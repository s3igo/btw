const GITHUB_ACCEPT_HEADER: &str = "application/vnd.github+json";
const GITHUB_API_VERSION: &str = "2022-11-28";
const DISCORD_USER_AGENT: &str = serenity::constants::USER_AGENT;

fn headers() -> reqwest::header::HeaderMap {
    use reqwest::header;

    let mut h = header::HeaderMap::new();
    h.insert(
        header::ACCEPT,
        header::HeaderValue::from_static(GITHUB_ACCEPT_HEADER),
    );
    h.insert(
        "X-GitHub-Api-Version",
        header::HeaderValue::from_static(GITHUB_API_VERSION),
    );
    h.insert(
        header::USER_AGENT,
        header::HeaderValue::from_static(DISCORD_USER_AGENT),
    );
    h
}

pub(super) async fn repo_languages(
    owner: &str,
    repo: &str,
) -> anyhow::Result<std::collections::HashMap<String, u64>> {
    let api_url = format!("https://api.github.com/repos/{owner}/{repo}/languages");

    let client = reqwest::Client::new();
    let res = client.get(&api_url).headers(headers()).send().await?;
    let map: std::collections::HashMap<String, u64> = res.json().await?;

    Ok(map)
}
