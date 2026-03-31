//! Pull Request data structures

use chrono::{DateTime, Utc};

#[derive(uniffi::Record, Clone, Debug)]
pub struct PullRequest {
    pub id: String,
    pub title: String,
    pub repository: String,
    pub number: u32,
    pub html_url: String,
    pub author: String,
    pub created_at: String,
    pub updated_at: String,
    pub display_time: String,
    pub status: String,
    pub review_bucket: String,
    pub is_draft: bool,
}

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct PRList {
    pub review_requested: Vec<PullRequest>,
    pub my_open: Vec<PullRequest>,
    pub mentioned_in: Vec<PullRequest>,
}

pub fn format_relative_time(updated_at: Option<DateTime<Utc>>) -> String {
    let Some(updated_at) = updated_at else {
        return "recent".to_string();
    };

    let now = Utc::now();
    let diff = now.signed_duration_since(updated_at);
    if diff.num_weeks() > 0 {
        format!("{}w ago", diff.num_weeks())
    } else if diff.num_days() > 0 {
        format!("{}d ago", diff.num_days())
    } else if diff.num_hours() > 0 {
        format!("{}h ago", diff.num_hours())
    } else if diff.num_minutes() > 0 {
        format!("{}m ago", diff.num_minutes())
    } else {
        "now".to_string()
    }
}
