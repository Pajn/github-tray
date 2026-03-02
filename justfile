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

# Build Rust xcframework for Swift (incremental - only rebuilds if Rust files changed)
build-xcframework:
    #!/usr/bin/env bash
    set -e
    STAMP_FILE="target/.xcframework_stamp"
    RUST_FILES=$(find github-tray-core/src -name "*.rs" -newer "$STAMP_FILE" 2>/dev/null | head -1)
    LIB_FILE="target/aarch64-apple-darwin/release/libgithub_tray_core.a"
    XCFRAMEWORK="SwiftApp/GitHubTray/github_tray_core.xcframework"
    GENERATED="SwiftApp/GitHubTray/Generated/github_tray_core.swift"

    if [[ -z "$RUST_FILES" && -f "$LIB_FILE" && -d "$XCFRAMEWORK" && -f "$GENERATED" && -f "$STAMP_FILE" ]]; then
        echo "Rust xcframework is up to date, skipping build"
        exit 0
    fi

    echo "Building Rust xcframework..."
    cargo build -p github-tray-core --release --target aarch64-apple-darwin

    mkdir -p SwiftApp/GitHubTray/Generated
    cargo run -p github-tray-core --bin uniffi-bindgen generate \
        --library target/aarch64-apple-darwin/release/libgithub_tray_core.a \
        --language swift \
        --out-dir SwiftApp/GitHubTray/Generated

    if [ -f "SwiftApp/GitHubTray/Generated/github_tray_coreFFI.modulemap" ]; then
        mv "SwiftApp/GitHubTray/Generated/github_tray_coreFFI.modulemap" \
           "SwiftApp/GitHubTray/Generated/module.modulemap"
    fi

    rm -rf "$XCFRAMEWORK"
    xcodebuild -create-xcframework \
        -library target/aarch64-apple-darwin/release/libgithub_tray_core.a \
        -headers SwiftApp/GitHubTray/Generated \
        -output "$XCFRAMEWORK"

    touch "$STAMP_FILE"
    echo "Rust xcframework built successfully"

# Generate Xcode project (requires xcodegen)
gen-xcode:
    cd SwiftApp && xcodegen generate

# Regenerate Xcode project with fresh build settings
gen-xcode-fresh: gen-xcode build-xcframework

# Build the macOS app (incremental - may use cached Rust code)
build-app: build-xcframework
    ./build-xcode.sh

# Fast rebuild - cleans Rust artifacts but preserves Swift build cache (faster when changing Rust code)
rebuild: kill clean-rust build-xcframework
    ./build-xcode.sh

# Force a complete rebuild from scratch (slowest, most thorough)
rebuild-full: kill clean build-xcframework
    ./build-xcode.sh

# Build and run (incremental)
run: build-app
    open SwiftApp/build/Build/Products/Release/GitHubTray.app

# Rebuild from scratch and run (use this when Rust code changed)
fresh: rebuild-full
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

clean-rust:
    rm -rf SwiftApp/GitHubTray/github_tray_core.xcframework SwiftApp/GitHubTray/Generated

# Update dependencies
update:
    cargo update

# Show dependency tree
deps:
    cargo tree

# Kill any running GitHubTray instances
kill:
    killall GitHubTray 2>/dev/null || true
