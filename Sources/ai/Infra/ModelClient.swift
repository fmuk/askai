import Foundation
import FoundationModels

// MARK: - Protocol and Types

@available(macOS 26.0, *)
protocol LanguageModeling {
    func respond(to prompt: String, options: GenerationOptions?) async throws -> Response
    func streamResponse(to prompt: String, options: GenerationOptions?) -> AsyncThrowingStream<String, Error>
    func respondStructured<T: Decodable & Encodable>(to prompt: String, responseSchema: T.Type, options: GenerationOptions?) async throws -> StructuredResponse<T> where T: Sendable
}

struct Response {
    let content: String
    let estimatedTokens: Int?
}

struct StructuredResponse<T: Codable>: Sendable where T: Sendable {
    let data: T
    let rawJSON: String
}

// MARK: - Real Implementation

@available(macOS 26.0, *)
actor AppleModelClient: LanguageModeling {
    private let session: LanguageModelSession

    init(systemInstructions: String? = nil) {
        let instructions = systemInstructions.map { Instructions($0) }
        self.session = LanguageModelSession(instructions: instructions)
    }

    func respond(to prompt: String, options: GenerationOptions? = nil) async throws -> Response {
        do {
            let opts = options ?? GenerationOptions()
            let response = try await session.respond(to: prompt, options: opts)
            return Response(content: response.content, estimatedTokens: nil)
        } catch let error as LanguageModelSession.GenerationError {
            throw categorizeError(error)
        } catch {
            throw error
        }
    }

    nonisolated func streamResponse(to prompt: String, options: GenerationOptions? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let opts = options ?? GenerationOptions()
                    // Access session in isolated context
                    let stream = session.streamResponse(to: prompt, options: opts)
                    for try await partial in stream {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: categorizeError(error))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func respondStructured<T: Decodable & Encodable>(
        to prompt: String,
        responseSchema: T.Type,
        options: GenerationOptions? = nil
    ) async throws -> StructuredResponse<T> where T: Sendable {
        do {
            // The prompt already includes schema information from the caller
            let opts = options ?? GenerationOptions()
            let response = try await session.respond(to: prompt, options: opts)

            // Clean the response - extract JSON from markdown code blocks or text
            var cleanedContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to extract JSON from markdown code blocks
            if let jsonStart = cleanedContent.range(of: "```json") {
                // Find the content after ```json
                cleanedContent = String(cleanedContent[jsonStart.upperBound...])
                // Find the closing ```
                if let jsonEnd = cleanedContent.range(of: "```") {
                    cleanedContent = String(cleanedContent[..<jsonEnd.lowerBound])
                }
                cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if cleanedContent.hasPrefix("```") {
                // Handle generic code blocks
                if let firstNewline = cleanedContent.firstIndex(of: "\n") {
                    cleanedContent = String(cleanedContent[cleanedContent.index(after: firstNewline)...])
                }
                if let endBlock = cleanedContent.range(of: "```") {
                    cleanedContent = String(cleanedContent[..<endBlock.lowerBound])
                }
                cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let jsonStart = cleanedContent.firstIndex(of: "{"), let jsonEnd = cleanedContent.lastIndex(of: "}") {
                // Extract JSON object from surrounding text
                cleanedContent = String(cleanedContent[jsonStart...jsonEnd])
            } else if let arrayStart = cleanedContent.firstIndex(of: "["), let arrayEnd = cleanedContent.lastIndex(of: "]") {
                // Extract JSON array from surrounding text
                cleanedContent = String(cleanedContent[arrayStart...arrayEnd])
            }

            // Parse the JSON response
            let decoder = JSONDecoder()
            guard let jsonData = cleanedContent.data(using: .utf8) else {
                throw CLIError.generationFailed("Failed to convert response to data", exitCode: ExitCode.generationFailed)
            }

            do {
                let data = try decoder.decode(T.self, from: jsonData)

                // Re-encode with pretty printing
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let prettyData = try encoder.encode(data)
                let jsonString = String(data: prettyData, encoding: .utf8) ?? "{}"

                return StructuredResponse(data: data, rawJSON: jsonString)
            } catch {
                // If JSON parsing fails, provide helpful error message
                throw CLIError.generationFailed(
                    "Failed to parse JSON: \(error.localizedDescription)\nExtracted content:\n\(cleanedContent)",
                    exitCode: ExitCode.generationFailed
                )
            }
        } catch let error as LanguageModelSession.GenerationError {
            throw categorizeError(error)
        } catch {
            throw error
        }
    }

    private nonisolated func categorizeError(_ error: LanguageModelSession.GenerationError) -> Error {
        switch error {
        case .exceededContextWindowSize:
            return CLIError.generationFailed(
                "Context window exceeded (4096 token limit)",
                exitCode: ExitCode.contextExceeded
            )
        // Note: unsupportedLanguage case may not exist in actual API
        // Commenting out for now until we can test with real framework
        // case .unsupportedLanguage:
        //     return CLIError.generationFailed(
        //         "Unsupported language",
        //         exitCode: ExitCode.unsupportedLanguage
        //     )
        default:
            return CLIError.generationFailed(
                "Generation failed: \(error.localizedDescription)",
                exitCode: ExitCode.generationFailed
            )
        }
    }
}

// MARK: - Mock Implementation (for testing)

struct MockLanguageModel: LanguageModeling {
    var mockResponse: String = "Mock response"
    var shouldThrow: Error? = nil

    func respond(to prompt: String, options: GenerationOptions?) async throws -> Response {
        if let error = shouldThrow {
            throw error
        }
        return Response(content: mockResponse, estimatedTokens: nil)
    }

    func streamResponse(to prompt: String, options: GenerationOptions?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            if let error = shouldThrow {
                continuation.finish(throwing: error)
            } else {
                continuation.yield(mockResponse)
                continuation.finish()
            }
        }
    }

    func respondStructured<T: Decodable & Encodable>(
        to prompt: String,
        responseSchema: T.Type,
        options: GenerationOptions?
    ) async throws -> StructuredResponse<T> where T: Sendable {
        if let error = shouldThrow {
            throw error
        }
        // For mock, decode from mockResponse
        let jsonData = mockResponse.data(using: .utf8) ?? Data()
        let decoder = JSONDecoder()
        let data = try decoder.decode(T.self, from: jsonData)
        return StructuredResponse(data: data, rawJSON: mockResponse)
    }
}
