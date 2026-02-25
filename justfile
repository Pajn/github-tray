# GitHub Tray - Justfile
# Install just: cargo install just

# Default: show available commands
default:
    @just --list

# Build the Rust core library
build-core:
    cd github-tray-core && cargo build

# Build the Rust core library (release)
build-core-release:
    cd github-tray-core && cargo build --release

# Generate Xcode project (requires xcodegen)
gen-xcode:
    cd SwiftApp && xcodegen generate

# Build the macOS app (incremental - may use cached Rust code)
build-app:
    ./build-xcode.sh

# Force a complete rebuild from scratch (recommended when Rust code changed)
rebuild: kill clean
    ./build-xcode.sh

# Build and run (incremental)
run: build-app
    open SwiftApp/build/Build/Products/Release/GitHubTray.app

# Rebuild from scratch and run (use this when Rust code changed)
fresh: rebuild
    open SwiftApp/build/Build/Products/Release/GitHubTray.app

# Open the built app (no rebuild)
open-bundle:
    open SwiftApp/build/Build/Products/Release/GitHubTray.app

# Run tests
test:
    cargo test

# Check for compilation errors
check:
    cargo check

# Check with all warnings
check-all:
    RUSTFLAGS="-D warnings" cargo check

# Format code
fmt:
    cargo fmt

# Check formatting
fmt-check:
    cargo fmt --check

# Run clippy linter
lint:
    cargo clippy -- -D warnings

# Run all quality checks
ci: fmt-check lint test
    cargo check

# Create config directory and template
setup-config:
    mkdir -p ~/Library/Application\ Support/github-tray
    @echo 'github_token = "YOUR_GITHUB_TOKEN_HERE"' > ~/Library/Application\ Support/github-tray/config.toml
    @echo '# Optional: refresh interval in seconds (default: 300)' >> ~/Library/Application\ Support/github-tray/config.toml
    @echo '# refresh_interval_secs = 300' >> ~/Library/Application\ Support/github-tray/config.toml
    @echo '# Optional: autostart on login (default: false)' >> ~/Library/Application\ Support/github-tray/config.toml
    @echo '# autostart = true' >> ~/Library/Application\ Support/github-tray/config.toml
    @echo "Config created at ~/Library/Application Support/github-tray/config.toml"
    @echo "Edit it with your GitHub Personal Access Token from:"
    @echo "  https://github.com/settings/tokens"
    @echo "The token needs 'repo' scope for private repositories."

# Show config location
config-path:
    @echo "Config file: ~/Library/Application Support/github-tray/config.toml"

# Install xcodegen (required for building)
install-xcodegen:
    brew install xcodegen

# Clean all build artifacts
clean:
    cargo clean
    rm -rf SwiftApp/build SwiftApp/GitHubTray/github_tray_core.xcframework SwiftApp/GitHubTray/Generated

# Update dependencies
update:
    cargo update

# Show dependency tree
deps:
    cargo tree

# Kill any running GitHubTray instances
kill:
    killall GitHubTray 2>/dev/null || true
