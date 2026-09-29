import Foundation
import Postbox
import SwiftSignalKit

// What the quote of a pseudo-reply says (donutgramPseudoReplyContent in
// PendingMessageManager): a reply to a deleted message that Donutgram kept goes out
// with a quote of that message, since the other participant no longer has it.

private let donutgramMessageDescriber = Atomic<((EngineMessage, EnginePeer.Id, ContentSettings) -> String)?>(value: nil)

/// Sets how to name what a message holds (a photo, a sticker, a location and so on)
/// in the app's language. TelegramCore has no strings of its own, so the app sets
/// this at launch, before any account starts sending.
public func donutgramSetMessageDescriber(_ describer: @escaping (_ message: EngineMessage, _ accountPeerId: EnginePeer.Id, _ contentSettings: ContentSettings) -> String) {
    let _ = donutgramMessageDescriber.swap(describer)
}

/// Names what `message` holds, for the quote of a message without text.
func donutgramMessageDescription(transaction: Transaction, message: Message) -> String {
    guard let describer = donutgramMessageDescriber.with({ $0 }), let state = transaction.getState() as? AuthorizedAccountState else {
        // An extension without the app's UI, such as Siri, can still send a queued
        // pseudo-reply. Its quote then only marks that something was there.
        return "…"
    }
    return describer(EngineMessage(message), state.peerId, getContentSettings(transaction: transaction))
}

/// The deleted message a pseudo-reply quotes, with the text the quote shows, as the
/// reply header shows it. A reply to one checklist task or poll option quotes that
/// item. Otherwise a poll is quoted by its question, and a checklist without text of
/// its own by "☑️" and its title. That text and its formatting then stand in for the
/// message's.
func donutgramPseudoReplySource(transaction: Transaction, reply: ReplyMessageAttribute) -> Message? {
    guard let message = transaction.getMessage(reply.messageId) else {
        return nil
    }
    let todo = message.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo
    let poll = message.media.first(where: { $0 is TelegramMediaPoll }) as? TelegramMediaPoll
    var quoted: (text: String, entities: [MessageTextEntity])?
    switch reply.innerSubject {
    case let .todoItem(todoItemId):
        if let todoItem = todo?.items.first(where: { $0.id == todoItemId }) {
            quoted = (todoItem.text, todoItem.entities)
        }
    case let .pollOption(pollOptionId):
        if let pollOption = poll?.options.first(where: { $0.opaqueIdentifier == pollOptionId }) {
            quoted = (pollOption.text, pollOption.entities)
        }
    default:
        break
    }
    if quoted == nil {
        if let todo, message.text.isEmpty {
            let marker = "☑️ "
            let markerLength = (marker as NSString).length
            quoted = (marker + todo.text, todo.textEntities.map { entity in
                MessageTextEntity(range: (entity.range.lowerBound + markerLength) ..< (entity.range.upperBound + markerLength), type: entity.type)
            })
        } else if let poll {
            quoted = (poll.text, poll.textEntities)
        }
    }
    guard let quoted else {
        return message
    }
    var attributes = message.attributes.filter { !($0 is TextEntitiesMessageAttribute) }
    if !quoted.entities.isEmpty {
        attributes.append(TextEntitiesMessageAttribute(entities: quoted.entities))
    }
    return message.withUpdatedText(quoted.text).withUpdatedAttributes(attributes)
}
