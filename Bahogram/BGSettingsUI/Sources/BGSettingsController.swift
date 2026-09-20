import Foundation
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

struct BGListState: Equatable { var revision: Int = 0 }

final class BGListArguments {
    let toggle: (String, Bool) -> Void
    let select: (String) -> Void
    let open: (String) -> Void
    let textUpdated: (String, String) -> Void
    init(toggle: @escaping (String, Bool) -> Void, select: @escaping (String) -> Void, open: @escaping (String) -> Void, textUpdated: @escaping (String, String) -> Void) {
        self.toggle = toggle
        self.select = select
        self.open = open
        self.textUpdated = textUpdated
    }
}

enum BGListEntry: ItemListNodeEntry {
    case header(Int32, Int32, String)
    case toggle(Int32, Int32, String, String, Bool, Bool)
    case disclosure(Int32, Int32, String, String, String)
    case checkbox(Int32, Int32, String, String, Bool)
    case info(Int32, Int32, String)
    case input(Int32, Int32, String, String, String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _, _), let .disclosure(_, section, _, _, _), let .checkbox(_, section, _, _, _), let .info(_, section, _), let .input(_, section, _, _, _): return section
        }
    }
    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _, _), let .disclosure(id, _, _, _, _), let .checkbox(id, _, _, _, _), let .info(id, _, _), let .input(id, _, _, _, _): return id
        }
    }
    static func < (lhs: BGListEntry, rhs: BGListEntry) -> Bool { lhs.stableId < rhs.stableId }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BGListArguments
        switch self {
        case let .header(_, _, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .toggle(_, _, key, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enableInteractiveChanges: enabled, enabled: enabled, sectionId: self.section, style: .blocks, updated: { arguments.toggle(key, $0) })
        case let .disclosure(_, _, key, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: { arguments.open(key) })
        case let .checkbox(_, _, key, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: { arguments.select(key) })
        case let .info(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .input(_, _, key, value, placeholder):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), clearType: .always, tag: nil, sectionId: self.section, textUpdated: { arguments.textUpdated(key, $0) })
        }
    }
}

func bgController(context: AccountContext, title: String, entries: @escaping () -> [BGListEntry], toggle: @escaping (String, Bool) -> Void = { _, _ in }, select: @escaping (String) -> Void = { _ in }, textUpdated: @escaping (String, String) -> Void = { _, _ in }, open: @escaping (String) -> ViewController? = { _ in nil }) -> ViewController {
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
    let arguments = BGListArguments(toggle: { key, value in toggle(key, value); refresh() }, select: { key in select(key); refresh() }, open: { key in
        if let controller = open(key) { pushControllerImpl?(controller) }
    }, textUpdated: { key, value in textUpdated(key, value) })
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] pushed in (controller?.navigationController as? NavigationController)?.pushViewController(pushed) }
    return controller
}

public func bgSettingsController(context: AccountContext) -> ViewController {
    return bgController(context: context, title: "Bahogram", entries: {
        [.header(0, 0, "BAHOGRAM"), .disclosure(1, 0, "spy", "Bahogram", ""), .disclosure(2, 0, "chats", "Чаты", ""), .disclosure(3, 0, "appearance", "Оформление", ""), .disclosure(4, 0, "support", "Поддержка", ""), .header(10, 1, "ABOUT"), .info(11, 1, "Bahogram is an unofficial client based on Telegram for iOS.")]
    }, open: { key in
        switch key {
        case "spy": return bgSpySettingsController(context: context)
        case "chats": return bgChatsSettingsController(context: context)
        case "appearance": return bgAppearanceSettingsController(context: context)
        case "support": return bgSupportController(context: context)
        default: return nil
        }
    })
}
