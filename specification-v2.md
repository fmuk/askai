# Apple Intelligence CLI — Specification & Design (v2)

A macOS CLI that sends prompts to **Apple Intelligence's on-device foundation model** via Apple's **Foundation Models framework** (Swift).

---

## 1) Product Definition

**Name (working):** `ai` (or `apple-ai`, `fim`)

**Goal:** Accept a prompt (CLI arg / stdin / interactive), run it through Apple Intelligence's **on-device** ~3B parameter model, print the response to stdout.

**Non-goals:**

* Not a Siri automation tool
* Not a cloud/Private Cloud Compute tool—strictly on-device
* Not a full chat application; it's a CLI "single-turn" tool with optional session loop
* Not a general knowledge chatbot—the model excels at text tasks (summarization, extraction, refinement, creative content) but is not designed for broad world knowledge Q&A

---

## 2) Requirements

### 2.1 Platform

* **macOS 26.0+** (Tahoe) or later
* **Apple Silicon required** (M1/M2/M3/M4 series)—the Neural Engine is essential for acceptable performance
* **Apple Intelligence enabled** in System Settings → Apple Intelligence & Siri
* Model assets downloaded (OS-managed, automatic)
* **Xcode 26+** required for building

### 2.2 Language Support

The on-device model supports approximately 10 languages:
- English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Chinese (Simplified & Traditional)

Prompts in unsupported languages will fail with a specific error. The CLI should detect and report this clearly.

### 2.3 Model Characteristics

| Property | Value |
|----------|-------|
| Parameters | ~3 billion |
| Context window | **4,096 tokens** (input + output combined) |
| Quantization | Mixed 2-bit/4-bit (~3.7 bits-per-weight) |
| Inference speed | ~30 tokens/sec on iPhone 15 Pro class hardware |
| Time-to-first-token | ~0.6ms per prompt token |

**Important:** The 4,096 token limit is a hard constraint. The framework throws `GenerationError.exceededContextWindowSize` with no automatic truncation.

---

## 3) CLI Interface Specification

### 3.1 Usage

```bash
ai "Summarize this text: ..."

ai --prompt "Write 5 bullet points about X"

echo "Explain this code:" | ai --stdin

ai                    # interactive single prompt
ai --repl             # continuous conversation loop
```

### 3.2 Flags

**Input:**
* `--prompt, -p <text>` — prompt as argument
* `--stdin` — read prompt from stdin (until EOF)
* (default) interactive prompt if neither provided

**Output:**
* `--format text|json` — default `text`
* `--stream` — stream tokens as generated (default for `text` format)
* `--no-stream` — wait for complete response
* `--no-wrap` — disable line wrapping
* `--quiet, -q` — only print model output (suppress banners/status)

**Generation controls:**
* `--max-tokens <n>` — maximum response tokens (default: framework default)
* `--temperature <0.0-2.0>` — randomness (0=deterministic-ish, 2=creative). Default: framework default (~1.0)
* `--greedy` — deterministic output (equivalent to specific sampling strategy). Note: only reproducible within same OS/model version

**Session/REPL:**
* `--repl` — interactive loop with conversation history
* `--system <text>` — system instruction (prepended to session)
* `--context-tokens <n>` — token budget for conversation history (default: 2048)
* `--save-session <path>` — persist transcript to JSONL
* `--load-session <path>` — restore transcript from JSONL

**Operational:**
* `--timeout <seconds>` — generation deadline (default: 60)
* `--verbose, -v` — show token counts, latency, model info

### 3.3 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | CLI usage error (invalid arguments) |
| 10 | Apple Intelligence unavailable (not enabled, device ineligible) |
| 11 | Model assets not ready (still downloading) |
| 12 | Unsupported language |
| 20 | Generation failed (framework error) |
| 21 | Timeout exceeded |
| 22 | Content policy / guardrail violation |
| 23 | Context window exceeded |

---

## 4) Behavioral Specification

### 4.1 Input Resolution Order

1. `--prompt` if present
2. `--stdin` if present  
3. If both `--prompt` and `--stdin` provided → exit code 2
4. Interactive prompt:
   * Display `> ` 
   * Read until EOF (Ctrl+D)

