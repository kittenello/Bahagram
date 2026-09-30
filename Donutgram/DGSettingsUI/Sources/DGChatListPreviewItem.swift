import UIKit
import AsyncDisplayKit
import Display
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import LocalizedPeerData
import AccountContext
import TelegramCore
import ChatListTitleView
import DGSnowEffect

final class DGChatListPreviewItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    let snow: Bool
    let hideStatus: Bool
    let centerTitle: Bool
    let titleMode: Int

    init(context: AccountContext, theme: PresentationTheme, sectionId: ItemListSectionId, snow: Bool, hideStatus: Bool, centerTitle: Bool, titleMode: Int) {
        self.context = context
        self.theme = theme
        self.sectionId = sectionId
        self.snow = snow
        self.hideStatus = hideStatus
        self.centerTitle = centerTitle
        self.titleMode = titleMode
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = DGChatListPreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { (nil, { _ in apply() }) })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? DGChatListPreviewItemNode {
                let makeLayout = nodeValue.asyncLayout()
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async { completion(layout, { _ in apply() }) }
                }
            }
        }
    }
}

final class DGChatListPreviewItemNode: ListViewItemNode, ItemListItemNode {
    var tag: ItemListItemTag? { DGSettingItemTag(key: "chatListPreview") }
    private var item: DGChatListPreviewItem?
    private var layoutWidth: CGFloat = 0
    private var leftInset: CGFloat = 0
    private var rightInset: CGFloat = 0
    private let block = UIView()
    private let panel = UIView()
    private let menuLabel = UILabel()
    private let snowView = DGSnowView()
    private var titleView: ChatListTitleView?
    private var accountPeer: EnginePeer?
    private var presentationData: PresentationData?
    private let peerDisposable = MetaDisposable()
    private var subscribed = false

    init() {
        super.init(layerBacked: false)
    }

    deinit {
        self.peerDisposable.dispose()
    }

    override func didLoad() {
        super.didLoad()
        self.view.addSubview(self.block)
        self.block.addSubview(self.panel)
        self.panel.addSubview(self.menuLabel)
        self.panel.addSubview(self.snowView)
        self.block.isUserInteractionEnabled = false
        self.block.layer.cornerRadius = 22.0
        self.block.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.block.clipsToBounds = true
        self.panel.layer.cornerRadius = 16.0
        self.panel.layer.borderWidth = UIScreenPixel
        self.panel.clipsToBounds = true
        self.menuLabel.font = .systemFont(ofSize: 22.0, weight: .semibold)
        self.menuLabel.text = "⋮"
        self.menuLabel.textAlignment = .center
        self.updateControls()
    }

    func displayHighlight() {
        guard let item else { return }
        dgDisplayHighlight(in: self.block, theme: item.theme)
    }

    func asyncLayout() -> (_ item: DGChatListPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 104.0), insets: itemListNeighborsGroupedInsets(neighbors, params))
            return (layout, { [weak self] in
                self?.item = item
                self?.layoutWidth = params.width
                self?.leftInset = params.leftInset
                self?.rightInset = params.rightInset
                self?.updateControls()
            })
        }
    }

    private func updateControls() {
        guard self.isNodeLoaded, let item else { return }
        if !self.subscribed {
            self.subscribed = true
            self.peerDisposable.set((combineLatest(
                item.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: item.context.account.peerId)),
                item.context.sharedContext.presentationData
            ) |> deliverOnMainQueue).start(next: { [weak self] peer, presentationData in
                self?.accountPeer = peer
                self?.presentationData = presentationData
                self?.updateControls()
            }))
        }
        let presentationData = self.presentationData ?? item.context.sharedContext.currentPresentationData.with { $0 }
        self.backgroundColor = .clear
        self.block.backgroundColor = item.theme.list.itemBlocksBackgroundColor
        self.panel.backgroundColor = item.theme.list.itemSecondaryTextColor.withAlphaComponent(0.11)
        self.panel.layer.borderColor = item.theme.list.itemSecondaryTextColor.withAlphaComponent(0.2).cgColor
        self.menuLabel.textColor = item.theme.list.itemPrimaryTextColor
        let titleView: ChatListTitleView
        if let current = self.titleView {
            titleView = current
        } else {
            titleView = ChatListTitleView(context: item.context, theme: item.theme, strings: presentationData.strings, animationCache: item.context.animationCache, animationRenderer: item.context.animationRenderer)
            titleView.manualLayout = true
            self.titleView = titleView
            self.panel.insertSubview(titleView, belowSubview: self.menuLabel)
        }
        titleView.theme = item.theme
        titleView.strings = presentationData.strings
        let title: String
        switch item.titleMode {
        case 1: title = "Donutgram"
        case 2:
            if let addressName = self.accountPeer?.addressName, !addressName.isEmpty {
                title = "@\(addressName)"
            } else {
                title = presentationData.strings.DialogList_Title
            }
        case 3:
            title = self.accountPeer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? presentationData.strings.DialogList_Title
        default: title = presentationData.strings.DialogList_Title
        }
        var peerStatus: NetworkStatusTitle.Status?
        if !item.hideStatus, case let .user(user) = self.accountPeer {
            if let emojiStatus = user.emojiStatus {
                peerStatus = .emoji(emojiStatus)
            } else if user.isPremium {
                peerStatus = .premium
            }
        }
        titleView.setTitle(NetworkStatusTitle(text: title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false, peerStatus: peerStatus), animated: false)
        titleView.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(21.0), textColor: item.theme.list.itemPrimaryTextColor)
        let blockWidth = max(0.0, self.layoutWidth - self.leftInset - self.rightInset)
        self.block.frame = CGRect(x: self.leftInset, y: 0, width: blockWidth, height: 104.0)
        self.panel.frame = CGRect(x: 22.0, y: 22.0, width: max(0.0, blockWidth - 44.0), height: 60.0)
        let width = self.panel.bounds.width
        let titleSize = CGSize(width: max(1.0, width - 80.0), height: 60.0)
        let contentRect = titleView.updateLayoutInternal(size: titleSize, transition: .immediate, centerTitle: true)
        titleView.frame = CGRect(origin: CGPoint(x: item.centerTitle ? (width - titleSize.width) / 2.0 : 18.0 - contentRect.minX, y: 0.0), size: titleSize)
        self.menuLabel.frame = CGRect(x: width - 38.0, y: 15.0, width: 25.0, height: 30.0)
        self.snowView.frame = self.panel.bounds
        self.snowView.isHidden = !item.snow
        self.snowView.update(isDark: item.theme.overallDarkAppearance)
        self.panel.bringSubviewToFront(self.snowView)
    }
}
