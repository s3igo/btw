const CONTENT: &str = "ちなみにRust製";

pub struct Handler;

#[serenity::async_trait]
impl serenity::client::EventHandler for Handler {
    async fn message(
        &self,
        ctx: serenity::client::Context,
        msg: serenity::model::channel::Message,
    ) {
        dbg!(&msg);
        for embed in &msg.embeds {
            if let Some(url) = embed.url.as_ref() {
                if let Err(e) = crate::github::check_repo_language(url).await {
                    eprintln!("{e:?}");
                } else if let Err(e) = msg.reply(&ctx, CONTENT).await {
                    eprintln!("Error sending message: {e:?}");
                    return;
                } else {
                    println!("Replied to message with content: {CONTENT}");
                }
            }
        }
    }

    async fn ready(&self, _: serenity::client::Context, ready: serenity::model::gateway::Ready) {
        println!("{} is connected!", ready.user.name);
    }
}
