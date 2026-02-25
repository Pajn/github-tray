//! Core FFI facade for GitHub Tray
//!
//! This module provides the main interface exposed to Swift via UniFFI.

use crate::autostart;
use crate::config::Config;
use crate::github::GitHubClient;
use crate::pr::PRList;
use std::sync::Arc;
use std::sync::LazyLock;
use std::time::Duration;
use tokio::sync::Mutex;

static TOKIO_RUNTIME: LazyLock<tokio::runtime::Runtime> = LazyLock::new(|| {
    eprintln!("[Rust] Creating Tokio runtime...");
    let rt = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .expect("Failed to create tokio runtime");
    eprintln!("[Rust] Tokio runtime created successfully");
    rt
});

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum GitHubTrayError {
    #[error("Configuration error: {message}")]
    Config { message: String },

    #[error("Network error: {message}")]
    Network { message: String },

    #[error("Unexpected error: {message}")]
    Unexpected { message: String },
}

impl From<anyhow::Error> for GitHubTrayError {
    fn from(err: anyhow::Error) -> Self {
        GitHubTrayError::Unexpected {
            message: err.to_string(),
        }
    }
}

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct AppState {
    pub review_count: u32,
    pub my_pr_count: u32,
    pub mentioned_count: u32,
    pub prs: PRList,
    pub autostart_enabled: bool,
    pub is_loading: bool,
    pub error_message: Option<String>,
}

#[uniffi::export(with_foreign)]
pub trait EventHandler: Send + Sync {
    fn on_state_changed(&self, state: AppState);
    fn on_error(&self, error: String);
}

#[derive(uniffi::Object)]
pub struct GitHubTrayCore {
    state: Arc<Mutex<AppState>>,
    github_client: Arc<GitHubClient>,
    refresh_interval_secs: u64,
    event_handler: Arc<dyn EventHandler>,
}

#[uniffi::export]
impl GitHubTrayCore {
    #[uniffi::constructor]
    pub fn new(event_handler: Arc<dyn EventHandler>) -> Result<Arc<Self>, GitHubTrayError> {
        eprintln!("[Rust] GitHubTrayCore::new() called");

        let _runtime = &*TOKIO_RUNTIME;
        eprintln!("[Rust] Runtime initialized");

        let config = Config::load().map_err(|e| {
            eprintln!("[Rust] Config load error: {}", e);
            GitHubTrayError::Config {
                message: e.to_string(),
            }
        })?;
        eprintln!("[Rust] Config loaded successfully");

        let github_client = Arc::new(GitHubClient::new(config.github_token));
        let autostart_enabled = autostart::is_enabled();

        if config.autostart && !autostart_enabled {
            let _ = autostart::enable();
        } else if !config.autostart && autostart_enabled {
            let _ = autostart::disable();
        }

        let refresh_interval_secs = config.refresh_interval_secs;

        let core = Arc::new(Self {
            state: Arc::new(Mutex::new(AppState {
                autostart_enabled: autostart::is_enabled(),
                is_loading: true,
                ..Default::default()
            })),
            github_client,
            refresh_interval_secs,
            event_handler,
        });

        let core_clone = core.clone();
        std::thread::spawn(move || {
            eprintln!("[Rust] Background thread started, entering tokio runtime...");
            TOKIO_RUNTIME.block_on(async move {
                eprintln!("[Rust] Inside tokio runtime, starting background task...");

                eprintln!("[Rust] About to call refresh_prs()...");
                if let Err(e) = refresh_prs(&core_clone).await {
                    eprintln!("[Rust] Initial refresh failed: {}", e);
                }
                eprintln!("[Rust] Initial refresh complete");

                let mut interval = tokio::time::interval(Duration::from_secs(core_clone.refresh_interval_secs));
                loop {
                    interval.tick().await;
                    if let Err(e) = refresh_prs(&core_clone).await {
                        eprintln!("[Rust] Refresh failed: {}", e);
                    }
                }
            });
        });

        eprintln!("[Rust] GitHubTrayCore::new() returning...");

        Ok(core)
    }

    pub fn refresh(&self) -> Result<(), GitHubTrayError> {
        TOKIO_RUNTIME.block_on(async { refresh_prs(self).await })
    }

    pub fn get_state(&self) -> AppState {
        TOKIO_RUNTIME.block_on(async { self.state.lock().await.clone() })
    }

    pub fn toggle_autostart(&self) -> Result<bool, GitHubTrayError> {
        let enabled = if autostart::is_enabled() {
            autostart::disable().map_err(|e| GitHubTrayError::Unexpected {
                message: e.to_string(),
            })?;
            false
        } else {
            autostart::enable().map_err(|e| GitHubTrayError::Unexpected {
                message: e.to_string(),
            })?;
            true
        };

        let state = self.state.clone();
        let event_handler = self.event_handler.clone();
        TOKIO_RUNTIME.spawn(async move {
            let mut s = state.lock().await;
            s.autostart_enabled = enabled;
            let state_copy = s.clone();
            drop(s);
            event_handler.on_state_changed(state_copy);
        });

        Ok(enabled)
    }

    pub fn is_autostart_enabled(&self) -> bool {
        autostart::is_enabled()
    }
}

async fn refresh_prs(core: &GitHubTrayCore) -> Result<(), GitHubTrayError> {
    let prs = core
        .github_client
        .fetch_prs()
        .await
        .map_err(|e| GitHubTrayError::Network {
            message: e.to_string(),
        })?;

    let mut state = core.state.lock().await;
    state.review_count = prs.review_requested.len() as u32;
    state.my_pr_count = prs.my_open.len() as u32;
    state.mentioned_count = prs.mentioned_in.len() as u32;
    state.prs = prs;
    state.is_loading = false;
    state.error_message = None;

    let state_copy = state.clone();
    drop(state);

    core.event_handler.on_state_changed(state_copy);

    Ok(())
}
