import Foundation
import FoundationModels

@available(macOS 26.0, *)
struct REPL {
    let client: any LanguageModeling
    let system: String?
    let contextManager: ContextManager
    let verbose: Bool
    let saveSessionPath: String?
    let options: GenerationOptions?

    func run() async throws {
        var session = ConversationSession(system: system)

        // Display welcome message
        print("┌─────────────────────────────────────────────┐")
        print("│  Apple Intelligence REPL Mode               │")
        print("│  Type your message and press Enter          │")
        print("│  Press Ctrl+D to exit                       │")
        if let sys = system {
            let truncated = sys.count > 30 ? "..." : ""
            let padding = String(repeating: " ", count: max(0, 40 - min(30, sys.count) - truncated.count))
            print("│  System: \(sys.prefix(30))\(truncated)\(padding)│")
        }
        print("└─────────────────────────────────────────────┘")
        print()

        while true {
            // Read user input
            print("You: ", terminator: "")
            fflush(stdout)

            let userInput = readLine()

            if userInput == nil {
                // Ctrl+D pressed
                print("\nExiting REPL...")
                break
            }

            guard let input = userInput, !input.isEmpty else {
                // Empty input, skip
                continue
            }

            // Build context with history
            let (includedHistory, wasTruncated) = contextManager.buildContext(
                system: system,
                history: session.getTurns(),
                currentPrompt: input
            )

            if wasTruncated && verbose {
                let droppedCount = session.count() - includedHistory.count
                print("ℹ️  [Truncated \(droppedCount) older message(s) due to context limit]")
            }

            // Build full prompt with history
            var fullPrompt = ""
            for turn in includedHistory {
                fullPrompt += "User: \(turn.user)\n\nAssistant: \(turn.assistant)\n\n"
            }
            fullPrompt += "User: \(input)\n\nAssistant:"

            // Generate response with streaming
            print("AI: ", terminator: "")
            fflush(stdout)

            var assistantResponse = ""
            var previousContent = ""

            do {
                let stream = client.streamResponse(to: fullPrompt, options: options)

                for try await cumulativeContent in stream {
                    // Foundation Models sends cumulative content, print only the delta
                    if cumulativeContent.count > previousContent.count {
                        let newContent = String(cumulativeContent.dropFirst(previousContent.count))
                        print(newContent, terminator: "")
                        fflush(stdout)
                    }
                    previousContent = cumulativeContent
                    assistantResponse = cumulativeContent
                }
                print() // Final newline
            } catch {
                print("\n⚠️  Error: \(error.localizedDescription)")
                continue
            }

            // Add turn to session
            session.addTurn(user: input, assistant: assistantResponse)

            // Save session if path provided
            if let savePath = saveSessionPath {
                do {
                    try SessionManager.save(transcript: session.getTurns(), to: savePath)
                    if verbose {
                        print("💾 Session saved to \(savePath)")
                    }
                } catch {
                    print("⚠️  Failed to save session: \(error.localizedDescription)")
                }
            }

            print() // Blank line for readability
        }

        // Final save
        if let savePath = saveSessionPath {
            do {
                try SessionManager.save(transcript: session.getTurns(), to: savePath)
                print("💾 Session saved to \(savePath)")
            } catch {
                print("⚠️  Failed to save session: \(error.localizedDescription)")
            }
        }
    }
}
