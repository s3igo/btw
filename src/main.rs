#[tokio::main]
async fn main() -> anyhow::Result<()> {
    use anyhow::Context as _;
    use serenity::model::gateway::GatewayIntents;

    let token = std::env::var("DISCORD_TOKEN").context("'DISCORD_TOKEN' env var not found")?;
    let intents = GatewayIntents::GUILD_MESSAGES | GatewayIntents::MESSAGE_CONTENT;

    let mut client = serenity::Client::builder(&token, intents)
        .event_handler(btw::Handler)
        .await
        .context("Error creating client")?;

    client.start().await.context("Error starting client")?;

    Ok(())
}
