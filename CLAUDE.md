# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**askai** (working name: `ai`) is a macOS CLI tool that sends prompts to Apple Intelligence's on-device foundation model via Apple's Foundation Models framework (Swift). This is a **specification/design repository**—implementation has not yet begun.

The tool provides command-line access to the ~3B parameter on-device model that powers Apple Intelligence text features, enabling offline AI capabilities for summarization, text refinement, extraction, and creative content generation.

## Implementation Status

**Current state:** ✅ Phase 3 COMPLETE - REPL & Context Management

- ✅ Phase 1: MVP complete
  - Basic single-turn prompts working
  - All input modes functional (--prompt, --stdin, interactive)
  - Text and JSON output formats working
  - System instructions working
  - Verbose mode with latency tracking

- ✅ Phase 2: Streaming complete
  - Real-time token streaming (default for text output)
  - Proper handling of cumulative partial responses
  - Optional buffered mode with `--no-stream`

- ✅ Phase 3: REPL & Context Management complete
  - Interactive conversation mode (`--repl`)
  - Automatic context window management (4,096 token limit)
  - Smart history truncation (keeps recent messages within token budget)
  - Session persistence (save/load in JSONL format)
  - Configurable history budget (`--context-tokens`)
  - Token estimation heuristic (~4 chars/token)
  - Successfully tested with real Apple Intelligence on macOS 26.2

**Status:** Feature-complete and production-ready!
All planned phases implemented. Future enhancements optional.

## Key Technical Constraints

### Platform Requirements
- **macOS 26.0+ (Tahoe)** — Foundation Models framework availability
- **Apple Silicon required** (M1/M2/M3/M4) — Neural Engine essential for performance
- **Xcode 26+** for building
- Apple Intelligence must be enabled in System Settings

### Model Characteristics
- **Context window:** 4,096 tokens (input + output combined) — **hard limit**
- **Parameters:** ~3 billion
- **Inference speed:** ~30 tokens/sec on iPhone 15 Pro-class hardware
- **Quantization:** Mixed 2-bit/4-bit (~3.7 bits-per-weight)
- **Languages:** ~10 supported (English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Chinese)
- **Guardrails:** Content filtering enforced by framework, cannot be disabled

### Critical Design Decisions

1. **Token Budget Management**
   - The 4,096 token limit is framework-enforced with `GenerationError.exceededContextWindowSize`
   - No automatic truncation—CLI must proactively manage context
   - Recommended allocation: system instruction ≤500, history ≤2048, prompt ≤1000, response headroom ≤548
   - Truncate oldest conversation turns first in REPL mode

2. **Offline-Only Design**
   - All processing on-device via Foundation Models framework
   - No network calls, no Private Cloud Compute fallback
   - The `--offline` flag from v1 was removed in v2 (always offline by default)

3. **Privacy Stance**
   - No data written to disk by default
   - Session persistence requires explicit `--save-session` opt-in
   - All processing local; framework may log to unified logging per macOS standards

## Planned Architecture

### Package Structure
```
ai/
├── Package.swift
├── Sources/
│   └── ai/
│       ├── main.swift
│       ├── CLI/
│       │   ├── Arguments.swift       # ArgumentParser definitions
│       │   ├── InputReader.swift     # stdin/TTY handling
│       │   └── OutputRenderer.swift  # streaming, JSON, text
│       ├── Core/
│       │   ├── ContextManager.swift  # token budgeting, truncation
│       │   ├── Session.swift         # transcript management
│       │   └── TokenEstimator.swift  # rough token counting (~4 chars/token)
│       └── Infra/
│           ├── AvailabilityGuard.swift
│           ├── ModelClient.swift     # LanguageModelSession wrapper
│           └── Errors.swift          # error categorization
└── Tests/
    └── aiTests/
        ├── ArgumentsTests.swift
        ├── ContextManagerTests.swift
        └── TokenEstimatorTests.swift
```

### Core Components

**CLI Frontend:** ArgumentParser-based flag handling, stdin/TTY input, streaming/JSON output rendering

