fn init_tracing() {
    use tracing::level_filters::LevelFilter;
    use tracing_subscriber::{
        filter::EnvFilter, fmt, layer::SubscriberExt as _, util::SubscriberInitExt as _,
    };

    // Use the `RUST_LOG` env var if set, otherwise output logs at INFO level or
    // lower by default
    // Ref: https://docs.rs/tracing/latest/tracing/struct.Level.html#filtering
    let filter = EnvFilter::builder()
        .with_default_directive(LevelFilter::INFO.into())
        .from_env_lossy();

    // Include the file and line number where each log originates
    let layer = fmt::layer().with_file(true).with_line_number(true);

    // Use JSON formatting in production, pretty formatting in development
    let pretty = cfg!(debug_assertions).then(|| fmt::layer().pretty());
    let json = cfg!(not(debug_assertions)).then(|| fmt::layer().json());

    tracing_subscriber::registry()
        .with(filter)
        .with(layer)
        .with(pretty)
        .with(json)
        .init();
}

#[tracing::instrument(name = "main")]
async fn run() -> anyhow::Result<()> {
    use anyhow::Context as _;
    use serenity::model::gateway::GatewayIntents;

    let token = std::env::var("DISCORD_TOKEN").context("'DISCORD_TOKEN' env var not found")?;
    let intents = GatewayIntents::GUILD_MESSAGES | GatewayIntents::MESSAGE_CONTENT;

    let mut client = serenity::Client::builder(&token, intents)
        .event_handler(btw::Handler)
        .await
        .context("Error creating client")?;

    client.start().await.context("Client error")?;

    Ok(())
}

#[tokio::main]
async fn main() {
    init_tracing();

    if let Err(e) = run().await {
        tracing::error!("{e:?}");
    }
}
