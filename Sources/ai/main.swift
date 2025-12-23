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

    // MARK: - Structured Output Options
    @Option(help: "Schema type for structured output (contact, task, task-list, code-issue, code-analysis, message, key-value, list)")
    var schema: String?

    // MARK: - Session Options
    @Option(help: "System instruction")
    var system: String?

    @Flag(help: "Interactive conversation mode")
    var repl: Bool = false

    @Option(help: "Save session transcript to file (JSONL)")
    var saveSession: String?

    @Option(help: "Load session transcript from file (JSONL)")
    var loadSession: String?

    @Option(help: "Token budget for conversation history (default: 2048)")
    var contextTokens: Int = 2048

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

        if repl && (prompt != nil || stdin) {
            throw ValidationError("Cannot use --prompt or --stdin in REPL mode")
        }

        if loadSession != nil && !repl {
            throw ValidationError("--load-session only works in REPL mode")
        }

        // Validate schema if provided
        if let schemaStr = schema {
            let validSchemas = SchemaType.allCases.map { $0.rawValue }
            if !validSchemas.contains(schemaStr) {
                throw ValidationError("Invalid schema type '\(schemaStr)'. Valid options: \(validSchemas.joined(separator: ", "))")
            }
        }

        // Schema requires format to be json or unspecified (will default to json)
        if schema != nil && format == "text" {
            throw ValidationError("Structured output (--schema) requires --format json or no format specified")
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
            schema: schema,
            system: system,
            repl: repl,
            saveSession: saveSession,
            loadSession: loadSession,
            contextTokens: contextTokens,
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
    let schema: String?
    let system: String?
    let repl: Bool
    let saveSession: String?
    let loadSession: String?
    let contextTokens: Int
    let timeout: Int

    func run() async throws {
        // 1. Check availability
        try AvailabilityGuard.check()

        // 2. Handle REPL mode separately
        if repl {
            return try await runREPL()
        }

        // 3. Resolve input for single-turn mode
        let input = try InputReader.resolve(
            prompt: prompt,
            useStdin: useStdin
        )

        guard !input.isEmpty else {
            throw CLIError.invalidInput("Empty prompt")
        }

        // 4. Create model client
        let client = AppleModelClient(systemInstructions: system)

        // 5. Configure generation options
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

        // 6. Create renderer
        let renderer = OutputRenderer(
            format: format,
            quiet: quiet,
            verbose: verbose
        )

        // 7. Generate response
        do {
            // Handle structured output if schema is specified
            if let schemaStr = schema {
                guard let schemaType = SchemaType(rawValue: schemaStr) else {
                    throw CLIError.invalidInput("Invalid schema type: \(schemaStr)")
                }

                let startTime = Date()
                let jsonOutput = try await generateStructuredResponse(
                    client: client,
                    input: input,
                    schemaType: schemaType,
                    options: options
                )
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)

                renderer.printStructuredResponse(
                    jsonOutput,
                    prompt: input,
                    schemaType: schemaType,
                    systemInstructions: system,
                    latencyMs: latency
                )
            } else {
                // Regular text output
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

    private func generateStructuredResponse(
        client: AppleModelClient,
        input: String,
        schemaType: SchemaType,
        options: GenerationOptions?
    ) async throws -> String {
        // Build prompt with schema example
        let enhancedPrompt = """
        \(input)

        You MUST respond with ONLY valid JSON following this exact schema:
        \(schemaType.exampleJSON)

        Use these exact field names and types. Do not include any explanatory text.
        """

        switch schemaType {
        case .contact:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: ContactInfo.self, options: options)
            return response.rawJSON
        case .task:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: TaskItem.self, options: options)
            return response.rawJSON
        case .taskList:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: TaskList.self, options: options)
            return response.rawJSON
        case .codeIssue:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: CodeIssue.self, options: options)
            return response.rawJSON
        case .codeAnalysis:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: CodeAnalysis.self, options: options)
            return response.rawJSON
        case .messageClassification:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: MessageClassification.self, options: options)
            return response.rawJSON
        case .keyValuePairs:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: KeyValuePairs.self, options: options)
            return response.rawJSON
        case .stringList:
            let response = try await client.respondStructured(to: enhancedPrompt, responseSchema: StringList.self, options: options)
            return response.rawJSON
        }
    }

    func runREPL() async throws {
        // Configure generation options
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

        // Create context manager
        let contextManager = ContextManager(historyBudget: contextTokens)

        // Create model client
        let client = AppleModelClient(systemInstructions: system)

        // Create and run REPL
        let replInstance = REPL(
            client: client,
            system: system,
            contextManager: contextManager,
            verbose: verbose,
            saveSessionPath: saveSession,
            options: options
        )

        try await replInstance.run()
    }
}

// MARK: - Exit Status Helper

struct ExitStatus: Error {
    let code: Int32
    init(_ code: Int32) {
        self.code = code
    }
}
