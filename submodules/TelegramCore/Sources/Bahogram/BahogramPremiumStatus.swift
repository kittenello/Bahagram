import Foundation
import Postbox
import BGSimpleSettings

/// Whether the "Hide Premium Statuses" option suppresses the premium decorations
/// (emoji status and Premium badge) shown next to a peer's name. The account's own
/// peer is never affected.
///
/// Display sites must check this instead of the option hiding `Peer.emojiStatus`
/// itself: collectible-gift profile visuals and own-status editing read the real value.
public func bahogramHidesPremiumStatus(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> Bool {
    return peerId != accountPeerId && BGSimpleSettings.shared.hidePremiumStatuses
}
