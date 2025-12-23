# Installation Guide

This guide covers installing the pre-built binary from GitHub releases.

## Quick Install

```bash
# Download the latest release
curl -L -o ai.tar.gz https://github.com/yourusername/askai/releases/latest/download/ai-macos-arm64.tar.gz

# Extract the archive
tar -xzf ai.tar.gz

# Install to your local bin directory
mkdir -p ~/bin
cp ai ~/bin/

# Make it executable (should already be, but just in case)
chmod +x ~/bin/ai

# Clean up
rm ai.tar.gz
```

## Prerequisites

- **macOS 26.0+** (Tahoe or later)
- **Apple Silicon** (M1, M2, M3, or M4)
- **Apple Intelligence** enabled in System Settings

## Detailed Installation Steps

### 1. Download the Release

Visit the [Releases page](https://github.com/yourusername/askai/releases) and download the latest `ai-macos-arm64.tar.gz` file.

Alternatively, use `curl`:

```bash
# Download latest release
curl -L -o ai.tar.gz https://github.com/yourusername/askai/releases/latest/download/ai-macos-arm64.tar.gz

# Or download a specific version (e.g., v0.5.0)
curl -L -o ai.tar.gz https://github.com/yourusername/askai/releases/download/v0.5.0/ai-macos-arm64.tar.gz
```

### 2. Extract the Archive

```bash
tar -xzf ai.tar.gz
```

This will extract:
- `ai` - The executable binary
- `README.md` - Quick reference guide
- `LICENSE` - License information (if applicable)

### 3. Install the Binary

Choose one of the following installation methods:

#### Option A: User-local installation (Recommended)

Install to `~/bin` (no sudo required):

```bash
# Create bin directory if it doesn't exist
mkdir -p ~/bin

# Copy the binary
cp ai ~/bin/

# Verify installation
~/bin/ai --version
```

#### Option B: System-wide installation

Install to `/usr/local/bin` (requires sudo):

```bash
sudo cp ai /usr/local/bin/
sudo chmod +x /usr/local/bin/ai

# Verify installation
ai --version
```

### 4. Add to PATH (if needed)

If you installed to `~/bin` and it's not in your PATH, add this to your `~/.zshrc` (or `~/.bashrc` for bash):

```bash
export PATH="$HOME/bin:$PATH"
```

Then reload your shell configuration:

```bash
source ~/.zshrc
```

### 5. Verify Installation

Test that the installation worked:

```bash
ai --version
# Should output: 0.5.0 (built YYYY-MM-DDTHH:MM:SSZ)

ai "what is 2+2?"
# Should output: 2 + 2 equals 4.
```

## First Run on macOS

### If You See "Unidentified Developer" Warning

macOS may show a security warning the first time you run the binary. If the binary is **signed and notarized**, you can simply click "Open" in the dialog.

If the binary is **unsigned** (development build), you'll need to:

**Option 1: Right-click method**
1. Right-click (or Control-click) on the binary in Finder
2. Select "Open"
3. Click "Open" in the dialog

**Option 2: Command-line method**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine ~/bin/ai

# Or for system-wide installation
sudo xattr -d com.apple.quarantine /usr/local/bin/ai
```

After this, the binary will run normally.

## Upgrading

To upgrade to a new version:

```bash
# Download the new version
curl -L -o ai.tar.gz https://github.com/yourusername/askai/releases/latest/download/ai-macos-arm64.tar.gz

# Extract and install (overwrites old version)
tar -xzf ai.tar.gz
cp ai ~/bin/

# Verify new version
ai --version
```

## Uninstalling

To remove the binary:

```bash
# If installed to ~/bin
rm ~/bin/ai

# If installed to /usr/local/bin
sudo rm /usr/local/bin/ai
```

## Troubleshooting

### "command not found: ai"

Your PATH doesn't include the directory where you installed the binary. Either:
1. Use the full path: `~/bin/ai "prompt"`
2. Add the directory to your PATH (see step 4 above)

### "Apple Intelligence not available"

Ensure that:
1. You're running macOS 26.0 (Tahoe) or later: `sw_vers`
2. You have Apple Silicon: `uname -m` should show `arm64`
3. Apple Intelligence is enabled in System Settings → Apple Intelligence

### "Operation not permitted"

The binary doesn't have execute permissions:

```bash
chmod +x ~/bin/ai
```

## Building from Source

If you prefer to build from source instead of using the pre-built binary, see the main [README.md](README.md#installation) for build instructions.

## Getting Help

- **Documentation:** See [README.md](README.md)
- **Version History:** See [CHANGELOG.md](CHANGELOG.md)
- **Issues:** Report bugs at [GitHub Issues](https://github.com/yourusername/askai/issues)
