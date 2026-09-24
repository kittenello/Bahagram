import UIKit
import TelegramCore
import AccountContext
import OverlayStatusController

/// This badge is a local Bahogram decoration, not a Telegram verification mark.
public func bahogramIsTeamMember(peerId: EnginePeer.Id) -> Bool {
    guard peerId.namespace == Namespaces.Peer.CloudUser else {
        return false
    }
    let id = peerId.toInt64()
    return id == 8997685381 || id == 625977431
}

private let teamBadgeImage: UIImage = {
    let size = CGSize(width: 18.0, height: 18.0)
    return UIGraphicsImageRenderer(size: size).image { _ in
        let shield = UIBezierPath()
        shield.move(to: CGPoint(x: 9.0, y: 0.8))
        shield.addCurve(to: CGPoint(x: 16.2, y: 3.4), controlPoint1: CGPoint(x: 11.1, y: 1.8), controlPoint2: CGPoint(x: 14.1, y: 2.8))
        shield.addLine(to: CGPoint(x: 16.2, y: 8.7))
        shield.addCurve(to: CGPoint(x: 9.0, y: 17.2), controlPoint1: CGPoint(x: 16.2, y: 12.7), controlPoint2: CGPoint(x: 12.1, y: 16.0))
        shield.addCurve(to: CGPoint(x: 1.8, y: 8.7), controlPoint1: CGPoint(x: 5.9, y: 16.0), controlPoint2: CGPoint(x: 1.8, y: 12.7))
        shield.addLine(to: CGPoint(x: 1.8, y: 3.4))
        shield.addCurve(to: CGPoint(x: 9.0, y: 0.8), controlPoint1: CGPoint(x: 3.9, y: 2.8), controlPoint2: CGPoint(x: 6.9, y: 1.8))
        shield.close()
        UIColor(red: 0.61, green: 0.63, blue: 0.66, alpha: 1.0).setFill()
        shield.fill()

        let check = UIBezierPath()
        check.move(to: CGPoint(x: 5.7, y: 8.9))
        check.addLine(to: CGPoint(x: 8.0, y: 11.0))
        check.addLine(to: CGPoint(x: 12.5, y: 6.6))
        check.lineWidth = 2.0
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        UIColor.white.setStroke()
        check.stroke()
    }
}()

public func bahogramTeamBadgeImage() -> UIImage {
    return teamBadgeImage
}

public func presentBahogramTeamBadge(context: AccountContext, peerName: String) {
    let text = "\(peerName) является членом команды разработчиков Bahogram."
    context.sharedContext.mainWindow?.present(
        OverlayStatusController(style: .dark, type: .shieldSuccess(text, true)),
        on: .root
    )
}
