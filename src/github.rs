mod fetch;

const EXPECTED_HOST: &str = "github.com";
const EXPECTED_LANGUAGE: &str = "Rust";

fn parse_url(url: &str) -> anyhow::Result<(String, String)> {
    use anyhow::Context as _;

    let url = url::Url::parse(url).context("Failed to parse URL")?;

    anyhow::ensure!(url.host_str() == Some(EXPECTED_HOST), "Host is not github");

    let path_segments: Vec<_> = url
        .path_segments()
        .context("Invalid URL path")?
        .filter(|s| !s.is_empty())
        .collect();

    dbg!(&path_segments);

    anyhow::ensure!(
        path_segments.len() == 2,
        "URL path must have exactly owner/repo"
    );
    let owner = path_segments[0];
    let repo = path_segments[1];

    Ok((owner.to_string(), repo.to_string()))
}

pub async fn check_repo_language(url: &str) -> anyhow::Result<()> {
    use anyhow::Context as _;

    let (owner, repo) = parse_url(url)?;

    let languages = fetch::repo_languages(&owner, &repo).await?;

    let (lang, _) = languages
        .iter()
        .max_by_key(|(_, &v)| v)
        .context("Languages not defined")?;

    anyhow::ensure!(
        lang == EXPECTED_LANGUAGE,
        "Primary language is not what was expected"
    );

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_url_valid() {
        let url = "https://github.com/owner/repo";
        let result = parse_url(url).unwrap();
        assert_eq!(result, ("owner".to_string(), "repo".to_string()));
    }

    #[test]
    fn test_parse_url_with_trailing_slash() {
        let url = "https://github.com/owner/repo/";
        let result = parse_url(url).unwrap();
        assert_eq!(result, ("owner".to_string(), "repo".to_string()));
    }

    #[test]
    fn test_parse_url_invalid_host() {
        let url = "https://gitlab.com/owner/repo";
        assert!(parse_url(url).is_err());
    }

    #[test]
    fn test_parse_url_invalid_path() {
        let url = "https://github.com/owner";
        assert!(parse_url(url).is_err());

        let url = "https://github.com/owner/repo/extra";
        assert!(parse_url(url).is_err());
    }

    #[test]
    fn test_parse_url_invalid_url() {
        let url = "not a url";
        assert!(parse_url(url).is_err());
    }
}
