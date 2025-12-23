.PHONY: build release clean test install install-user uninstall uninstall-user

# User bin directory (customize with: make install-user USER_BIN=~/bin)
USER_BIN ?= ~/.local/bin

# Build in debug mode
build:
	@./Scripts/generate-build-info.sh
	@swift build

# Build in release mode
release:
	@./Scripts/generate-build-info.sh
	@swift build -c release

# Clean build artifacts
clean:
	@swift package clean

# Run tests
test:
	@./Scripts/generate-build-info.sh
	@swift test

# Install to user bin directory (no sudo required)
install-user: release
	@mkdir -p $(USER_BIN)
	@cp .build/release/ai $(USER_BIN)/ai
	@chmod +x $(USER_BIN)/ai
	@echo "Installed ai to $(USER_BIN)/ai"
	@echo ""
	@if [ "$(USER_BIN)" = "$$HOME/bin" ]; then \
		echo "Make sure ~/bin is in your PATH."; \
		echo "If not, add this to your ~/.zshrc or ~/.bashrc:"; \
		echo '  export PATH="$$HOME/bin:$$PATH"'; \
	else \
		echo "Make sure $(USER_BIN) is in your PATH."; \
		echo "If not, add this to your ~/.zshrc or ~/.bashrc:"; \
		echo '  export PATH="$(USER_BIN):$$PATH"'; \
	fi

# Install to /usr/local/bin (requires sudo)
install: release
	@install .build/release/ai /usr/local/bin/ai
	@echo "Installed ai to /usr/local/bin/ai"

# Uninstall from user bin directory
uninstall-user:
	@rm -f $(USER_BIN)/ai
	@echo "Uninstalled ai from $(USER_BIN)"

# Uninstall from /usr/local/bin
uninstall:
	@rm -f /usr/local/bin/ai
	@echo "Uninstalled ai from /usr/local/bin"
