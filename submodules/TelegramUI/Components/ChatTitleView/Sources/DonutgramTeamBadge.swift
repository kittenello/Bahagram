import UIKit
import TelegramCore
import AccountContext
import OverlayStatusController
import EmojiStatusComponent
import AppBundle

/// Donutgram's own badges. They are local decorations, not Telegram verification marks.
public enum DonutgramBadge: Equatable {
    case developer
    case supporter
    case baha
}

// Raw Telegram user IDs.
private let donutgramBahaIds: Set<Int64> = [7395289125]
private let donutgramDeveloperIds: Set<Int64> = [8997685381, 625977431]
private let donutgramSupporterIds: Set<Int64> = [8494126379]

/// The badge a user gets; Baha's own badge wins over the developer one, which wins over the supporter one.
public func donutgramBadge(peerId: EnginePeer.Id) -> DonutgramBadge? {
    guard peerId.namespace == Namespaces.Peer.CloudUser else {
        return nil
    }
    // The real Telegram user ID. `toInt64()` is Postbox's packed storage key and only
    // equals it below 2^32 (8997685381 packs to 69127227525).
    let id = peerId.id._internalGetInt64Value()
    if donutgramBahaIds.contains(id) {
        return .baha
    } else if donutgramDeveloperIds.contains(id) {
        return .developer
    } else if donutgramSupporterIds.contains(id) {
        return .supporter
    } else {
        return nil
    }
}

/// `.compact` is the 16 pt chat-list size; `.large` serves the chat title and the profile header.
public func donutgramBadgeContent(_ badge: DonutgramBadge, sizeType: EmojiStatusComponent.SizeType) -> EmojiStatusComponent.Content {
    let isLarge = sizeType == .large
    let image: UIImage?
    switch badge {
    case .developer:
        image = isLarge ? DonutgramBadgeImages.developerLarge : DonutgramBadgeImages.developerCompact
    case .supporter:
        image = isLarge ? DonutgramBadgeImages.supporterLarge : DonutgramBadgeImages.supporterCompact
    case .baha:
        image = isLarge ? DonutgramBadgeImages.bahaLarge : DonutgramBadgeImages.bahaCompact
    }
    return .image(image: image, tintColor: nil)
}

public func presentDonutgramBadge(_ badge: DonutgramBadge, context: AccountContext, peerName: String) {
    let type: OverlayStatusControllerType
    switch badge {
    case .developer:
        type = .shieldSuccess("\(peerName) является членом команды разработчиков Donutgram.", true)
    case .supporter:
        type = .genericSuccess("\(peerName) поддерживает Donutgram.", true)
    case .baha:
        type = .genericSuccess("\(peerName) — припухлый Баха собственной персоной.", true)
    }
    context.sharedContext.mainWindow?.present(
        OverlayStatusController(style: .dark, type: type),
        on: .root
    )
}

private enum DonutgramBadgeImages {
    // The developer badge («Кристалл») is a looping animation: 48 frames on one sprite sheet,
    // 8 per row, played by EmojiStatusComponent as an animated UIImage.
    static let developerCompact = animatedImage(sheetNamed: "Donutgram/BadgeDeveloperCompact")
    static let developerLarge = animatedImage(sheetNamed: "Donutgram/BadgeDeveloperLarge")
    static let supporterCompact = UIImage(bundleImageName: "Donutgram/BadgeSupporterCompact")
    static let supporterLarge = UIImage(bundleImageName: "Donutgram/BadgeSupporterLarge")
    static let bahaCompact = UIImage(bundleImageName: "Donutgram/BadgeBahaCompact")
    static let bahaLarge = UIImage(bundleImageName: "Donutgram/BadgeBahaLarge")

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
