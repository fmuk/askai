import Foundation

enum OutputFormat: String {
    case text
    case json
}

struct OutputRenderer {
    let format: OutputFormat
    let quiet: Bool
    let verbose: Bool

    func printStreaming(_ stream: AsyncThrowingStream<String, Error>) async throws -> (content: String, latency: Int) {
        let startTime = Date()
        var previousContent = ""
        var fullContent = ""

        for try await cumulativeContent in stream {
            // Foundation Models sends cumulative content, so print only the delta
            if cumulativeContent.count > previousContent.count {
                let newContent = String(cumulativeContent.dropFirst(previousContent.count))
                print(newContent, terminator: "")
                fflush(stdout)
            }
            previousContent = cumulativeContent
            fullContent = cumulativeContent
        }
        print() // Final newline

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        if verbose {
            print("\n---")
            print("Latency: \(latencyMs)ms")
        }

        return (fullContent, latencyMs)
    }

    func printResponse(_ response: Response, prompt: String, systemInstructions: String?, latencyMs: Int) {
        switch format {
        case .text:
            print(response.content)

            if verbose {
                print("\n---")
                print("Latency: \(latencyMs)ms")
                if let tokens = response.estimatedTokens {
                    print("Estimated tokens: \(tokens)")
                }
            }

        case .json:
            let output = JSONOutput(
                model: "apple.foundation.ondevice.3b",
                prompt: prompt,
                response: response.content,
                system: systemInstructions,
                latencyMs: latencyMs,
                estimatedTokens: response.estimatedTokens
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(output),
               let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        }
    }

    func printError(_ message: String) {
        if !quiet {
            fputs("Error: \(message)\n", stderr)
        }
    }
}

struct JSONOutput: Codable {
    let model: String
    let prompt: String
    let response: String
    let system: String?
    let latencyMs: Int
    let estimatedTokens: Int?
}
