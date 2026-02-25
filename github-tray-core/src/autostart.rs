//! macOS LaunchAgent management for autostart functionality

use anyhow::{Context, Result};
use std::fs;
use std::path::PathBuf;

const BUNDLE_ID: &str = "com.github-tray.app";

fn plist_path() -> Result<PathBuf> {
    let home = dirs::home_dir().context("Could not find home directory")?;
    Ok(home
        .join("Library")
        .join("LaunchAgents")
        .join(format!("{}.plist", BUNDLE_ID)))
}

fn generate_plist_content(executable: &std::path::Path) -> String {
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{bundle_id}</string>
    <key>ProgramArguments</key>
    <array>
        <string>{executable}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
"#,
        bundle_id = BUNDLE_ID,
        executable = executable.display()
    )
}

pub fn is_enabled() -> bool {
    plist_path().map(|path| path.exists()).unwrap_or(false)
}

pub fn enable() -> Result<()> {
    let plist_path = plist_path()?;
    let executable =
        std::env::current_exe().context("Could not determine current executable path")?;

    if let Some(parent) = plist_path.parent() {
        if !parent.exists() {
            fs::create_dir_all(parent).context("Failed to create LaunchAgents directory")?;
        }
    }

    let content = generate_plist_content(&executable);
    fs::write(&plist_path, content).context("Failed to write LaunchAgent plist file")?;

    tracing::info!("Autostart enabled: created LaunchAgent at {:?}", plist_path);
    Ok(())
}

pub fn disable() -> Result<()> {
    let plist_path = plist_path()?;

    if plist_path.exists() {
        fs::remove_file(&plist_path).context("Failed to remove LaunchAgent plist file")?;
        tracing::info!(
            "Autostart disabled: removed LaunchAgent at {:?}",
            plist_path
        );
    }

    Ok(())
}
