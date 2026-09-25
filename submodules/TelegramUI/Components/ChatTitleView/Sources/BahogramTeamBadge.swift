import UIKit
import TelegramCore
import AccountContext
import OverlayStatusController
import EmojiStatusComponent

/// This badge is a local Bahogram decoration, not a Telegram verification mark.
public func bahogramIsTeamMember(peerId: EnginePeer.Id) -> Bool {
    guard peerId.namespace == Namespaces.Peer.CloudUser else {
        return false
    }
    // The real Telegram user ID. `toInt64()` is Postbox's packed storage key and only
    // equals it below 2^32 (8997685381 packs to 69127227525).
    let id = peerId.id._internalGetInt64Value()
    return id == 8997685381 || id == 625977431
}

public func bahogramTeamBadgeContent(sizeType: EmojiStatusComponent.SizeType) -> EmojiStatusComponent.Content {
    return .verified(
        fillColor: UIColor(red: 0.61, green: 0.63, blue: 0.66, alpha: 1.0),
        foregroundColor: .white,
        sizeType: sizeType
    )
}

public func presentBahogramTeamBadge(context: AccountContext, peerName: String) {
    let text = "\(peerName) является членом команды разработчиков Bahogram."
    context.sharedContext.mainWindow?.present(
        OverlayStatusController(style: .dark, type: .shieldSuccess(text, true)),
        on: .root
    )
}