### 4.2 Token Budget Management

Given the **4,096 token hard limit**, the CLI must proactively manage context:

```
Total budget:        4,096 tokens
┌─────────────────────────────────┐
│ System instruction    ≤500     │
│ Conversation history  ≤2,048   │  ← --context-tokens
│ Current prompt        ≤1,000   │
│ Response headroom     ≤548     │
└─────────────────────────────────┘
```

**Truncation strategy (REPL mode):**
1. Estimate tokens for system instruction + current prompt
2. Calculate remaining budget for history
3. Include most recent turns that fit within budget
4. Trim oldest turns first
5. If single prompt exceeds budget, warn and truncate with "[truncated]" marker

**Token estimation:** Use ~4 characters per token as rough heuristic (actual tokenizer not publicly exposed).

### 4.3 Prompt Construction

```
┌─ Session ─────────────────────────────────────┐
│ Instructions: [--system text if provided]     │
│                                               │
│ Transcript:                                   │
│   [Previous turns if --repl, within budget]   │
│                                               │
│ Current prompt: [user input]                  │
└───────────────────────────────────────────────┘
```

### 4.4 Output Behavior

**Streaming (default for `text`):**
- Print tokens as they arrive
- Flush after each token for real-time display
- Show newline only after generation completes

**Non-streaming:**
- Buffer complete response
- Print all at once

**JSON format:**
```json
{
  "model": "apple.foundation.ondevice.3b",
  "prompt": "...",
  "response": "...",
  "system": "...",
  "usage": {
    "prompt_tokens": 127,
    "response_tokens": 89,
    "total_tokens": 216
  },
  "latency_ms": 2847,
  "options": {
    "temperature": 1.0,
    "max_tokens": null,
    "greedy": false
  },
  "warnings": []
}
```

Note: Token counts may be estimates; the framework doesn't expose exact tokenization.

### 4.5 Guardrails

The Foundation Models framework enforces content guardrails that **cannot be disabled**. If a prompt or response triggers the guardrail:
- Exit with code 22
- Display: `Error: Content filtered by Apple Intelligence safety guidelines`
- In JSON mode, include `"error": "guardrail_triggered"` 

---

## 5) Architecture

### 5.1 Components

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI Frontend                          │
│  • ArgumentParser for flag handling                         │
│  • stdin/TTY input handling                                 │
│  • Output rendering (streaming, JSON, text)                 │
│  • Exit code mapping                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Availability Guard                       │
│  • Check SystemLanguageModel.default.availability           │
│  • Map unavailability reasons to exit codes                 │
│  • Fail fast with clear messages                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Context Manager                         │
│  • Token budget tracking (estimated)                        │
│  • Transcript truncation                                    │
│  • System instruction + history + prompt assembly           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Foundation Model Client                    │
│  • LanguageModelSession management                          │
│  • respond(to:) / streamResponse(to:)                       │
│  • GenerationOptions configuration                          │
│  • Error handling and categorization                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Session Store (opt)                      │
│  • In-memory transcript                                     │
│  • JSONL persistence (--save-session / --load-session)      │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Data Flow (Single Turn)

```
CLI args/stdin
      │
      ▼
AvailabilityGuard.check()  ─── fail ──→ exit(10|11)
      │
      │ ok
      ▼
ContextManager.build(system, prompt)
      │
      ▼
FoundationModelClient.generate()
      │
      ├── stream ──→ print tokens ──→ exit(0)
      │
      └── error ──→ categorize ──→ exit(20|21|22|23)
```

### 5.3 Data Flow (REPL)

```
Loop:
  ┌──→ read user input
  │         │
  │         ▼
  │    ContextManager.build(system, history, prompt)
  │         │
  │         ├── budget exceeded? ──→ truncate oldest turns
  │         │
  │         ▼
  │    FoundationModelClient.generate()
  │         │
  │         ├── stream response to stdout
  │         │
  │         ▼
  │    append (prompt, response) to transcript
  │         │
  └─────────┘
```

---

## 6) Implementation Design (Swift)

### 6.1 Package Structure

