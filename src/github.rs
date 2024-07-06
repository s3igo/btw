use std::collections::HashMap;

use anyhow::{ensure, Context as _, Result};
use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, USER_AGENT};
use url::Url;

fn parse_url(url: &str) -> Result<(String, String)> {
    let url = Url::parse(url).context("Failed to parse URL")?;

    ensure!(url.host_str() == Some("github.com"), "Host is not github");

    let mut path_segments = url.path_segments().context("Invalid URL path")?;

    let owner = path_segments.next().context("Missing owner in URL path")?;
    let repo = path_segments.next().context("Missing repo in URL path")?;
    ensure!(path_segments.next().is_none(), "URL path is too long");

    Ok((owner.to_string(), repo.to_string()))
}

pub(crate) async fn check_repo_language(url: &str) -> Result<()> {
    let (owner, repo) = parse_url(url)?;

    // send request to GitHub API
    let api_url = format!("https://api.github.com/repos/{owner}/{repo}/languages");
    let headers = {
        let mut h = HeaderMap::new();
        h.insert(
            ACCEPT,
            HeaderValue::from_static("application/vnd.github+json"),
        );
        h.insert(
            "X-GitHub-Api-Version",
            HeaderValue::from_static("2022-11-28"),
        );
        h.insert(
            USER_AGENT,
            HeaderValue::from_static(serenity::constants::USER_AGENT),
        );
        h
    };

    let client = reqwest::Client::new();
    let res = client.get(&api_url).headers(headers).send().await?;
    let res = res.json::<HashMap<String, u64>>().await?;

    let (lang, _) = res
        .iter()
        .max_by_key(|(_, &v)| v)
        .context("Languages not defined")?;

    ensure!(lang == "Rust", "Primary language is not Rust");

    Ok(())
}
