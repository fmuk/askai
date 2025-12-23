import Foundation
import FoundationModels

// MARK: - Protocol and Types

@available(macOS 26.0, *)
protocol LanguageModeling {
    func respond(to prompt: String, options: GenerationOptions?) async throws -> Response
}

struct Response {
    let content: String
    let estimatedTokens: Int?
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

    private func categorizeError(_ error: LanguageModelSession.GenerationError) -> Error {
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
}
