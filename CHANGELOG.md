# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2025-12-24

### Added
- Calendar event schema (`--schema calendar`) for extracting event information
- ICS (iCalendar) output format for calendar events
- `--format ics` option for generating .ics files
- Auto-detection: calendar schema defaults to ICS format
- Support for timezone-aware events (TZID field)
- CalendarEvent struct with toICS() method for proper .ics file generation
- Explicit schema field guidance to improve extraction accuracy

### Changed
- Calendar schema outputs .ics format by default (can override with `--format json` for debugging)
- Updated validation to allow `--format ics` only with calendar schema
- Improved structured output prompts to focus on extraction rather than example copying

### Fixed
- Structured output now extracts actual data from input instead of copying example values
- Calendar events now use correct ICS field names (summary, dtstart, dtend, location, description)
- Invalid values ("null" strings, type descriptions) are now filtered out from ICS output

### Known Limitations
- Structured output may vary slightly between runs due to model randomness
- Use `--greedy` or `--temperature 0.0` for more deterministic results
- Optional fields may be omitted by the model; review output before using

### Documentation
- Added calendar schema examples to README
- Documented .ics file format and usage patterns

## [0.5.0] - 2025-12-23

### Added
- **Positional argument support** - Use `ai "prompt"` directly without `-p` flag
- **Build date in version output** - Shows when the binary was compiled
- **Configurable user install directory** - Support for custom `USER_BIN` paths
- **Makefile build system** - Streamlined build, install, and release workflow
- **Build info generation** - Automatic timestamp injection at build time

### Changed
- **Simplified CLI syntax** - Primary usage is now `ai "prompt"` instead of `ai -p "prompt"`
- **Improved interactive mode UX** - Added clear instructions for Ctrl+D submission
- **Updated installation process** - User-local install to `~/bin` or `~/.local/bin` without sudo

### Fixed
- **Compiler warnings** - Removed unused variables in `ContextManager.swift`
- **Interactive mode confusion** - Users now see clear Ctrl+D submission instructions

### Documentation
- Created INSTALL.md for binary distribution
- Created CHANGELOG.md for version tracking
- Updated README with simplified usage examples
- Added release packaging scripts

## [0.4.0] - 2025-12-XX

### Added
- **Structured output with predefined schemas** (Phase 4)
  - Contact information extraction
  - Task and task list parsing
  - Code issue and analysis schemas
  - Message classification
  - Key-value pair extraction
  - String list extraction
- Schema validation and error reporting
- Automatic JSON parsing with markdown code block handling

## [0.3.0] - 2025-12-XX

### Added
- **REPL mode for interactive conversations** (Phase 3)
  - Multi-turn conversation support with `--repl` flag
  - Automatic context window management (4,096 token limit)
  - Smart history truncation (keeps recent messages within budget)
  - Session persistence (save/load in JSONL format)
  - Configurable history budget with `--context-tokens`
  - Token estimation heuristic (~4 chars/token)

## [0.2.0] - 2025-12-XX

### Added
- **Real-time streaming output** (Phase 2)
  - Token-by-token streaming as default for text output
  - See responses appear as they're generated
  - Optional buffered mode with `--no-stream` flag
  - Proper handling of cumulative partial responses

## [0.1.0] - 2025-12-XX

### Added
- **Initial MVP release** (Phase 1)
  - Single-turn prompt/response with Apple Intelligence
  - Multiple input methods (--prompt, --stdin, interactive)
  - Text and JSON output formats
  - System instructions support
  - Generation controls (temperature, greedy, max-tokens)
  - Verbose mode with latency tracking
  - Proper error handling with exit codes
  - 100% on-device processing (fully offline)

### Requirements
- macOS 26.0+ (Tahoe)
- Apple Silicon (M1/M2/M3/M4)
- Apple Intelligence enabled in System Settings

[Unreleased]: https://github.com/yourusername/askai/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/yourusername/askai/releases/tag/v0.5.0
[0.4.0]: https://github.com/yourusername/askai/releases/tag/v0.4.0
[0.3.0]: https://github.com/yourusername/askai/releases/tag/v0.3.0
[0.2.0]: https://github.com/yourusername/askai/releases/tag/v0.2.0
[0.1.0]: https://github.com/yourusername/askai/releases/tag/v0.1.0
