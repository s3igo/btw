mod fetch;

use anyhow::{ensure, Context as _, Result};
use url::Url;

const EXPECTED_HOST: &str = "github.com";
const EXPECTED_LANGUAGE: &str = "Rust";

fn parse_url(url: &str) -> Result<(String, String)> {
    let url = Url::parse(url).context("Failed to parse URL")?;

    ensure!(url.host_str() == Some(EXPECTED_HOST), "Host is not github");

    let mut path_segments = url.path_segments().context("Invalid URL path")?;

    let owner = path_segments.next().context("Missing owner in URL path")?;
    let repo = path_segments.next().context("Missing repo in URL path")?;
    ensure!(path_segments.next().is_none(), "URL path is too long");

    Ok((owner.to_string(), repo.to_string()))
}

pub async fn check_repo_language(url: &str) -> Result<()> {
    let (owner, repo) = parse_url(url)?;

    let languages = fetch::repo_languages(&owner, &repo).await?;

    let (lang, _) = languages
        .iter()
        .max_by_key(|(_, &v)| v)
        .context("Languages not defined")?;

    ensure!(
        lang == EXPECTED_LANGUAGE,
        "Primary language is not what was expected"
    );

    Ok(())
}