**Availability Guard:** Check `SystemLanguageModel.default.availability` and fail fast with specific exit codes for:
- Apple Intelligence not enabled (exit 10)
- Device not eligible (exit 10)
- Model assets not ready (exit 11)
- Unsupported language (exit 12)

**Context Manager:** Token budget tracking, transcript truncation, system instruction + history + prompt assembly

**Foundation Model Client:** Wrapper around `LanguageModelSession`, handles `respond(to:)` and `streamResponse(to:)`, configures `GenerationOptions`

**Session Store:** In-memory transcript with optional JSONL persistence

## Development Commands

### Building
```bash
# Debug build
swift build

# Release build
swift build -c release
```

### Running

**Basic usage:**
```bash
# Simple prompt
.build/debug/ai --prompt "Write a haiku about programming"

# Or with release build
.build/release/ai --prompt "Write a haiku about programming"

# Interactive mode (type prompt, press Ctrl+D to submit)
.build/debug/ai
```

**Input methods:**
```bash
# Command-line argument
.build/debug/ai --prompt "Explain async/await"

# Stdin
echo "Summarize this text" | .build/debug/ai --stdin

# Piped file
cat document.txt | .build/debug/ai --stdin
```

**Output formats:**
```bash
# Text output (default)
.build/debug/ai --prompt "Hello"

# JSON output
.build/debug/ai --prompt "Hello" --format json

# Verbose mode (shows latency)
.build/debug/ai --prompt "Hello" --verbose
```

**System instructions:**
```bash
.build/debug/ai --system "You are a helpful coding assistant" --prompt "Explain recursion"
```

**Generation options:**
```bash
# Temperature control (0.0 = deterministic, 2.0 = creative)
.build/debug/ai --temperature 0.5 --prompt "Generate a greeting"

# Greedy sampling (deterministic)
.build/debug/ai --greedy --prompt "Generate a greeting"

# Max tokens
.build/debug/ai --max-tokens 50 --prompt "Write a story"
```

### Testing
```bash
# Run all tests (when implemented)
swift test

# Run specific test
swift test --filter ContextManagerTests
```

## Implementation Guidance

### Error Handling Pattern
Map `LanguageModelSession.GenerationError` to specific exit codes:
- `.exceededContextWindowSize` → exit 23
- `.unsupportedLanguage` → exit 12
- `.guardrailViolation` → exit 22
- Other generation errors → exit 20
- `CancellationError` (timeout) → exit 21

### Streaming Implementation
Default for text format; print tokens as they arrive with `fflush(stdout)` after each token for real-time display.

### Timeout Implementation
Use `withThrowingTaskGroup` to race generation task against `Task.sleep(for: timeout)`, cancel all tasks on first completion.

### Token Estimation
Framework doesn't expose tokenizer—use ~4 characters per token as heuristic. Validate against actual usage in testing.

### Testability
Define `LanguageModeling` protocol to allow mocking in CI environments without Apple Intelligence:
```swift
protocol LanguageModeling {
    func respond(to prompt: String) async throws -> String
    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error>
}
```

## Key Differences from v1 Specification

The v2 specification (specification-v2.md) supersedes v1 with these changes:
- Removed `--offline` flag (always offline)
- Added streaming as default for text output
- Added `--greedy` flag for deterministic sampling
- Documented 4,096 token context limit with explicit budget strategy
- Added exit codes 12 (unsupported language), 22 (guardrail), 23 (context exceeded)
- Specified macOS 26+ and Apple Silicon requirements
- Documented ~10 language support
- Made guardrails non-disableable (framework constraint)

## Known Limitations

1. **4,096 token context** — Long conversations lose early history
2. **Text only** — No image/vision input support
3. **Guardrails enforced** — Content filtering cannot be disabled
4. **Language restrictions** — ~10 languages only
5. **Greedy reproducibility** — Only within same OS/model version
6. **Not a knowledge base** — Model excels at text tasks, not factual Q&A
