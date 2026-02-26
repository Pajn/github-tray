# GitHub Tray

A native macOS menu bar app that keeps your GitHub pull requests visible at a glance.

GitHub Tray shows PRs in focused sections and lets you jump straight to each PR from the menu bar.

## What It Does

- Shows **Review Requested** PRs in your menu bar.
- Splits your authored PRs into:
  - **Approved**
  - **Returned to You**
  - **My Open PRs** (everything else)
- Shows PRs where you are **Mentioned In**.
- Displays per-PR status indicators for checks (pending, success, failure).
- Supports optional launch-at-login (**Autostart**).

## Tech Stack

- **Rust** core (`github-tray-core`) for GitHub API access and app state.
- **UniFFI** for Rust <-> Swift bindings.
- **Swift/AppKit** macOS menu bar UI (`SwiftApp`).
- **Tokio + Reqwest** for async GitHub calls.

## Project Layout

```text
github-tray/
├── Cargo.toml
├── justfile
├── build-xcode.sh
├── github-tray-core/          # Rust core + UniFFI
│   └── src/
└── SwiftApp/                  # Swift macOS app
    ├── project.yml            # XcodeGen spec
    └── GitHubTray/
        └── Sources/
```

## Prerequisites

- macOS
- Xcode + Xcode Command Line Tools
- Rust (stable)
- [`just`](https://github.com/casey/just)
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen)

Install helpers:

```bash
cargo install just
brew install xcodegen
```

## Configuration

Create config file:

```bash
just setup-config
```

This creates:

- `~/Library/Application Support/github-tray/config.toml`

Example:

```toml
github_token = "ghp_xxx"
refresh_interval_secs = 300
autostart = true
```

Token notes:

- Use a GitHub Personal Access Token.
- `repo` scope is required for private repositories.

## Build & Run

### First time

```bash
just gen-xcode
just fresh
```

### Day-to-day

```bash
just run
```

### Build only

```bash
just build-app
```

App bundle output:

- `SwiftApp/build/Build/Products/Release/GitHubTray.app`

## Development Commands

```bash
just check       # cargo check
just test        # cargo test
just lint        # cargo clippy -- -D warnings
just fmt         # cargo fmt
just ci          # fmt-check + lint + test + check
```

Useful:

```bash
just clean       # clear Rust + Xcode build artifacts
just rebuild     # clean + build app
just open-bundle # open existing built app
```

## How It Works

1. Swift app starts `GitHubTrayCore` (Rust).
2. Rust loads config from `~/Library/Application Support/github-tray/config.toml`.
3. Rust fetches PRs from GitHub GraphQL API on an interval.
4. Rust sends `AppState` updates via UniFFI callback trait.
5. Swift rebuilds the menu UI from the latest state.

## Troubleshooting

### "Config file not found"

Run:

```bash
just setup-config
```

### "Failed to parse config" or token errors

Verify `github_token` is set and not placeholder text.

### Xcode project missing

Run:

```bash
just gen-xcode
```

### Swift/UI not reflecting Rust changes

Run a full rebuild:

```bash
just rebuild
```

### Open app manually

```bash
open SwiftApp/build/Build/Products/Release/GitHubTray.app
```

## License

MIT
