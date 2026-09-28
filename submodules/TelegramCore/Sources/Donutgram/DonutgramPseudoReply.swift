import Foundation
import Postbox

/// Whether a reply to a kept deleted message can go out as a pseudo-reply: the real
/// reply is dropped and the quote is prepended to the message text
/// (`donutgramPseudoReplyContent` in PendingMessageManager).
///
/// That only works when the text reaches the other participant. An inline-bot result
/// (the GIF panel's search and trending results are among them) is sent by
/// `messages.sendInlineBotResult`, which takes no text. Stickers and dice are drawn
/// without their caption, and Telegram has no caption for round videos, locations,
/// contacts, stories and similar media. Such messages keep the regular reply; otherwise
/// the recipient would get neither the reply nor the quote. A poll qualifies: its
/// description is the message text.
func donutgramCanSendAsPseudoReply(attributes: [MessageAttribute], media: [Media]) -> Bool {
    if attributes.contains(where: { $0 is OutgoingChatContextResultMessageAttribute }) {
        return false
    }
    for item in media {
        if let file = item as? TelegramMediaFile {
            if file.isSticker || file.isAnimatedSticker || file.isInstantVideo {
                return false
            }
        } else if !(item is TelegramMediaImage || item is TelegramMediaWebpage || item is TelegramMediaPoll || item is TelegramMediaPaidContent) {
            return false
        }
    }
    return true
}
