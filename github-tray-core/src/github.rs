//! GitHub GraphQL API client for pull request searches

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

use crate::pr::{format_relative_time, PRList, PullRequest};

const GITHUB_GRAPHQL_URL: &str = "https://api.github.com/graphql";
const USER_AGENT: &str = "github-tray";

pub struct GitHubClient {
    client: Client,
    api_token: String,
}

impl GitHubClient {
    pub fn new(api_token: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .expect("Failed to create HTTP client");

        Self { client, api_token }
    }

    pub async fn fetch_prs(&self) -> Result<PRList> {
        let review_requested = self.search_prs("is:open is:pr review-requested:@me archived:false").await?;
        let my_open = self.search_prs("is:open is:pr author:@me archived:false").await?;
        let mentioned_in = self.search_prs("is:open is:pr mentions:@me archived:false").await?;

        Ok(PRList {
            review_requested,
            my_open,
            mentioned_in,
        })
    }

    async fn search_prs(&self, query: &str) -> Result<Vec<PullRequest>> {
        let graphql_query = SearchQuery {
            query: query.to_string(),
        };

        let request_body = GraphQLRequest {
            query: SEARCH_QUERY,
            variables: graphql_query,
        };

        let response = self
            .client
            .post(GITHUB_GRAPHQL_URL)
            .header("Authorization", format!("bearer {}", self.api_token))
            .header("User-Agent", USER_AGENT)
            .json(&request_body)
            .send()
            .await
            .with_context(|| "Failed to connect to GitHub GraphQL API")?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(anyhow::anyhow!("GitHub API error ({}): {}", status, body));
        }

        let graphql_response: GraphQLResponse = response
            .json()
            .await
            .context("Failed to parse GitHub GraphQL response")?;

        if let Some(errors) = graphql_response.errors {
            let error_messages: Vec<String> = errors.iter().map(|e| e.message.clone()).collect();
            return Err(anyhow::anyhow!("GraphQL errors: {}", error_messages.join(", ")));
        }

        let prs = graphql_response
            .data
            .search
            .nodes
            .into_iter()
            .filter_map(|node| {
                let SearchNode::PullRequest(pr) = node;
                let updated_at = parse_datetime(&pr.updated_at);
                let created_at = parse_datetime(&pr.created_at);
                let status = map_status(&pr.commits);
                let review_bucket = map_review_bucket(
                    pr.review_decision.as_deref(),
                    pr.review_requests.total_count > 0,
                );

                Some(PullRequest {
                    id: pr.id,
                    title: pr.title,
                    repository: pr.repository.name_with_owner,
                    number: pr.number as u32,
                    html_url: pr.url,
                    author: pr.author?.login,
                    created_at: created_at.map(|dt| dt.to_rfc3339()).unwrap_or_default(),
                    updated_at: updated_at.map(|dt| dt.to_rfc3339()).unwrap_or_default(),
                    display_time: format_relative_time(updated_at),
                    status,
                    review_bucket,
                    is_draft: pr.is_draft,
                })
            })
            .collect();

        Ok(prs)
    }
}

