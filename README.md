# ai - Apple Intelligence CLI

A macOS command-line interface for Apple Intelligence's on-device foundation model.

## Features

✅ **Implemented**
- **Phase 1 MVP:**
  - Single-turn prompt/response
  - Multiple input methods (--prompt, --stdin, interactive)
  - Text and JSON output formats
  - System instructions
  - Generation controls (temperature, greedy, max-tokens)
  - Verbose mode with latency tracking
  - Fully offline (on-device processing)

- **Phase 2: Streaming:**
  - Real-time token streaming (default for text output)
  - See responses appear as they're generated
  - Optional buffered mode with `--no-stream`

- **Phase 3: REPL & Context Management:**
  - Interactive conversation mode (`--repl`)
  - Automatic context window management (4,096 token limit)
  - Smart history truncation (keeps recent messages)
  - Session persistence (save/load conversations in JSONL format)
  - Configurable history budget

## Requirements

- macOS 26.0 (Tahoe) or later
- Apple Silicon (M1/M2/M3/M4)
- Apple Intelligence enabled in System Settings
- Xcode 26+ (for building)

## Installation

```bash
# Build from source
swift build -c release

# The binary will be at .build/release/ai
```

## Usage

### Basic Examples

```bash
# Simple prompt
./build/release/ai --prompt "Write a haiku about coding"

# Interactive single prompt
./build/release/ai
> Type your prompt here
> Press Ctrl+D to submit

# Pipe input from file
cat document.txt | .build/release/ai --stdin

# With system instruction
.build/release/ai --system "You are a helpful assistant" --prompt "Explain quantum computing"
```

### REPL Mode (Interactive Conversations)

```bash
# Start REPL mode
.build/release/ai --repl

# REPL with system instruction
.build/release/ai --repl --system "You are a helpful coding assistant"

# REPL with session saving
.build/release/ai --repl --save-session chat.jsonl

# REPL with custom context budget (default 2048 tokens for history)
.build/release/ai --repl --context-tokens 3000
```

The REPL mode maintains conversation history and automatically manages the 4,096 token context window by truncating older messages when needed.

### Output Formats

```bash
# Text output with streaming (default - tokens appear in real-time)
.build/release/ai --prompt "Write a story"

# Disable streaming (buffer complete response)
.build/release/ai --prompt "Write a story" --no-stream

# JSON output (automatically disables streaming)
.build/release/ai --prompt "Hello" --format json

# Verbose mode (shows latency)
.build/release/ai --prompt "Hello" --verbose
```

### Generation Controls

```bash
# Temperature (0.0 = deterministic, 2.0 = creative)
.build/release/ai --temperature 1.5 --prompt "Write a creative story"

# Greedy sampling (deterministic output)
.build/release/ai --greedy --prompt "Generate code"

# Limit response length
.build/release/ai --max-tokens 50 --prompt "Explain AI"
```

## Command-Line Options

```
USAGE: ai [<options>]

OPTIONS:
  -p, --prompt <prompt>            Prompt text
  --stdin                          Read prompt from stdin
  --format <format>                Output format (text|json) (default: text)
  --no-stream                      Disable streaming output (buffer complete response)
  -q, --quiet                      Only print model output
  -v, --verbose                    Show detailed information
  --max-tokens <max-tokens>        Maximum response tokens
  --temperature <temperature>      Temperature (0.0-2.0)
  --greedy                         Use greedy sampling (deterministic)
  --system <system>                System instruction
  --repl                           Interactive conversation mode
  --save-session <save-session>    Save session transcript to file (JSONL)
  --load-session <load-session>    Load session transcript from file (JSONL)
  --context-tokens <context-tokens> Token budget for conversation history (default: 2048)
  --timeout <timeout>              Generation timeout in seconds (default: 60)
  --version                        Show the version
  -h, --help                       Show help information
```

## Architecture

See [CLAUDE.md](CLAUDE.md) for detailed architectural documentation and implementation guidance.

### Project Structure

```
ai/
├── Package.swift
├── Sources/ai/
│   ├── main.swift              # CLI entry point and argument parser
│   ├── CLI/
│   │   ├── InputReader.swift   # stdin/TTY input handling
│   │   └── OutputRenderer.swift # Text and JSON output
│   ├── Core/                   # (Phase 3)
│   │   ├── TokenEstimator.swift
│   │   ├── ContextManager.swift
│   │   ├── REPL.swift
│   │   └── Session.swift
│   └── Infra/
│       ├── Errors.swift        # Error types and exit codes
│       ├── AvailabilityGuard.swift # Apple Intelligence availability checking
│       └── ModelClient.swift   # FoundationModels wrapper
└── Tests/aiTests/
```

## Examples

```bash
# Summarize text
echo "Long article text..." | .build/release/ai --stdin --system "Summarize this in 3 bullet points"

# Code review
cat myfile.swift | .build/release/ai --stdin --system "Review this Swift code for potential issues"

# Generate content
.build/release/ai --prompt "Write 5 creative project names for a weather app" --temperature 1.8

# Extract information
.build/release/ai --prompt "Extract email addresses from this text: Contact us at hello@example.com or support@test.org" --format json

# Interactive coding session
.build/release/ai --repl --system "You are an expert Swift developer" --save-session coding-session.jsonl

# Long conversation with context management
.build/release/ai --repl --context-tokens 3000 --verbose
# The verbose flag will show when older messages are truncated
```

## Performance

Typical performance on Apple M4 Pro:
- Time to first token: ~60ms for 100-token prompt
- Generation speed: ~30 tokens/second
- Latency for short prompts: 300-1000ms

## Privacy

- **100% on-device processing** - no network calls, no data leaves your Mac
- No telemetry or usage tracking by this tool
- Respects Apple's Foundation Models framework privacy guarantees
- Optional session persistence is explicit opt-in (--save-session)

## Limitations

1. **4,096 token context window** - Input + output combined
2. **Text only** - No image/vision input support
3. **Content guardrails enforced** - Cannot be disabled (Apple framework requirement)
4. **Language support** - ~10 languages (English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Chinese)
5. **Not a knowledge base** - Best for text tasks (summarization, refinement, creative content), not factual Q&A

## License

See LICENSE file (if applicable)

## Contributing

This is a personal/educational project. See specification files (specification-v1.txt, specification-v2.md) for design rationale.
