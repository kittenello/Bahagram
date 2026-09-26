import Foundation
import Darwin
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import SettingsUI
import UndoUI

struct BGListState: Equatable { var revision: Int = 0 }

final class BGListArguments {
    let context: AccountContext
    let toggle: (String, Bool) -> Void
    let select: (String) -> Void
    let open: (String) -> Void
    let textUpdated: (String, String) -> Void
    init(context: AccountContext, toggle: @escaping (String, Bool) -> Void, select: @escaping (String) -> Void, open: @escaping (String) -> Void, textUpdated: @escaping (String, String) -> Void) {
        self.context = context
        self.toggle = toggle
        self.select = select
        self.open = open
        self.textUpdated = textUpdated
    }
}

private func bgSettingsSymbol(key: String, title: String) -> String {
    switch key {
    case "downloads", "downloadTikTok", "downloadShorts": return "arrow.down.to.line"
    case "spy", "ghost", "options", "offline": return "eye.slash"
    case "chats", "messages", "tails", "replies": return "bubble.left.and.bubble.right"
    case "appearance", "customBackgrounds": return "paintbrush"
    case "support": return "questionmark.circle"
    case "saveDeleted", "transparentDeleted": return "tray.full"
    case "saveEdits": return "pencil"
    case "saveOnce": return "lock"
    case "saveBots": return "bubble.left"
    case "bypassForward": return "arrowshape.turn.up.right"
    case "readOnAction": return "checkmark.message"
    case "scheduled": return "calendar"
    case "silent": return "speaker.slash"
    case "stories", "hideStories": return "play.rectangle"
    case "premiumStatuses": return "star.slash"
    case "hideTabBar", "wideTabBar": return "rectangle.split.3x1"
    case "contacts", "mutualContact": return "person.2"
    case "calls", "confirmCalls": return "phone"
    case "profileId", "visualId": return "number"
    case "dc": return "network"
    case "regDate", "chatDate": return "calendar"
    case "disableAds": return "xmark.rectangle"
    case "onlyAdded", "recent": return "face.smiling"
    case "reactions": return "heart"
    case "seconds": return "clock"
    case "transcription": return "waveform"
    case "rearCamera": return "camera.rotate"
    case "visualPhone", "number": return "phone"
    case "visualRating": return "star"
    case "visualUsernames": return "at"
    case "signDownloads": return "text.alignleft"
    case "online": return "person.crop.circle"
    case "typing": return "ellipsis.bubble"
    default:
        if title.contains("номер") { return "phone" }
        if title.contains("истори") { return "play.rectangle" }
        if title.contains("звука") { return "speaker.slash" }
        return "gearshape"
    }
}

enum BGListEntry: ItemListNodeEntry {
    case header(Int32, Int32, String)
    case toggle(Int32, Int32, String, String, Bool, Bool)
    case disclosure(Int32, Int32, String, String, String)
    case checkbox(Int32, Int32, String, String, Bool)
    case info(Int32, Int32, String)
    case input(Int32, Int32, String, String, String)
    // The flags (tails, seconds, colored replies) are only a diff key: the bubbles read BGSimpleSettings at layout time.
    case messagePreview(Int32, Int32, Bool, Bool, Bool)
    case appIcons(Int32, Int32)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _, _), let .disclosure(_, section, _, _, _), let .checkbox(_, section, _, _, _), let .info(_, section, _), let .input(_, section, _, _, _), let .messagePreview(_, section, _, _, _), let .appIcons(_, section): return section
        }
    }
    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _, _), let .disclosure(id, _, _, _, _), let .checkbox(id, _, _, _, _), let .info(id, _, _), let .input(id, _, _, _, _), let .messagePreview(id, _, _, _, _), let .appIcons(id, _): return id
        }
    }
    static func < (lhs: BGListEntry, rhs: BGListEntry) -> Bool { lhs.stableId < rhs.stableId }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BGListArguments
        func icon(_ key: String, _ title: String, enabled: Bool = true) -> UIImage? {
            let color = enabled ? presentationData.theme.list.itemPrimaryTextColor : presentationData.theme.list.itemDisabledTextColor
            return PresentationResourcesSettings.bahogramOutlineIcon(bgSettingsSymbol(key: key, title: title), color: color)
        }
        switch self {
        case let .header(_, _, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .toggle(_, _, key, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: icon(key, title, enabled: enabled), title: title, value: value, enableInteractiveChanges: enabled, enabled: enabled, sectionId: self.section, style: .blocks, updated: { arguments.toggle(key, $0) })
        case let .disclosure(_, _, key, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: icon(key, title), title: title, label: label, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: { arguments.open(key) })
        case let .checkbox(_, _, key, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: { arguments.select(key) })
        case let .info(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .input(_, _, key, value, placeholder):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: value, placeholder: placeholder, type: key == "level" ? .number : .regular(capitalization: false, autocorrection: false), clearType: .always, tag: nil, sectionId: self.section, textUpdated: { arguments.textUpdated(key, $0) }, action: {})
        case .messagePreview:
            return bahogramMessagePreviewItem(context: arguments.context, sectionId: self.section)
        case .appIcons:
            return bahogramAppIconItem(context: arguments.context, sectionId: self.section, updated: { arguments.select("refreshAppIcon") })
        }
    }
}

