//! Configuration management

use anyhow::{Context, Result};
use serde::Deserialize;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub github_token: String,

    #[serde(default = "default_refresh_interval")]
    pub refresh_interval_secs: u64,

    #[serde(default)]
    pub autostart: bool,
}

fn default_refresh_interval() -> u64 {
    300
}

impl Config {
    pub fn load() -> Result<Self> {
        let config_path = Self::config_path()?;

        if !config_path.exists() {
            return Err(anyhow::anyhow!(
                "Config file not found at {:?}\n\n\
                Please create it with your GitHub Personal Access Token:\n\n\
                mkdir -p ~/Library/Application\\ Support/github-tray\n\
                echo 'github_token = \"YOUR_TOKEN_HERE\"' > ~/Library/Application\\ Support/github-tray/config.toml\n\n\
                The token needs 'repo' scope for private repositories.\n\
                Get your token from: https://github.com/settings/tokens",
                config_path
            ));
        }

        let content = fs::read_to_string(&config_path).context("Failed to read config file")?;

        let config: Config = toml::from_str(&content).context("Failed to parse config file")?;

        if config.github_token.is_empty() || config.github_token == "YOUR_TOKEN_HERE" {
            return Err(anyhow::anyhow!(
                "Please set your actual GitHub token in {:?}",
                config_path
            ));
        }

        Ok(config)
    }

    pub fn config_path() -> Result<PathBuf> {
        let config_dir = dirs::config_dir().context("Could not find config directory")?;
        Ok(config_dir.join("github-tray").join("config.toml"))
    }

    pub fn config_dir() -> Result<PathBuf> {
        let config_dir = dirs::config_dir().context("Could not find config directory")?;
        Ok(config_dir.join("github-tray"))
    }
}
