import Foundation
import Postbox

// A pseudo-reply (a reply to a kept deleted message) goes out with a quote of the
// deleted message in front of its text (donutgramPseudoReplyContent in
// PendingMessageManager), while its local copy keeps the body alone under the reply.
// Every later server copy starts with that quote as well, so it is stored with the
// message: an edit from another device can then be told apart from the quote.

/// What the server copy of a pseudo-reply has in front of the text its local copy shows:
/// the quote that was sent, or an empty string when the message went out without one.
/// Local only.
final class DonutgramPseudoReplyPrefixMessageAttribute: MessageAttribute {
    let text: String

    init(text: String) {
        self.text = text
    }

    init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
    }

    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
    }
}

/// The attributes a pseudo-reply takes from its local copy rather than from a server copy.
func donutgramIsPseudoReplyLocalAttribute(_ attribute: MessageAttribute) -> Bool {
    return attribute is ReplyMessageAttribute || attribute is TextEntitiesMessageAttribute || attribute is DonutgramPseudoReplyPrefixMessageAttribute
}

/// The quote a stored pseudo-reply went out with, if this build sent it.
func donutgramStoredPseudoReplyPrefix(_ message: Message) -> DonutgramPseudoReplyPrefixMessageAttribute? {
    return message.attributes.first(where: { $0 is DonutgramPseudoReplyPrefixMessageAttribute }) as? DonutgramPseudoReplyPrefixMessageAttribute
}

/// The local tags a pseudo-reply keeps over its server copies: the tag itself, and the mark of
/// a later part of a split text, which must not get the quote when it is edited.
func donutgramPseudoReplyLocalTags(_ message: Message) -> LocalMessageTags {
    return message.localTags.intersection([.donutgramPseudoReply, .donutgramPseudoReplyContinuation])
}

/// The part of a pseudo-reply's `sentText` in front of its `body`. The sent text is the
/// quote, then a line break and the body when there is one, or the body alone when no
/// quote went out. Nil for any other shape.
private func donutgramPseudoReplyPrefix(sentText: String, body: String) -> String? {
    let nsSentText = sentText as NSString
    let bodyLength = (body as NSString).length
    if bodyLength == 0 {
        return sentText
    }
    if nsSentText.isEqual(to: body) {
        return ""
    }
    let prefixLength = nsSentText.length - bodyLength - 1
    guard prefixLength > 0, nsSentText.character(at: prefixLength) == 0x0a, nsSentText.compare(body, options: .literal, range: NSRange(location: prefixLength + 1, length: bodyLength)) == .orderedSame else {
        return nil
    }
    return nsSentText.substring(to: prefixLength)
}

/// Stores on a pseudo-reply that goes out as `sentText` what its server copy has in front
/// of the local text: `body`, or the stored text when no `body` is given. An edit passes the
/// new body, which a scheduled message stores only when the server copy comes back.
func donutgramStorePseudoReplyPrefix(transaction: Transaction, messageId: MessageId, sentText: String, body: String? = nil) {
    transaction.updateMessage(messageId, update: { currentMessage in
        // After an edit the stored copy may already be the server one, no pseudo-reply.
        guard currentMessage.localTags.contains(.donutgramPseudoReply) else {
            return .skip
        }
        var attributes = currentMessage.attributes.filter { !($0 is DonutgramPseudoReplyPrefixMessageAttribute) }
        if let prefix = donutgramPseudoReplyPrefix(sentText: sentText, body: body ?? currentMessage.text) {
            attributes.append(DonutgramPseudoReplyPrefixMessageAttribute(text: prefix))
        }
        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
    })
}

/// `text` without `prefix` and the line break after it, or nil when `text` no longer
/// starts with them. The comparison is exact, in UTF-16 code units like entity offsets.
private func donutgramPseudoReplyBody(text: String, prefix: String) -> String? {
    let nsText = text as NSString
    let prefixLength = (prefix as NSString).length
    if prefixLength == 0 {
        return text
    }
    guard nsText.length >= prefixLength, nsText.compare(prefix, options: .literal, range: NSRange(location: 0, length: prefixLength)) == .orderedSame else {
        return nil
    }
    if nsText.length == prefixLength {
        return ""
    }
    guard nsText.character(at: prefixLength) == 0x0a else {
        return nil
    }
    return nsText.substring(from: prefixLength + 1)
}

/// Returns `updated`, a server copy about to replace the stored `previous`, in the form the
/// local copy of a pseudo-reply shows. While the server text still starts with the quote
/// that was sent, the quote and the entities over it are cut off and the reply to the
/// deleted message stays. Otherwise (the quote was removed or changed on another device,
/// the text is empty without it, or no quote was stored) the server copy replaces the
/// local one as it is. Where the caller takes the local tags from the server copy
/// (`.EditMessage`, `.AddScheduledMessages`) the message is no longer a pseudo-reply;
/// `addMessages` and the album acknowledgement keep the stored tags.
func donutgramPreservingPseudoReply(previous: Message, updated: StoreMessage) -> StoreMessage {
    guard previous.localTags.contains(.donutgramPseudoReply),
          let prefix = donutgramStoredPseudoReplyPrefix(previous),
          let body = donutgramPseudoReplyBody(text: updated.text, prefix: prefix.text),
          !body.isEmpty || updated.media.contains(where: { !($0 is TelegramMediaWebpage) }) else {
        return updated
    }
    let bodyLength = (body as NSString).length
    let bodyRange = NSRange(location: (updated.text as NSString).length - bodyLength, length: bodyLength)
    let entities = (updated.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute)?.entities ?? []
    let bodyEntities = messageTextEntitiesInRange(entities: entities, range: bodyRange, onlyQuoteable: false)

    var attributes = updated.attributes.filter { !donutgramIsPseudoReplyLocalAttribute($0) }
    attributes.append(contentsOf: previous.attributes.filter { $0 is ReplyMessageAttribute })
    if !bodyEntities.isEmpty {
        attributes.append(TextEntitiesMessageAttribute(entities: bodyEntities))
    }
    attributes.append(prefix)
    var tags = updated.tags
    var globalTags = updated.globalTags
    if !prefix.text.isEmpty {
        // A link that was only in the quote no longer puts the message into the shared links.
        (tags, globalTags) = tagsForStoreMessage(incoming: updated.flags.contains(.Incoming), attributes: attributes, media: updated.media, textEntities: bodyEntities, isPinned: updated.tags.contains(.pinned))
    }
    return StoreMessage(id: updated.id, customStableId: updated.customStableId, globallyUniqueId: updated.globallyUniqueId, groupingKey: updated.groupingKey, threadId: updated.threadId, timestamp: updated.timestamp, flags: updated.flags, tags: tags, globalTags: globalTags, localTags: updated.localTags.union(donutgramPseudoReplyLocalTags(previous)), forwardInfo: updated.forwardInfo, authorId: updated.authorId, text: body, attributes: attributes, media: updated.media)
}
