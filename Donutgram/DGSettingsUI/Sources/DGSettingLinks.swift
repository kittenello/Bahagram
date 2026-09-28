import Foundation
import UIKit
import ItemListUI
import Display

struct DGSettingItemTag: ItemListItemTag {
    let key: String

    func isEqual(to other: ItemListItemTag) -> Bool {
        return (other as? DGSettingItemTag)?.key == self.key
    }
}

private var pendingSettingLinkFocus: (page: String, key: String)?

func dgPrepareSettingLinkFocus(page: String, key: String) {
    pendingSettingLinkFocus = (page, key)
}

func dgTakeSettingLinkFocus(page: String) -> DGSettingItemTag? {
    guard let pending = pendingSettingLinkFocus, pending.page == page else {
        return nil
    }
    pendingSettingLinkFocus = nil
    return DGSettingItemTag(key: pending.key)
}

func dgSettingPageId(title: String) -> String {
    switch title {
    case "Настройки Donutgram": return "root"
    case "Основные": return "general"
    case "Режим призрака": return "ghost"
    case "Параметры призрака": return "ghost-options"
    case "Отправлять без звука": return "silent"
    case "Оформление": return "appearance"
    case "ID диалога": return "dialog-id"
    case "Чаты": return "chats"
    case "Камера в кружках": return "camera"
    case "Авто пауза": return "auto-pause"
    case "Скачивание": return "downloads"
    case "Голос в текст": return "transcription"
    case "Скрыть реакции": return "reactions"
    case "Визуальный ID": return "visual-id"
    case "Визуальный рейтинг": return "visual-rating"
    case "Визуальные NFT-юзернеймы": return "visual-usernames"
    case "Визуальный номер": return "visual-phone"
    case "Поддержка": return "support"
    default: return "root"
    }
}

func dgHighlightSettingView(_ view: UIView) {
    let highlight = UIView(frame: view.bounds)
    highlight.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    highlight.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.22)
    highlight.isUserInteractionEnabled = false
    highlight.layer.cornerRadius = 12.0
    view.addSubview(highlight)
    UIView.animate(withDuration: 0.6, delay: 2.2, options: [.curveEaseOut], animations: {
        highlight.alpha = 0.0
    }, completion: { _ in
        highlight.removeFromSuperview()
    })
}

final class DGSettingsLongPressHandler: NSObject {
    weak var controller: ItemListController?
    let page: String

    init(controller: ItemListController, page: String) {
        self.controller = controller
        self.page = page
    }

    @objc func handle(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let controller = self.controller else {
            return
        }
        let point = gesture.location(in: controller.view)
        var target: (key: String, view: UIView)?
        controller.forEachItemNode { node in
            guard target == nil,
                  let tag = (node as? ItemListItemNode)?.tag as? DGSettingItemTag,
                  node.view.bounds.contains(node.view.convert(point, from: controller.view)) else {
                return
            }
            target = (tag.key, node.view)
        }
        guard let target, let url = URL(string: "tg://settings/donutgram/\(page)/\(target.key)") else {
            return
        }
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Копировать ссылку", style: .default, handler: { _ in
            UIPasteboard.general.string = url.absoluteString
        }))
        menu.addAction(UIAlertAction(title: "Поделиться ссылкой", style: .default, handler: { [weak controller] _ in
            let share = UIActivityViewController(activityItems: [url.absoluteString], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = target.view
            share.popoverPresentationController?.sourceRect = target.view.bounds
            controller?.present(share, animated: true)
        }))
        menu.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        menu.popoverPresentationController?.sourceView = target.view
        menu.popoverPresentationController?.sourceRect = target.view.bounds
        controller.present(menu, animated: true)
    }
}
