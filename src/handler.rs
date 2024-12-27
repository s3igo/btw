const CONTENT: &str = "ちなみにRust製";

pub struct Handler;

impl Handler {
    async fn inner(
        &self,
        ctx: serenity::client::Context,
        msg: serenity::model::channel::Message,
    ) -> anyhow::Result<()> {
        use anyhow::Context as _;

        for embed in &msg.embeds {
            if let Some(url) = embed.url.as_ref() {
                let url = crate::url::Url::new(url)?;
                if url.is_rust_project().await? {
                    msg.reply(&ctx, CONTENT)
                        .await
                        .context("Failed to reply to message")?;

                    println!("Replied to message with content: {CONTENT}");
                }
            }
        }

        Ok(())
    }
}

async fn get_message(
    ctx: &serenity::client::Context,
    channel_id: &serenity::model::id::ChannelId,
    message_id: &serenity::model::id::MessageId,
) -> anyhow::Result<serenity::model::channel::Message> {
    let msg = channel_id.message(&ctx.http, message_id).await?;
    Ok(msg)
}

#[serenity::async_trait]
impl serenity::client::EventHandler for Handler {
    /// This handler listens for `message_update` events rather than `message`
    /// events to ensure link unfurling has completed.
    /// This guarantees that `msg.embeds` contains the unfurled content.
    /// For more about unfurling, see: https://api.slack.com/reference/messaging/link-unfurling
    /// NOTE: Since Discord's documentation does not contain information about
    /// unfurling, a link to Slack's explanation is provided instead.
    async fn message_update(
        &self,
        ctx: serenity::client::Context,
        _old: Option<serenity::model::channel::Message>,
        _new: Option<serenity::model::channel::Message>,
        event: serenity::model::event::MessageUpdateEvent,
    ) {
        if let Ok(msg) = get_message(&ctx, &event.channel_id, &event.id).await {
            if let Err(e) = self.inner(ctx, msg).await {
                eprintln!("Error: {e:?}");
            }
        }
    }

    async fn ready(&self, _ctx: serenity::client::Context, ready: serenity::model::gateway::Ready) {
        println!("{} is connected!", ready.user.name);
    }
}
