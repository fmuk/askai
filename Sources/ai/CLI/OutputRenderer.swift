import Foundation

enum OutputFormat: String {
    case text
    case json
}

struct OutputRenderer {
    let format: OutputFormat
    let quiet: Bool
    let verbose: Bool

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
