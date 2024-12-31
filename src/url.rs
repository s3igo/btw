const CACHE_TTI: std::time::Duration = std::time::Duration::from_secs(7 * 24 * 60 * 60); // 1 week
const CACHE_CAPACITY: u64 = 1_000;

#[derive(Debug)]
pub struct Url {
    owner: String,
    repo: String,
}

impl Url {
    #[tracing::instrument(ret, err)]
    pub fn new(url: &str) -> anyhow::Result<Self> {
        use anyhow::Context as _;

        let url = url::Url::parse(url).with_context(|| format!("Failed to parse URL: {url}"))?;

        anyhow::ensure!(
            url.host_str() == Some("github.com"),
            "Invalid host: expected github.com"
        );

        let mut path_segments = url
            .path_segments()
            .with_context(|| format!("Invalid URL path: {url:?}"))?
            .filter(|s| !s.is_empty());

        let owner = path_segments
            .next()
            .context("Repository owner not found in URL path")?
            .to_string();

        let repo = path_segments
            .next()
            .context("Repository name not found in URL path")?
            .to_string();

        Ok(Self { owner, repo })
    }

    #[tracing::instrument(skip(client), ret, err(level = tracing::Level::WARN))]
    pub async fn is_rust_project(&self, client: reqwest::Client) -> anyhow::Result<bool> {
        use std::{collections::HashMap, sync::LazyLock};

        use anyhow::Context as _;
        use moka::future::Cache;

        static LANGUAGES_CACHE: LazyLock<Cache<String, bool>> = LazyLock::new(|| {
            Cache::builder()
                .time_to_idle(CACHE_TTI)
                .max_capacity(CACHE_CAPACITY)
                .build()
        });

        let cache_key = format!("{}/{}", self.owner, self.repo);

        if let Some(is_rust) = LANGUAGES_CACHE.get(&cache_key).await {
            tracing::info!("Cache hit for {cache_key}: is_rust = {is_rust}");
            return Ok(is_rust);
        }

        tracing::info!("Cache miss for {cache_key}");

        let api_url = format!(
            "https://api.github.com/repos/{}/{}/languages",
            self.owner, self.repo
        );

        let res = client
            .get(&api_url)
            .header(reqwest::header::ACCEPT, "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header(reqwest::header::USER_AGENT, serenity::constants::USER_AGENT)
            .send()
            .await
            .with_context(|| format!("Failed to send request to {api_url}"))?;

        let languages: HashMap<String, u64> = res
            .json()
            .await
            .with_context(|| format!("Failed to parse JSON response from {api_url}"))?;

        let (primary_lang, _) = languages
            .iter()
            .max_by_key(|(_, &v)| v)
            .with_context(|| format!("Repository languages data is empty: {languages:?}"))?;

        let is_rust = primary_lang == "Rust";
        tracing::info!("Inserting into cache: {cache_key} = {is_rust}");
        LANGUAGES_CACHE.insert(cache_key, is_rust).await;

        Ok(is_rust)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_url_valid() {
        let url = "https://github.com/owner/repo";
        let result = Url::new(url).unwrap();
        assert_eq!(result.owner, "owner");
        assert_eq!(result.repo, "repo");
    }

    #[test]
    fn test_parse_url_with_trailing_slash() {
        let url = "https://github.com/owner/repo/";
        let result = Url::new(url).unwrap();
        assert_eq!(result.owner, "owner");
        assert_eq!(result.repo, "repo");
    }

    #[test]
    fn test_parse_url_invalid_host() {
        let url = "https://gitlab.com/owner/repo";
        assert!(Url::new(url).is_err());
    }

    #[test]
    fn test_parse_url_invalid_path() {
        let url = "https://github.com/owner";
        assert!(Url::new(url).is_err());
    }

    #[test]
    fn test_parse_url_with_extra_segments() {
        let url = "https://github.com/owner/repo/blob/main/README.md";
        let result = Url::new(url).unwrap();
        assert_eq!(result.owner, "owner");
        assert_eq!(result.repo, "repo");
    }

    #[test]
    fn test_parse_url_with_query_params() {
        let url = "https://github.com/owner/repo?tab=readme-ov-file";
        let result = Url::new(url).unwrap();
        assert_eq!(result.owner, "owner");
        assert_eq!(result.repo, "repo");
    }

    #[test]
    fn test_parse_url_invalid_url() {
        let url = "not a url";
        assert!(Url::new(url).is_err());
    }
}
