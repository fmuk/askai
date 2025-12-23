import Foundation
import ArgumentParser
import FoundationModels

@available(macOS 26.0, *)
@main
enum Main {
    static func main() async {
        await AI.main()
    }
}

@available(macOS 26.0, *)
struct AI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ai",
        abstract: "Command-line interface to Apple Intelligence on-device model",
        version: "0.1.0"
    )

    // MARK: - Input Options
    @Option(name: .shortAndLong, help: "Prompt text")
    var prompt: String?

    @Flag(help: "Read prompt from stdin")
    var stdin: Bool = false

    // MARK: - Output Options
    @Option(help: "Output format (text|json)")
    var format: String = "text"

    @Flag(help: "Disable streaming output (buffer complete response)")
    var noStream: Bool = false

    @Flag(name: .shortAndLong, help: "Only print model output")
    var quiet: Bool = false

    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false

    // MARK: - Generation Options
    @Option(help: "Maximum response tokens")
    var maxTokens: Int?

    @Option(help: "Temperature (0.0-2.0)")
    var temperature: Double?

    @Flag(help: "Use greedy sampling (deterministic)")
    var greedy: Bool = false

    // MARK: - Session Options
    @Option(help: "System instruction")
    var system: String?

    @Flag(help: "Interactive conversation mode")
    var repl: Bool = false

    // MARK: - Operational Options
    @Option(help: "Generation timeout in seconds")
    var timeout: Int = 60

    // MARK: - Validation
    mutating func validate() throws {
        if prompt != nil && stdin {
            throw ValidationError("Cannot specify both --prompt and --stdin")
        }

        if let temp = temperature, !(0.0...2.0).contains(temp) {
            throw ValidationError("Temperature must be between 0.0 and 2.0")
        }

        if format != "text" && format != "json" {
            throw ValidationError("Format must be 'text' or 'json'")
        }

        if format == "json" && repl {
            throw ValidationError("JSON format not supported in REPL mode")
        }
    }

    // MARK: - Run
    mutating func run() async throws {
        let runner = CLIRunner(
            prompt: prompt,
            useStdin: stdin,
            format: format == "json" ? .json : .text,
            noStream: noStream,
            quiet: quiet,
            verbose: verbose,
            maxTokens: maxTokens,
            temperature: temperature,
            greedy: greedy,
            system: system,
            repl: repl,
            timeout: timeout
        )

        do {
            try await runner.run()
        } catch let error as CLIError {
            switch error {
            case .unavailable(let message, let code):
                if !quiet {
                    fputs("Error: \(message)\n", stderr)
                }
                Self.exit(withError: ExitStatus(code))
            case .generationFailed(let message, let code):
                if !quiet {
                    fputs("Error: \(message)\n", stderr)
                }
                Self.exit(withError: ExitStatus(code))
            case .invalidInput(let message):
                if !quiet {
                    fputs("Error: \(message)\n", stderr)
                }
                Self.exit(withError: ExitStatus(ExitCode.usageError))
            case .timeout:
                if !quiet {
                    fputs("Error: Operation timed out\n", stderr)
                }
                Self.exit(withError: ExitStatus(ExitCode.timeout))
            }
        } catch {
            if !quiet {
                fputs("Error: \(error.localizedDescription)\n", stderr)
            }
            Self.exit(withError: ExitStatus(ExitCode.generalError))
        }
    }
}

// MARK: - CLI Runner

@available(macOS 26.0, *)
struct CLIRunner {
    let prompt: String?
    let useStdin: Bool
    let format: OutputFormat
    let noStream: Bool
    let quiet: Bool
    let verbose: Bool
    let maxTokens: Int?
    let temperature: Double?
    let greedy: Bool
    let system: String?
    let repl: Bool
    let timeout: Int

    func run() async throws {
        // 1. Check availability
        try AvailabilityGuard.check()

        // 2. Resolve input
        let input = try InputReader.resolve(
            prompt: prompt,
            useStdin: useStdin
        )

        guard !input.isEmpty else {
            throw CLIError.invalidInput("Empty prompt")
        }

        // 3. Create model client
        let client = AppleModelClient(systemInstructions: system)

        // 4. Configure generation options
        var options = GenerationOptions()
        if let temp = temperature {
            options.temperature = temp
        }
        if greedy {
            options.sampling = .greedy
        }
        if let max = maxTokens {
            options.maximumResponseTokens = max
        }

        // 5. Create renderer
        let renderer = OutputRenderer(
            format: format,
            quiet: quiet,
            verbose: verbose
        )

        // 6. Generate response
        do {
            // Use streaming by default for text format (unless --no-stream or --format json)
            let shouldStream = format == .text && !noStream

            if shouldStream {
                let stream = client.streamResponse(to: input, options: options)
                _ = try await renderer.printStreaming(stream)
            } else {
                let startTime = Date()
                let response = try await client.respond(to: input, options: options)
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                renderer.printResponse(
                    response,
                    prompt: input,
                    systemInstructions: system,
                    latencyMs: latency
                )
            }
        } catch let error as CLIError {
            renderer.printError(error.localizedDescription)
            throw error
        } catch {
            renderer.printError(error.localizedDescription)
            throw CLIError.generationFailed(
                error.localizedDescription,
                exitCode: ExitCode.generationFailed
            )
        }
    }
}

// MARK: - Exit Status Helper

struct ExitStatus: Error {
    let code: Int32
    init(_ code: Int32) {
        self.code = code
    }
}
