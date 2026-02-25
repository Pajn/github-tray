# AGENTS.md - Technical Documentation for AI Agents

> This document provides technical context for AI assistants working on this codebase.

## Project Overview

**Name:** GitHub Tray  
**Type:** macOS menubar application  
**Language:** Rust (Edition 2021) + Swift (via UniFFI)  
**Purpose:** Display GitHub pull requests in macOS menu bar with three categories

## Architecture

```
github-tray/
├── Cargo.toml                  # Workspace config
├── justfile                    # Build commands
├── build-xcode.sh              # Xcode build script
├── AGENTS.md                   # This file
├── github-tray-core/           # Rust core library (UniFFI)
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs              # UniFFI scaffolding
│       ├── core.rs             # Main facade + EventHandler trait
│       ├── github.rs           # GitHub API client
│       ├── config.rs           # Config loading
│       ├── autostart.rs        # macOS LaunchAgent
│       └── pr.rs               # PR data structures
└── SwiftApp/                   # Swift macOS app
    ├── project.yml             # XcodeGen config
    └── GitHubTray/
        ├── Info.plist
        ├── GitHubTray.entitlements
        └── Sources/
            ├── main.swift
            ├── AppDelegate.swift
            ├── StatusBarController.swift
            ├── PRMenuItemView.swift
            └── GitHubTrayEventHandler.swift
```

### Data Flow

```
[Config] → [GitHubClient] ←──→ [GitHub API]
                ↓
           [AppState] (Arc<Mutex<AppState>>)
                ↓
          [StatusBarController] → [NSMenu]
                ↓
           [User Click] → [NSWorkspace.open(url)]
```

## Key Dependencies

| Crate | Version | Purpose |
|-------|---------|---------|
| `uniffi` | 0.28 | FFI bindings for Swift |
| `tokio` | 1.x | Async runtime |
| `reqwest` | 0.12 | HTTP client with JSON support |
| `serde` / `serde_json` | 1.x | JSON/TOML parsing |
| `chrono` | 0.4 | Date/time handling |
| `dirs` | 5.x | Config directory paths |
| `anyhow` / `thiserror` | 1.x | Error handling |

## API Details

### GitHub Search API

**Base URL:** `https://api.github.com`

**Authentication:** Bearer token in `Authorization` header

```rust
// Search for PRs (GET /search/issues)
GET /search/issues?q=is:open%20is:pr%20review-requested:@me%20archived:false
Authorization: Bearer {token}
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
User-Agent: github-tray

// Response
{
  "items": [
    {
      "node_id": "PR_xxx",
      "title": "Fix memory leak",
      "html_url": "https://github.com/owner/repo/pull/123",
      "user": { "login": "username" },
      "created_at": "2026-02-20T14:00:00Z",
      "updated_at": "2026-02-21T10:30:00Z"
    }
  ]
}
```

### Search Queries

| Category | Query |
|----------|-------|
| Review Requested | `is:open is:pr review-requested:@me archived:false` |
| My Open PRs | `is:open is:pr author:@me archived:false` |
| Mentioned In | `is:open is:pr mentions:@me archived:false` |

### Data Structures

```rust
#[derive(uniffi::Record, Clone)]
pub struct PullRequest {
    pub id: String,           // PR node_id for uniqueness
    pub title: String,
    pub repository: String,   // "owner/repo"
    pub number: u32,
    pub html_url: String,
    pub author: String,
    pub created_at: String,
    pub updated_at: String,
    pub display_time: String, // "2h ago", "1d ago"
}

#[derive(uniffi::Record, Clone, Default)]
pub struct PRList {
    pub review_requested: Vec<PullRequest>,
    pub my_open: Vec<PullRequest>,
    pub mentioned_in: Vec<PullRequest>,
}

#[derive(uniffi::Record, Clone)]
pub struct AppState {
    pub review_count: u32,
    pub my_pr_count: u32,
    pub mentioned_count: u32,
    pub prs: PRList,
    pub autostart_enabled: bool,
    pub is_loading: bool,
    pub error_message: Option<String>,
}
```

## UniFFI Architecture

### Thread Safety

- `AppState` is wrapped in `Arc<Mutex<_>>` for shared access
- `GitHubClient` is wrapped in `Arc` for cheap cloning
- `GitHubTrayCore` is NOT `Send` - must stay on main thread
- Async operations use `tokio::spawn` and send results via EventHandler trait

### EventHandler Pattern

```rust
#[uniffi::export(with_foreign)]
pub trait EventHandler: Send + Sync {
    fn on_state_changed(&self, state: AppState);
    fn on_error(&self, error: String);
}
```

Swift implements this trait:
```swift
class GitHubTrayEventHandler: EventHandler {
    weak var controller: StatusBarController?
    
    func onStateChanged(state: AppState) {
        DispatchQueue.main.async { [weak self] in
            self?.controller?.updateState(state)
        }
    }
    
    func onError(error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.controller?.showError(error)
        }
    }
}
```

## Configuration

**Location (macOS):** `~/Library/Application Support/github-tray/config.toml`

```toml
github_token = "ghp_xxxx"  # Personal access token with 'repo' scope

# Optional settings
refresh_interval_secs = 300  # Default: 5 minutes
autostart = true
```

## Menu Structure

```
GH [total]  ← menubar title

Review Requested (3)
  ── Fix memory leak in cache · owner/repo · 2h ago
  ── Add dark mode support · owner/repo · 5h ago

My Open PRs (2)
  ── Refactor API client · owner/repo · 1d ago

Mentioned In (1)
  ── Review needed: auth flow · owner/repo · 3h ago

───────────────
Refresh        ⌘R
✓ Autostart
───────────────
Quit           ⌘Q
```

## Build Commands

```bash
# Development
just build-core          # Build Rust library
just build-app           # Build .app bundle via Xcode
just run                 # Build and open app

# Production
just fresh               # Clean rebuild and run

# Quality
just lint                # Run clippy
just fmt                 # Format code
just ci                  # All checks

# Setup
just setup-config        # Create config template
```

## Error Handling

- Uses `anyhow::Result` throughout
- Errors are logged via `tracing`
- User-facing errors shown in tray tooltip with "!" in title
- API errors don't crash the app - graceful degradation

## Platform Notes

- **macOS only** - Uses macOS-specific APIs for tray and autostart
- **Requires main thread** - Event loop must run on main thread
- **Bundle ID:** `com.github-tray.app`
- **Autostart** uses LaunchAgent at `~/Library/LaunchAgents/com.github-tray.app.plist`
