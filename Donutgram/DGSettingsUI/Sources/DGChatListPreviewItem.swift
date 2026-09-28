import UIKit
import AsyncDisplayKit
import Display
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData

final class DGChatListPreviewItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    let snow: Bool
    let hideStatus: Bool
    let centerTitle: Bool
    let hideSearch: Bool
    let senderAvatars: Bool
    let titleMode: Int

    init(theme: PresentationTheme, sectionId: ItemListSectionId, snow: Bool, hideStatus: Bool, centerTitle: Bool, hideSearch: Bool, senderAvatars: Bool, titleMode: Int) {
        self.theme = theme
        self.sectionId = sectionId
        self.snow = snow
        self.hideStatus = hideStatus
        self.centerTitle = centerTitle
        self.hideSearch = hideSearch
        self.senderAvatars = senderAvatars
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
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let menuLabel = UILabel()
    private let search = UIView()
    private let searchLabel = UILabel()
    private let avatar = UIView()
    private let senderAvatar = UIView()
    private let rowTitle = UILabel()
    private let rowMessage = UILabel()
    private let snowLabel = UILabel()

    init() {
        super.init(layerBacked: false)
    }

    override func didLoad() {
        super.didLoad()
        self.view.addSubview(self.block)
        self.block.addSubview(self.panel)
        self.panel.addSubview(self.titleLabel)
        self.panel.addSubview(self.statusLabel)
        self.panel.addSubview(self.menuLabel)
        self.panel.addSubview(self.search)
        self.search.addSubview(self.searchLabel)
        self.panel.addSubview(self.avatar)
        self.panel.addSubview(self.senderAvatar)
        self.panel.addSubview(self.rowTitle)
        self.panel.addSubview(self.rowMessage)
        self.panel.addSubview(self.snowLabel)

        self.block.isUserInteractionEnabled = false
        self.block.layer.cornerRadius = 22.0
        self.block.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.block.clipsToBounds = true
        self.panel.layer.cornerRadius = 16.0
        self.panel.clipsToBounds = true
        self.search.layer.cornerRadius = 10.0
        self.search.clipsToBounds = true
        self.avatar.layer.cornerRadius = 18.0
        self.senderAvatar.layer.cornerRadius = 8.0
        self.senderAvatar.layer.borderWidth = 2.0

        self.titleLabel.font = .systemFont(ofSize: 21.0, weight: .semibold)
        self.statusLabel.font = .systemFont(ofSize: 10.0)
        self.menuLabel.font = .systemFont(ofSize: 22.0, weight: .semibold)
        self.menuLabel.text = "⋮"
        self.menuLabel.textAlignment = .center
        self.searchLabel.font = .systemFont(ofSize: 12.0)
        self.searchLabel.text = "⌕  Поиск"
        self.rowTitle.font = .systemFont(ofSize: 13.0, weight: .semibold)
        self.rowTitle.text = "Donutgram"
        self.rowMessage.font = .systemFont(ofSize: 11.0)
        self.rowMessage.text = "Привет! Как дела?"
        self.snowLabel.font = .systemFont(ofSize: 13.0)
        self.snowLabel.text = "❄︎      ·      ❄︎"
        self.snowLabel.textAlignment = .center
        self.updateControls()
    }

    func asyncLayout() -> (_ item: DGChatListPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 166.0), insets: itemListNeighborsGroupedInsets(neighbors, params))
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
        guard let item else { return }
        self.backgroundColor = .clear
        self.block.backgroundColor = item.theme.list.itemBlocksBackgroundColor
        let primary = item.theme.list.itemPrimaryTextColor
        let secondary = item.theme.list.itemSecondaryTextColor
        let accent = item.theme.list.itemAccentColor
        self.panel.backgroundColor = secondary.withAlphaComponent(0.11)
        self.search.backgroundColor = secondary.withAlphaComponent(0.12)
        self.avatar.backgroundColor = accent.withAlphaComponent(0.82)
        self.senderAvatar.backgroundColor = secondary
        self.senderAvatar.layer.borderColor = item.theme.list.itemBlocksBackgroundColor.cgColor
        self.titleLabel.textColor = primary
        self.statusLabel.textColor = secondary
        self.menuLabel.textColor = primary
        self.searchLabel.textColor = secondary
        self.rowTitle.textColor = primary
        self.rowMessage.textColor = secondary
        self.snowLabel.textColor = primary.withAlphaComponent(0.7)

        switch item.titleMode {
        case 1: self.titleLabel.text = "Donutgram"
        case 2: self.titleLabel.text = "@username"
        case 3: self.titleLabel.text = "Никнейм"
        default: self.titleLabel.text = "Чаты"
        }
        self.statusLabel.isHidden = item.hideStatus
        self.statusLabel.text = "Подключение..."
        self.search.isHidden = item.hideSearch
        self.senderAvatar.isHidden = !item.senderAvatars
        self.snowLabel.isHidden = !item.snow

        let blockWidth = max(0.0, self.layoutWidth - self.leftInset - self.rightInset)
        self.block.frame = CGRect(x: self.leftInset, y: 0, width: blockWidth, height: 166.0)
        self.panel.frame = CGRect(x: 14.0, y: 14.0, width: max(0.0, blockWidth - 28.0), height: 136.0)
        let width = self.panel.bounds.width
        self.titleLabel.frame = CGRect(x: item.centerTitle ? 45.0 : 17.0, y: 10.0, width: max(0.0, width - (item.centerTitle ? 90.0 : 55.0)), height: 28.0)
        self.titleLabel.textAlignment = item.centerTitle ? .center : .left
        self.statusLabel.frame = CGRect(x: 17.0, y: 36.0, width: max(0.0, width - 50.0), height: 16.0)
        self.menuLabel.frame = CGRect(x: width - 38.0, y: 14.0, width: 25.0, height: 29.0)
        self.search.frame = CGRect(x: 14.0, y: 58.0, width: max(0.0, width - 28.0), height: 28.0)
        self.searchLabel.frame = CGRect(x: 10.0, y: 3.0, width: max(0.0, self.search.bounds.width - 20.0), height: 22.0)
        let rowY: CGFloat = item.hideSearch ? 72.0 : 96.0
        self.avatar.frame = CGRect(x: 16.0, y: rowY, width: 36.0, height: 36.0)
        self.senderAvatar.frame = CGRect(x: 43.0, y: rowY + 23.0, width: 16.0, height: 16.0)
        self.rowTitle.frame = CGRect(x: 64.0, y: rowY, width: max(0.0, width - 80.0), height: 18.0)
        self.rowMessage.frame = CGRect(x: 64.0, y: rowY + 17.0, width: max(0.0, width - 80.0), height: 18.0)
        self.snowLabel.frame = CGRect(x: 10.0, y: 5.0, width: max(0.0, width - 20.0), height: 20.0)
    }
}
