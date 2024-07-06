use std::collections::HashMap;

use anyhow::Result;
use reqwest::{
    header::{HeaderMap, HeaderValue, ACCEPT, USER_AGENT},
    Client,
};

const GITHUB_ACCEPT_HEADER: &str = "application/vnd.github+json";
const GITHUB_API_VERSION: &str = "2022-11-28";
const DISCORD_USER_AGENT: &str = serenity::constants::USER_AGENT;

fn create_headers() -> HeaderMap {
    let mut h = HeaderMap::new();
    h.insert(ACCEPT, HeaderValue::from_static(GITHUB_ACCEPT_HEADER));
    h.insert(
        "X-GitHub-Api-Version",
        HeaderValue::from_static(GITHUB_API_VERSION),
    );
    h.insert(USER_AGENT, HeaderValue::from_static(DISCORD_USER_AGENT));
    h
}

pub(super) async fn repo_languages(owner: &str, repo: &str) -> Result<HashMap<String, u64>> {
    let api_url = format!("https://api.github.com/repos/{owner}/{repo}/languages");

    let client = Client::new();
    let res = client
        .get(&api_url)
        .headers(create_headers())
        .send()
        .await?;

    Ok(res.json::<HashMap<String, u64>>().await?)
}