```
ai/
├── Package.swift
├── Sources/
│   └── ai/
│       ├── main.swift
│       ├── CLI/
│       │   ├── Arguments.swift      # ArgumentParser definitions
│       │   ├── InputReader.swift    # stdin/TTY handling
│       │   └── OutputRenderer.swift # streaming, JSON, text
│       ├── Core/
│       │   ├── ContextManager.swift # token budgeting, truncation
│       │   ├── Session.swift        # transcript management
│       │   └── TokenEstimator.swift # rough token counting
│       └── Infra/
│           ├── AvailabilityGuard.swift
│           ├── ModelClient.swift    # LanguageModelSession wrapper
│           └── Errors.swift         # error categorization
└── Tests/
    └── aiTests/
        ├── ArgumentsTests.swift
        ├── ContextManagerTests.swift
        └── TokenEstimatorTests.swift
```

### 6.2 Key Types

```swift
import FoundationModels
import ArgumentParser

@main
struct AI: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Prompt text")
    var prompt: String?
    
    @Flag(help: "Read prompt from stdin")
    var stdin: Bool = false
    
    @Option(help: "System instruction")
    var system: String?
    
    @Option(help: "Temperature (0.0-2.0)")
    var temperature: Double?
    
    @Flag(help: "Use greedy (deterministic) sampling")
    var greedy: Bool = false
    
    @Option(help: "Maximum response tokens")
    var maxTokens: Int?
    
    @Flag(help: "Interactive conversation mode")
    var repl: Bool = false
    
    @Option(help: "Output format")
    var format: OutputFormat = .text
    
    // ... additional flags
    
    func run() async throws {
        // 1. Check availability
        try AvailabilityGuard.check()
        
        // 2. Resolve input
        let input = try InputReader.resolve(prompt: prompt, useStdin: stdin)
        
        // 3. Build session
        let session = LanguageModelSession(
            instructions: system.map { Instructions($0) }
        )
        
        // 4. Configure options
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
        
        // 5. Generate
        if format == .text {
            // Stream by default
            let stream = session.streamResponse(to: input, options: options)
            for try await partial in stream {
                print(partial.content, terminator: "")
                fflush(stdout)
            }
            print() // final newline
        } else {
            let response = try await session.respond(to: input, options: options)
            // Output JSON
        }
    }
}
```

### 6.3 Availability Checking

```swift
struct AvailabilityGuard {
    static func check() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return // OK
            
        case .unavailable(.appleIntelligenceNotEnabled):
            throw CLIError.unavailable(
                "Apple Intelligence is not enabled. Enable it in System Settings → Apple Intelligence & Siri.",
                exitCode: 10
            )
            
        case .unavailable(.deviceNotEligible):
            throw CLIError.unavailable(
                "This device doesn't support Apple Intelligence. Apple Silicon Mac required.",
                exitCode: 10
            )
            
        case .unavailable(.modelNotReady):
            throw CLIError.unavailable(
                "Model assets are still downloading. Try again in a few minutes.",
                exitCode: 11
            )
            
        case .unavailable(_):
            throw CLIError.unavailable(
                "Apple Intelligence is unavailable.",
                exitCode: 10
            )
        }
    }
}
```

### 6.4 Error Handling

```swift
func categorizeError(_ error: Error) -> (message: String, code: Int32) {
    if let genError = error as? LanguageModelSession.GenerationError {
        switch genError {
        case .exceededContextWindowSize:
            return ("Context window exceeded (4096 token limit)", 23)
        case .unsupportedLanguage:
            return ("Unsupported language", 12)
        case .guardrailViolation:
            return ("Content filtered by safety guidelines", 22)
        default:
            return ("Generation failed: \(genError.localizedDescription)", 20)
        }
    }
    
    if error is CancellationError {
        return ("Operation timed out", 21)
    }
    
    return ("Unexpected error: \(error.localizedDescription)", 1)
}
```

### 6.5 Concurrency

