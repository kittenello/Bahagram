import Foundation
import Postbox
import SwiftSignalKit
import BGSimpleSettings

public struct BahogramMessageRevision: Codable, Equatable {
    public let text: String
    public let timestamp: Int32

    public init(text: String, timestamp: Int32) {
        self.text = text
        self.timestamp = timestamp
    }
}

private struct BahogramMessageRevisionList: Codable {
    var revisions: [BahogramMessageRevision]
}

private func bahogramMessageWithUpdatedLocalTags(_ message: Message, localTags: LocalMessageTags) -> StoreMessage {
    return StoreMessage(
        id: message.id,
        customStableId: nil,
        globallyUniqueId: message.globallyUniqueId,
        groupingKey: message.groupingKey,
        threadId: message.threadId,
        timestamp: message.timestamp,
        flags: StoreMessageFlags(message.flags),
        tags: message.tags,
        globalTags: message.globalTags,
        localTags: localTags,
        forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init),
        authorId: message.author?.id,
        text: message.text,
        attributes: message.attributes,
        media: message.media
    )
}

private func bahogramRevisionCacheId(_ messageId: MessageId) -> ItemCacheEntryId {
    let key = ValueBoxKey(length: 16)
    key.setInt64(0, value: messageId.peerId.toInt64())
    key.setInt32(8, value: messageId.namespace)
    key.setInt32(12, value: messageId.id)
    return ItemCacheEntryId(
        collectionId: Namespaces.CachedItemCollection.bahogramEditHistory,
        key: key
    )
}

private func bahogramAllowsSavingInPeer(transaction: Transaction, peerId: PeerId) -> Bool {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }

    if BGSimpleSettings.shared.saveInBotChats {
        return true
    }

    if let user = transaction.getPeer(peerId) as? TelegramUser, user.botInfo != nil {
        return false
    }

    return true
}

private func bahogramRevisionTimestamp(_ message: Message) -> Int32 {
    for attribute in message.attributes {
        if let attribute = attribute as? EditedMessageAttribute, attribute.date != 0 {
            return attribute.date
        }
    }
    return message.timestamp
}

/// Marks a cloud message as locally deleted instead of removing it from Postbox.
///
/// Keeping the original Message object means its text, attributes and media
/// references stay available after reopening the chat and after an app restart.
/// The marker is local-only and is never sent to Telegram.
func bahogramPreserveDeletedMessage(transaction: Transaction, messageId: MessageId) -> Bool {
    guard BGSimpleSettings.shared.saveDeletedMessages else {
        return false
    }
    guard messageId.namespace == Namespaces.Message.Cloud else {
        return false
    }
    guard bahogramAllowsSavingInPeer(transaction: transaction, peerId: messageId.peerId) else {
        return false
    }
    guard let message = transaction.getMessage(messageId) else {
        return false
    }

    if message.localTags.contains(.bahogramDeleted) {
        return true
    }

    transaction.updateMessage(messageId, update: { currentMessage in
        var localTags = currentMessage.localTags
        localTags.insert(.bahogramDeleted)
        return .update(bahogramMessageWithUpdatedLocalTags(currentMessage, localTags: localTags))
    })
    return true
}

/// Stores the version that is about to be replaced by an incoming edit.
/// Returns true when the message should carry the local edit-history marker.
func bahogramStorePreviousMessageRevision(
    transaction: Transaction,
    previousMessage: Message,
    updatedText: String
) -> Bool {
    guard BGSimpleSettings.shared.saveEditHistory else {
        return previousMessage.localTags.contains(.bahogramHasEditHistory)
    }
    guard previousMessage.id.namespace == Namespaces.Message.Cloud else {
        return previousMessage.localTags.contains(.bahogramHasEditHistory)
    }
    guard previousMessage.text != updatedText else {
        return previousMessage.localTags.contains(.bahogramHasEditHistory)
    }
    guard bahogramAllowsSavingInPeer(transaction: transaction, peerId: previousMessage.id.peerId) else {
        return previousMessage.localTags.contains(.bahogramHasEditHistory)
    }

    let cacheId = bahogramRevisionCacheId(previousMessage.id)
    var list = transaction.retrieveItemCacheEntry(id: cacheId)?.get(BahogramMessageRevisionList.self)
        ?? BahogramMessageRevisionList(revisions: [])

    let revision = BahogramMessageRevision(
        text: previousMessage.text,
        timestamp: bahogramRevisionTimestamp(previousMessage)
    )

    if list.revisions.last != revision {
        list.revisions.append(revision)

        // A pathological message can be edited many times. Keep the newest
        // revisions while bounding the local cache.
        if list.revisions.count > 100 {
            list.revisions.removeFirst(list.revisions.count - 100)
        }

        guard let entry = CodableEntry(list) else {
            return previousMessage.localTags.contains(.bahogramHasEditHistory)
        }
        transaction.putItemCacheEntry(id: cacheId, entry: entry)
    }

    return true
}

public func bahogramMessageRevisions(
    postbox: Postbox,
    messageId: MessageId
) -> Signal<[BahogramMessageRevision], NoError> {
    return postbox.transaction { transaction -> [BahogramMessageRevision] in
        let cacheId = bahogramRevisionCacheId(messageId)
        return transaction.retrieveItemCacheEntry(id: cacheId)?
            .get(BahogramMessageRevisionList.self)?
            .revisions ?? []
    }
}

