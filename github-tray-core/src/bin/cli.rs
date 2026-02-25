//! CLI tool for testing GitHub Tray core functionality

use anyhow::Result;
use github_tray_core::{Config, GitHubClient};

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    println!("Loading config...");
    let config = Config::load()?;
    println!("Config loaded from: {:?}", Config::config_path()?);

    println!("\nFetching PRs from GitHub (using GraphQL)...");
    let client = GitHubClient::new(config.github_token);

    match client.fetch_prs().await {
        Ok(pr_list) => {
            println!(
                "\n=== Review Requested ({}) ===",
                pr_list.review_requested.len()
            );
            for pr in &pr_list.review_requested {
                println!(
                    "  [{}] {} - {} - {} - draft={}",
                    pr.status, pr.title, pr.repository, pr.display_time, pr.is_draft
                );
                println!("    {}", pr.html_url);
            }

            println!("\n=== My Open PRs ({}) ===", pr_list.my_open.len());
            for pr in &pr_list.my_open {
                println!(
                    "  [{}] {} - {} - {} - draft={}",
                    pr.status, pr.title, pr.repository, pr.display_time, pr.is_draft
                );
                println!("    {}", pr.html_url);
            }

            println!("\n=== Mentioned In ({}) ===", pr_list.mentioned_in.len());
            for pr in &pr_list.mentioned_in {
                println!(
                    "  [{}] {} - {} - {} - draft={}",
                    pr.status, pr.title, pr.repository, pr.display_time, pr.is_draft
                );
                println!("    {}", pr.html_url);
            }

            println!(
                "\nTotal: {} PRs",
                pr_list.review_requested.len() + pr_list.my_open.len() + pr_list.mentioned_in.len()
            );
        }
        Err(e) => {
            eprintln!("\nError fetching PRs: {:?}", e);
            return Err(e);
        }
    }

    Ok(())
}
