use serenity::{
    async_trait,
    client::{Context, EventHandler},
    model::{channel::Message, gateway::Ready},
};

use crate::github::check_repo_language;

pub struct Handler;

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
                if let Err(e) = check_repo_language(url).await {
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