```swift
// Timeout implementation
func generateWithTimeout(
    session: LanguageModelSession,
    prompt: String,
    timeout: Duration
) async throws -> String {
    try await withThrowingTaskGroup(of: String.self) { group in
        group.addTask {
            let response = try await session.respond(to: prompt)
            return response.content
        }
        
        group.addTask {
            try await Task.sleep(for: timeout)
            throw CLIError.timeout
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

---

## 7) Operational Concerns

### 7.1 Performance Expectations

| Operation | Expected Latency |
|-----------|------------------|
| Availability check | <10ms |
| Session creation | <50ms |
| Time to first token | prompt_tokens × 0.6ms |
| Token generation | ~30 tokens/sec |

For a 100-token prompt expecting 200-token response: ~60ms TTFT + ~6.7s generation = **~7 seconds total**

### 7.2 Privacy Stance

* **Default:** No data written to disk
* **Explicit opt-in:** `--save-session` writes transcript
* **All processing on-device:** No network calls, no telemetry
* The Foundation Models framework itself may log to unified logging (os_log) per Apple's standard practices

### 7.3 Known Limitations

1. **4,096 token context** — Long conversations will lose early context
2. **No image input** — Text only (vision not supported in current framework)
3. **Guardrails enforced** — Cannot disable content filtering
4. **Language restrictions** — ~10 languages supported
5. **Model updates** — Greedy sampling reproducibility only within same OS version
6. **Not a knowledge base** — Model excels at text tasks, not factual Q&A

---

## 8) Testing Strategy

### 8.1 Unit Tests

* CLI argument parsing (all flag combinations)
* Input resolution precedence
* Token estimation accuracy
* Context truncation logic
* JSON output schema validation
* Error categorization

### 8.2 Integration Tests

```swift
// Protocol for testability
protocol LanguageModeling {
    func respond(to prompt: String) async throws -> String
    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error>
}

// Mock for CI environments without Apple Intelligence
struct MockLanguageModel: LanguageModeling {
    var responses: [String: String] = [:]
    
    func respond(to prompt: String) async throws -> String {
        responses[prompt] ?? "Mock response for: \(prompt)"
    }
}
```

### 8.3 Manual Validation

On a compatible macOS 26+ system with Apple Intelligence enabled:
- Single prompt generation
- Streaming output
- REPL mode conversation continuity
- Context truncation at ~4000 tokens
- Guardrail triggering
- Timeout behavior
- Session save/load

---

## 9) Future Considerations

### 9.1 Potential Enhancements

* **Structured output** — Leverage `@Generable` for typed responses (e.g., `--schema recipe.json`)
* **Tool integration** — Allow model to call external tools
* **Adapter support** — Load custom fine-tuned adapters (advanced)
* **Pipe-friendly mode** — Better integration with Unix pipelines

### 9.2 Monitoring Apple's Updates

* Context window may increase in future OS versions
* Additional languages may be added
* New sampling strategies or generation options
* Guardrail configuration may become available

---

## Appendix A: Quick Reference

```bash
# Basic usage
ai "Summarize: [text]"

# With system prompt
ai --system "You are a helpful editor" --prompt "Fix grammar: [text]"

# Piped input
cat document.txt | ai --stdin --system "Summarize this document"

# REPL mode
ai --repl --system "You are a coding assistant"

# Deterministic output
ai --greedy "Generate a greeting"

# JSON output with metadata
ai --format json "What is 2+2?"

# Save conversation
ai --repl --save-session chat.jsonl
```

---

## Appendix B: Comparison with Spec v1

| Aspect | v1 | v2 (This Document) |
|--------|----|--------------------|
| Context limit | Unspecified | 4,096 tokens (hard limit) |
| Token budget | "Hard cap" mentioned | Explicit allocation strategy |
| `--offline` flag | Present | Removed (always offline) |
| Streaming | Not mentioned | Default for text output |
| `--greedy` | Not present | Added for deterministic output |
| Exit codes | 6 codes | 9 codes (added 12, 22, 23) |
| Platform | "Apple Intelligence era" | macOS 26+, Apple Silicon required |
| Language support | Not mentioned | ~10 languages documented |
| Guardrails | Not mentioned | Documented as non-disableable |

---

## References

* [Meet the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
* [Deep dive into the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/301/)
* [Apple Foundation Models Documentation](https://developer.apple.com/documentation/foundationmodels)
* [Apple ML Research: Foundation Models](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
* [TN3193: Managing the on-device foundation model's context window](https://developer.apple.com/documentation/technotes/tn3193)