// Note: __typename is required for serde tag-based deserialization
const SEARCH_QUERY: &str = r#"
query($query: String!) {
  search(query: $query, type: ISSUE, first: 100) {
    nodes {
      __typename
      ... on PullRequest {
        id
        title
        url
        number
        isDraft
        createdAt
        updatedAt
        reviewDecision
        author {
          login
        }
        repository {
          nameWithOwner
        }
        reviewRequests(first: 1) {
          totalCount
        }
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup {
                state
                contexts(first: 100) {
                  nodes {
                    __typename
                    ... on CheckRun {
                      status
                    }
                    ... on StatusContext {
                      state
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
"#;

#[derive(Serialize)]
struct GraphQLRequest<T: Serialize> {
    query: &'static str,
    variables: T,
}

#[derive(Serialize)]
struct SearchQuery {
    query: String,
}

#[derive(Debug, Deserialize)]
struct GraphQLResponse {
    data: ResponseData,
    errors: Option<Vec<GraphQLError>>,
}

#[derive(Debug, Deserialize)]
struct GraphQLError {
    message: String,
}

#[derive(Debug, Deserialize)]
struct ResponseData {
    search: SearchResult,
}

#[derive(Debug, Deserialize)]
struct SearchResult {
    nodes: Vec<SearchNode>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "__typename")]
enum SearchNode {
    PullRequest(PullRequestNode),
}

#[derive(Debug, Deserialize)]
struct PullRequestNode {
    id: String,
    title: String,
    url: String,
    number: i32,
    #[serde(rename = "isDraft")]
    is_draft: bool,
    #[serde(rename = "createdAt")]
    created_at: String,
    #[serde(rename = "updatedAt")]
    updated_at: String,
    #[serde(rename = "reviewDecision")]
    review_decision: Option<String>,
    author: Option<Author>,
    repository: Repository,
    #[serde(rename = "reviewRequests")]
    review_requests: ReviewRequestConnection,
    commits: CommitConnection,
}

#[derive(Debug, Deserialize)]
struct Author {
    login: String,
}

#[derive(Debug, Deserialize)]
struct Repository {
    #[serde(rename = "nameWithOwner")]
    name_with_owner: String,
}

#[derive(Debug, Deserialize)]
struct ReviewRequestConnection {
    #[serde(rename = "totalCount")]
    total_count: i32,
}

#[derive(Debug, Deserialize)]
struct CommitConnection {
    nodes: Vec<CommitNode>,
}

#[derive(Debug, Deserialize)]
struct CommitNode {
    commit: Commit,
}

#[derive(Debug, Deserialize)]
struct Commit {
    #[serde(rename = "statusCheckRollup")]
    status_check_rollup: Option<StatusCheckRollup>,
}

#[derive(Debug, Deserialize)]
struct StatusCheckRollup {
    state: String,
    contexts: Option<StatusCheckContexts>,
}

#[derive(Debug, Deserialize)]
struct StatusCheckContexts {
    nodes: Vec<StatusCheckContextNode>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "__typename")]
enum StatusCheckContextNode {
    CheckRun(CheckRunContext),
    StatusContext(StatusContextNode),
}

#[derive(Debug, Deserialize)]
struct CheckRunContext {
    status: String,
}

#[derive(Debug, Deserialize)]
struct StatusContextNode {
    state: String,
}

fn parse_datetime(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

fn map_status(commits: &CommitConnection) -> String {
    let rollup = commits
        .nodes
        .first()
        .and_then(|node| node.commit.status_check_rollup.as_ref());

    if has_running_checks(rollup) {
        return "pending".to_string();
    }

    let state = rollup.map(|rollup| rollup.state.as_str());

    match state {
        Some("SUCCESS") => "success".to_string(),
        Some("FAILURE") | Some("ERROR") | Some("TIMED_OUT") | Some("ACTION_REQUIRED") => {
            "failure".to_string()
        }
        Some("EXPECTED")
        | Some("PENDING")
        | Some("QUEUED")
        | Some("IN_PROGRESS")
        | Some("WAITING")
        | Some("REQUESTED")
        | Some("STALE") => "pending".to_string(),
        Some("NEUTRAL") | None => "none".to_string(),
        _ => "none".to_string(),
    }
}

fn map_review_bucket(review_decision: Option<&str>, has_outstanding_review_requests: bool) -> String {
    match review_decision {
        Some("APPROVED") if !has_outstanding_review_requests => "approved".to_string(),
        Some("CHANGES_REQUESTED") if !has_outstanding_review_requests => "returned_to_you".to_string(),
        _ => "none".to_string(),
    }
}

fn has_running_checks(rollup: Option<&StatusCheckRollup>) -> bool {
    let Some(rollup) = rollup else {
        return false;
    };

    let Some(contexts) = rollup.contexts.as_ref() else {
        return false;
    };

    contexts.nodes.iter().any(|node| match node {
        StatusCheckContextNode::CheckRun(check_run) => matches!(
            check_run.status.as_str(),
            "IN_PROGRESS" | "QUEUED" | "PENDING" | "WAITING" | "REQUESTED"
        ),
        StatusCheckContextNode::StatusContext(context) => context.state == "PENDING",
    })
}

#[cfg(test)]
mod tests {
    use super::map_review_bucket;

    #[test]
    fn approved_pr_with_no_pending_reviews_stays_approved() {
        assert_eq!(map_review_bucket(Some("APPROVED"), false), "approved");
    }

    #[test]
    fn approved_pr_with_pending_review_request_is_not_approved() {
        assert_eq!(map_review_bucket(Some("APPROVED"), true), "none");
    }

    #[test]
    fn changes_requested_with_pending_review_request_is_not_returned_to_you() {
        assert_eq!(map_review_bucket(Some("CHANGES_REQUESTED"), true), "none");
    }
}
