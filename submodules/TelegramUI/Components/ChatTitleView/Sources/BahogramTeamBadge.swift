import UIKit
import TelegramCore
import AccountContext
import OverlayStatusController
import EmojiStatusComponent
import AppBundle

/// Bahogram's own badges. They are local decorations, not Telegram verification marks.
public enum BahogramBadge: Equatable {
    case developer
    case supporter
    case baha
}

// Raw Telegram user IDs.
private let bahogramBahaIds: Set<Int64> = [7395289125]
private let bahogramDeveloperIds: Set<Int64> = [8997685381, 625977431]
private let bahogramSupporterIds: Set<Int64> = [8494126379]

/// The badge a user gets; Baha's own badge wins over the developer one, which wins over the supporter one.
public func bahogramBadge(peerId: EnginePeer.Id) -> BahogramBadge? {
    guard peerId.namespace == Namespaces.Peer.CloudUser else {
        return nil
    }
    // The real Telegram user ID. `toInt64()` is Postbox's packed storage key and only
    // equals it below 2^32 (8997685381 packs to 69127227525).
    let id = peerId.id._internalGetInt64Value()
    if bahogramBahaIds.contains(id) {
        return .baha
    } else if bahogramDeveloperIds.contains(id) {
        return .developer
    } else if bahogramSupporterIds.contains(id) {
        return .supporter
    } else {
        return nil
    }
}

/// `.compact` is the 16 pt chat-list size; `.large` serves the chat title and the profile header.
public func bahogramBadgeContent(_ badge: BahogramBadge, sizeType: EmojiStatusComponent.SizeType) -> EmojiStatusComponent.Content {
    let isLarge = sizeType == .large
    let image: UIImage?
    switch badge {
    case .developer:
        image = isLarge ? BahogramBadgeImages.developerLarge : BahogramBadgeImages.developerCompact
    case .supporter:
        image = isLarge ? BahogramBadgeImages.supporterLarge : BahogramBadgeImages.supporterCompact
    case .baha:
        image = isLarge ? BahogramBadgeImages.bahaLarge : BahogramBadgeImages.bahaCompact
    }
    return .image(image: image, tintColor: nil)
}

public func presentBahogramBadge(_ badge: BahogramBadge, context: AccountContext, peerName: String) {
    let type: OverlayStatusControllerType
    switch badge {
    case .developer:
        type = .shieldSuccess("\(peerName) является членом команды разработчиков Bahogram.", true)
    case .supporter:
        type = .genericSuccess("\(peerName) поддерживает Bahogram.", true)
    case .baha:
        type = .genericSuccess("\(peerName) — припухлый Баха собственной персоной.", true)
    }
    context.sharedContext.mainWindow?.present(
        OverlayStatusController(style: .dark, type: type),
        on: .root
    )
}

private enum BahogramBadgeImages {
    // The developer badge («Кристалл») is a looping animation: 48 frames on one sprite sheet,
    // 8 per row, played by EmojiStatusComponent as an animated UIImage.
    static let developerCompact = animatedImage(sheetNamed: "Bahogram/BadgeDeveloperCompact")
    static let developerLarge = animatedImage(sheetNamed: "Bahogram/BadgeDeveloperLarge")
    static let supporterCompact = UIImage(bundleImageName: "Bahogram/BadgeSupporterCompact")
    static let supporterLarge = UIImage(bundleImageName: "Bahogram/BadgeSupporterLarge")
    static let bahaCompact = UIImage(bundleImageName: "Bahogram/BadgeBahaCompact")
    static let bahaLarge = UIImage(bundleImageName: "Bahogram/BadgeBahaLarge")

    private static let frameCount = 48
    private static let columns = 8
    private static let loopDuration: Double = 2.4

    private static func animatedImage(sheetNamed name: String) -> UIImage? {
        guard let sheet = UIImage(bundleImageName: name), let cgSheet = sheet.cgImage else {
            return nil
        }
        let rows = (frameCount + columns - 1) / columns
        assert(cgSheet.width % columns == 0 && cgSheet.height % rows == 0, "\(name) is not a \(columns)×\(rows) sprite sheet")
        let frameWidth = cgSheet.width / columns
        let frameHeight = cgSheet.height / rows
        var frames: [UIImage] = []
        for index in 0 ..< frameCount {
            let rect = CGRect(x: (index % columns) * frameWidth, y: (index / columns) * frameHeight, width: frameWidth, height: frameHeight)
            if let cgFrame = cgSheet.cropping(to: rect) {
                frames.append(UIImage(cgImage: cgFrame, scale: sheet.scale, orientation: .up))
            }
        }
        if frames.count < 2 {
            return frames.first
        }
        return UIImage.animatedImage(with: frames, duration: loopDuration)
    }
}
