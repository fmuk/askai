# ai - Apple Intelligence CLI

A macOS command-line interface for Apple Intelligence's on-device foundation model.

**Version:** 0.5.0 | [Installation](INSTALL.md) | [Changelog](CHANGELOG.md)

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

- **Phase 4: Structured Output:**
  - Extract structured data as JSON using predefined schemas
  - Built-in schemas: contact info, tasks, code analysis, message classification, key-value pairs, lists
  - Automatic JSON parsing with markdown code block handling
  - Schema validation and error reporting

## Requirements

- macOS 26.0 (Tahoe) or later
- Apple Silicon (M1/M2/M3/M4)
- Apple Intelligence enabled in System Settings
- Xcode 26+ (for building)

## Installation

### Option 1: Download Pre-built Binary (Easiest)

Download the latest release from the [Releases page](https://github.com/yourusername/askai/releases):

```bash
# Quick install
curl -L -o ai.tar.gz https://github.com/yourusername/askai/releases/latest/download/ai-macos-arm64.tar.gz
tar -xzf ai.tar.gz
mkdir -p ~/bin && cp ai ~/bin/
```

For detailed installation instructions, see **[INSTALL.md](INSTALL.md)**.

### Option 2: Build from Source

```bash
# Build release binary with build date
make release

# Install for current user (no sudo required)
make install-user  # Installs to ~/.local/bin/ai (default)

# Or install to ~/bin
make install-user USER_BIN=~/bin

# Or install system-wide (requires sudo)
sudo make install  # Installs to /usr/local/bin/ai
```

**Uninstall:**
```bash
make uninstall-user  # Remove from user bin
# or
sudo make uninstall  # Remove from /usr/local/bin
```

## Usage

### Basic Examples

```bash
# Simple prompt (direct argument - easiest way)
ai "Write a haiku about coding"

# Or with explicit flag
ai --prompt "Write a haiku about coding"
# or
ai -p "Write a haiku about coding"

# Interactive single prompt
ai
> Type your prompt here
> Press Ctrl+D to submit

# Pipe input from file
cat document.txt | ai --stdin

# With system instruction
ai --system "You are a helpful assistant" "Explain quantum computing"
```

### REPL Mode (Interactive Conversations)

```bash
# Start REPL mode
ai --repl

# REPL with system instruction
ai --repl --system "You are a helpful coding assistant"

# REPL with session saving
ai --repl --save-session chat.jsonl

# REPL with custom context budget (default 2048 tokens for history)
ai --repl --context-tokens 3000
```

The REPL mode maintains conversation history and automatically manages the 4,096 token context window by truncating older messages when needed.

### Output Formats

```bash
# Text output with streaming (default - tokens appear in real-time)
ai "Write a story"

# Disable streaming (buffer complete response)
ai "Write a story" --no-stream

# JSON output (automatically disables streaming)
ai "Hello" --format json

# Verbose mode (shows latency)
ai "Hello" --verbose
```

### Generation Controls

```bash
# Temperature (0.0 = deterministic, 2.0 = creative)
ai --temperature 1.5 "Write a creative story"

# Greedy sampling (deterministic output)
ai --greedy "Generate code"

# Limit response length
ai --max-tokens 50 "Explain AI"
```

### Structured Output

```bash
# Extract contact information
ai --schema contact --format json "Name: John Doe, Email: john@example.com, Phone: 555-1234"

# Extract a list of items
ai --schema list --format json "List the programming languages: Python, JavaScript, Swift"

# Extract task information
ai --schema task --format json "Create a task to update the documentation, high priority, 2 hours"

# Extract multiple tasks
ai --schema task-list --format json "Plan a birthday party"

# Extract key-value pairs
ai --schema key-value --format json "Parse config: debug=true, port=8080, host=localhost"

# Message classification
ai --schema message --format json "Classify this email: URGENT - Server down, need immediate attention"

# Code analysis
ai --schema code-analysis --format json --stdin < mycode.swift
```

Available schemas:
- `contact` - Extract contact info (name, email, phone, address)
- `task` - Single task with title, description, priority
- `task-list` - Multiple tasks
- `code-issue` - Single code issue with severity and suggestion
- `code-analysis` - Multiple code issues with summary
- `message` - Email/message classification (category, sentiment, priority)
- `key-value` - Extract key-value pairs
- `list` - Simple list of strings

## Command-Line Options

```
USAGE: ai [<options>] [<prompt-arg>]

ARGUMENTS:
  <prompt-arg>                     Prompt text (alternative to --prompt)

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
  --schema <schema>                Schema type for structured output (contact, task, task-list, code-issue, code-analysis, message, key-value, list)
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
│   ├── Core/
│   │   ├── TokenEstimator.swift   # Token counting heuristic
│   │   ├── ContextManager.swift   # Context window management
│   │   ├── REPL.swift             # Interactive conversation mode
│   │   ├── Session.swift          # Transcript persistence
│   │   └── Schemas.swift          # Structured output schema definitions (Phase 4)
│   └── Infra/
│       ├── Errors.swift        # Error types and exit codes
│       ├── AvailabilityGuard.swift # Apple Intelligence availability checking
│       └── ModelClient.swift   # FoundationModels wrapper with structured output support
└── Tests/aiTests/
```

## Examples

```bash
# Summarize text
echo "Long article text..." | ai --stdin --system "Summarize this in 3 bullet points"

# Code review
cat myfile.swift | ai --stdin --system "Review this Swift code for potential issues"

# Generate content
ai --temperature 1.8 "Write 5 creative project names for a weather app"

# Extract information (unstructured)
ai --format json "Extract email addresses from this text: Contact us at hello@example.com or support@test.org"

# Extract structured contact information
ai --schema contact --format json "Parse: John Doe, john@company.com, (555) 123-4567"

# Extract list of items
ai --schema list --format json "Find all cities mentioned: I've lived in New York, San Francisco, and Tokyo"

# Interactive coding session
ai --repl --system "You are an expert Swift developer" --save-session coding-session.jsonl

# Long conversation with context management
ai --repl --context-tokens 3000 --verbose
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

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and release notes.

## Release Process

To create a new release:

```bash
# 1. Update version in Scripts/generate-build-info.sh
# 2. Update CHANGELOG.md
# 3. Build and package release
./Scripts/package-release.sh

# 4. Create and push git tag
git tag v0.5.0
git push origin v0.5.0

# 5. Create GitHub release and upload the tarball
```

See `Scripts/package-release.sh` for the complete release workflow including code signing and notarization.

## License

See LICENSE file (if applicable)

## Contributing

This is a personal/educational project. See specification files (specification-v1.txt, specification-v2.md) for design rationale.
