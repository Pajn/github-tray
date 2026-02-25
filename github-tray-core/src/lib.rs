//! GitHub Tray Core
//!
//! This library provides the core functionality for GitHub Tray,
//! a macOS menu bar application for GitHub pull requests.

uniffi::setup_scaffolding!();

mod autostart;
mod config;
mod core;
mod github;
mod pr;

pub use config::Config;
pub use core::{AppState, EventHandler, GitHubTrayCore, GitHubTrayError};
pub use github::GitHubClient;
pub use pr::{PRList, PullRequest};
