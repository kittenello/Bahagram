import Foundation
import UIKit
import AsyncDisplayKit
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
    case "Внешний вид": return "chat-list-appearance"
    case "Текст в заголовке": return "chat-list-title"
    case "Перемотка двойным нажатием": return "double-tap-seek"
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

final class DGSettingsLongPressHandler: NSObject, UIGestureRecognizerDelegate {
    weak var controller: ItemListController?
    let page: String

    init(controller: ItemListController, page: String) {
        self.controller = controller
        self.page = page
    }

    private func target(at point: CGPoint, in controller: ItemListController) -> (key: String, view: UIView)? {
        var found: (key: String, view: UIView)?
        controller.forEachItemNode { node in
            guard found == nil,
                  let tag = (node as? ItemListItemNode)?.tag as? DGSettingItemTag,
                  node.view.bounds.contains(node.view.convert(point, from: controller.view)) else {
                return
            }
            found = (tag.key, node.view)
        }
        return found
    }

    // Only a hold on a list row opens the menu. Touches outside the list (the navigation bar over a row scrolled
    // under it, a toast) and on a row's own control (switch, slider, text field, clear button) keep their behavior.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var currentView = touch.view
        while let view = currentView {
            if view is UIControl || view.asyncdisplaykit_node is ASControlNode {
                return false
            }
            if view is ListViewBackingView {
                return true
            }
            currentView = view.superview
        }
        return false
    }

    // Beginning cancels the touch in the list, so it must not begin where there is no link to show.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let controller = self.controller else {
            return false
        }
        return self.target(at: gestureRecognizer.location(in: controller.view), in: controller) != nil
    }

    @objc func handle(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let controller = self.controller,
              let target = self.target(at: gesture.location(in: controller.view), in: controller),
              let url = URL(string: "tg://settings/donutgram/\(page)/\(target.key)") else {
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
