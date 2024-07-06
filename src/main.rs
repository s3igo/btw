use std::{collections::HashMap, env};

use anyhow::{ensure, Context as _, Result};
use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, USER_AGENT};
use serenity::{
    async_trait,
    model::{channel::Message, gateway::Ready},
    prelude::*,
};
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

async fn check(url: &str) -> Result<()> {
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

    ensure!(lang == "Rust", "Primary language is not rust");

    Ok(())
}

struct Handler;

#[async_trait]
impl EventHandler for Handler {
    // Set a handler for the `message` event. This is called whenever a new message
    // is received.
    //
    // Event handlers are dispatched through a threadpool, and so multiple events
    // can be dispatched simultaneously.
    async fn message(&self, ctx: Context, msg: Message) {
        for embed in &msg.embeds {
            if let Some(url) = embed.url.as_ref() {
                if let Err(e) = check(url).await {
                    eprintln!("{e:#}");
                } else {
                    let _ = msg.reply(ctx, "ちなみにRust製").await;
                    return;
                }
            }
        }
    }

    // Set a handler to be called on the `ready` event. This is called when a shard
    // is booted, and a READY payload is sent by Discord. This payload contains
    // data like the current user's guild Ids, current user data, private
    // channels, and more.
    //
    // In this case, just print what the current user's username is.
    async fn ready(&self, _: Context, ready: Ready) {
        println!("{} is connected!", ready.user.name);
    }
}

#[tokio::main]
async fn main() {
    // Configure the client with your Discord bot token in the environment.
    let token = env::var("DISCORD_TOKEN").expect("Expected a token in the environment");
    // Set gateway intents, which decides what events the bot will be notified about
    let intents = GatewayIntents::GUILD_MESSAGES | GatewayIntents::MESSAGE_CONTENT;

    // Create a new instance of the Client, logging in as a bot. This will
    // automatically prepend your bot token with "Bot ", which is a requirement
    // by Discord for bot users.
    let mut client = Client::builder(&token, intents)
        .event_handler(Handler)
        .await
        .expect("Err creating client");

    // Finally, start a single shard, and start listening to events.
    //
    // Shards will automatically attempt to reconnect, and will perform exponential
    // backoff until it reconnects.
    if let Err(e) = client.start().await {
        println!("Client error: {e:?}");
    }
}
