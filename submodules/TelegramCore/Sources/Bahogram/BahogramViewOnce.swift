import Foundation
import Postbox
import BGSimpleSettings

// "Сохранять одноразки": a view-once (or ≤60 s self-destructing) message received
// while the setting is on carries `.bahogramSavedViewOnce` (StoreMessage_Telegram.swift).
// Stock Telegram destroys such media in three places, and each one consults the helpers
// below:
// - playing the message starts its self-destruct countdown
//   (_internal_markMessageContentAsConsumedInteractively);
// - the expired countdown replaces the media with an "expired" placeholder
//   (managedAutoremoveMessageOperations);
// - once the message is read, the server strips the file, so every later server copy
//   arrives as TelegramMediaExpiredContent and would overwrite the stored media.

/// Whether `message` is a saved view-once message whose media must survive being
/// played. Secret chats keep the stock behavior.
func bahogramKeepsSavedViewOnce(_ message: Message) -> Bool {
    return message.localTags.contains(.bahogramSavedViewOnce) && message.id.peerId.namespace != Namespaces.Peer.SecretChat
}

/// Ghost mode with read receipts turned off. Like AyuGram's "Don't Read Messages", it
/// also stops reporting that voice and round video messages were played.
func bahogramGhostModeBlocksContentReads() -> Bool {
    let settings = BGSimpleSettings.shared
    return settings.ghostModeEnabled && !settings.ghostReadMessages
}

/// Whether reading a personal mention in `message` has to stay local. Marking a mention
/// as read sends `readMessageContents`, which also reports the message's voice or round
/// video as played, so in ghost mode it only goes to the server for messages without
/// such media. AyuGram checks for unread media instead; checking for any such media also
/// holds back a message whose media was played locally in ghost mode and never reported.
func bahogramGhostModeBlocksMentionRead(_ message: Message) -> Bool {
    return bahogramGhostModeBlocksContentReads() && message.attributes.contains(where: { $0 is ConsumableContentMessageAttribute })
}

/// Marks a personal mention as read without contacting the server. This is the local
/// part of the mention read in ManagedConsumePersonalMessagesActions.
func bahogramConsumePersonalMentionLocally(transaction: Transaction, id: MessageId) {
    transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: nil)
    transaction.updateMessage(id, update: { currentMessage in
        var storeForwardInfo: StoreMessageForwardInfo?
        if let forwardInfo = currentMessage.forwardInfo {
            storeForwardInfo = StoreMessageForwardInfo(forwardInfo)
        }
        var attributes = currentMessage.attributes
        loop: for j in 0 ..< attributes.count {
            if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
                break loop
            }
        }
        var updatedTags = currentMessage.tags
        updatedTags.remove(.unseenPersonalMessage)
        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
    })
}

private func bahogramContainsExpiredContent(_ media: [Media]) -> Bool {
    return media.contains(where: { $0 is TelegramMediaExpiredContent })
}

/// Returns `updated`, a server copy about to replace the stored `previous`, with the
/// saved view-once state of `previous` kept: the local tag always, and the stored media
/// when the server copy only carries the stripped "expired" placeholder.
func bahogramPreservingSavedViewOnceMedia(previous: Message, updated: StoreMessage) -> StoreMessage {
    guard bahogramKeepsSavedViewOnce(previous) else {
        return updated
    }
    let localTags = updated.localTags.union(.bahogramSavedViewOnce)
    guard bahogramContainsExpiredContent(updated.media), !bahogramContainsExpiredContent(previous.media) else {
        return updated.withUpdatedLocalTags(localTags)
    }
    // The placeholder carries no shared-media tags (voice, round video, ...), so derive
    // them again from the media that stays.
    let (mediaTags, mediaGlobalTags) = tagsForStoreMessage(incoming: previous.flags.contains(.Incoming), attributes: [], media: previous.media, textEntities: nil, isPinned: false)
    return StoreMessage(id: updated.id, customStableId: updated.customStableId, globallyUniqueId: updated.globallyUniqueId, groupingKey: updated.groupingKey, threadId: updated.threadId, timestamp: updated.timestamp, flags: updated.flags, tags: updated.tags.union(mediaTags), globalTags: updated.globalTags.union(mediaGlobalTags), localTags: localTags, forwardInfo: updated.forwardInfo, authorId: updated.authorId, text: updated.text, attributes: updated.attributes, media: previous.media)
}

/// `bahogramPreservingSavedViewOnceMedia(previous:updated:)` for server messages passed to
/// `Transaction.addMessages`, which replaces the media of a message that is already stored.
func bahogramPreservingSavedViewOnceMedia(transaction: Transaction, messages: [StoreMessage]) -> [StoreMessage] {
    // Only a copy with stripped media can destroy a saved message, so the common case
    // returns without reading the stored messages.
    if !messages.contains(where: { bahogramContainsExpiredContent($0.media) }) {
        return messages
    }
    return messages.map { message -> StoreMessage in
        guard bahogramContainsExpiredContent(message.media), case let .Id(id) = message.id, let previous = transaction.getMessage(id) else {
            return message
        }
        return bahogramPreservingSavedViewOnceMedia(previous: previous, updated: message)
    }
}
