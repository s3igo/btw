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

#[serenity::async_trait]
impl serenity::client::EventHandler for Handler {
    async fn message(
        &self,
        ctx: serenity::client::Context,
        msg: serenity::model::channel::Message,
    ) {
        if let Err(e) = self.inner(ctx, msg).await {
            eprintln!("Error: {e:?}");
        }
    }

    async fn ready(&self, _: serenity::client::Context, ready: serenity::model::gateway::Ready) {
        println!("{} is connected!", ready.user.name);
    }
}