func bgController(context: AccountContext, title: String, entries: @escaping () -> [BGListEntry], restartRequiredKeys: Set<String> = [], toggle: @escaping (String, Bool) -> Void = { _, _ in }, select: @escaping (String) -> Void = { _ in }, textUpdated: @escaping (String, String) -> Void = { _, _ in }, open: @escaping (String) -> ViewController? = { _ in nil }) -> ViewController {
    let initialState = BGListState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let refresh = {
        statePromise.set(stateValue.modify { state in
            var state = state
            state.revision += 1
            return state
        })
    }
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentRestartNoticeImpl: (() -> Void)?
    // Set when a sub-page is pushed: it can change a value this page shows (e.g. the transcription service label).
    var needsRefreshOnAppear = false
    let arguments = BGListArguments(context: context, toggle: { key, value in
        toggle(key, value)
        refresh()
        if restartRequiredKeys.contains(key) { presentRestartNoticeImpl?() }
    }, select: { key in select(key); refresh() }, open: { key in
        if let controller = open(key) {
            needsRefreshOnAppear = true
            pushControllerImpl?(controller)
        }
    }, textUpdated: { key, value in textUpdated(key, value) })
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    // As in upstream theme settings: the chat preview item lays out views, so list updates must run on the main thread.
    controller.alwaysSynchronous = true
    // Re-read the entries on return from a sub-page, but not on other re-appearances (tab switches, dismissed modals):
    // that would overwrite a text field the user is still editing with its stored value.
    controller.didAppear = { firstTime in
        if !firstTime && needsRefreshOnAppear {
            needsRefreshOnAppear = false
            refresh()
        }
    }
    pushControllerImpl = { [weak controller] pushed in (controller?.navigationController as? NavigationController)?.pushViewController(pushed) }
    presentRestartNoticeImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller?.present(UndoOverlayController(
            presentationData: presentationData,
            content: .info(title: nil, text: "Необходим перезапуск", timeout: 5.0, customUndoText: "Перезапустить сейчас"),
            elevatedLayout: false,
            position: .bottom,
            action: { action in
                if case .undo = action {
                    Darwin.exit(0)
                }
                return false
            }
        ), in: .current)
    }
    return controller
}

public func bgSettingsController(context: AccountContext) -> ViewController {
    return bgController(context: context, title: "Bahogram", entries: {
        [.header(0, 0, "BAHOGRAM"), .disclosure(1, 0, "downloads", "Скачивание", ""), .disclosure(2, 0, "spy", "Bahogram", ""), .disclosure(3, 0, "chats", "Чаты", ""), .disclosure(4, 0, "appearance", "Оформление", ""), .disclosure(5, 0, "support", "Поддержка", ""), .header(10, 1, "ABOUT"), .info(11, 1, "Bahogram is an unofficial client based on Telegram for iOS.")]
    }, open: { key in
        switch key {
        case "downloads": return bgDownloadsSettingsController(context: context)
        case "spy": return bgSpySettingsController(context: context)
        case "chats": return bgChatsSettingsController(context: context)
        case "appearance": return bgAppearanceSettingsController(context: context)
        case "support": return bgSupportController(context: context)
        default: return nil
        }
    })
}
