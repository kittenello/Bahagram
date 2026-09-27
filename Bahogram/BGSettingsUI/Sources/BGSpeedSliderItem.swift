import UIKit
import AsyncDisplayKit
import Display
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData

final class BGSpeedSliderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let sectionId: ItemListSectionId
    let value: Int
    let updated: (Int) -> Void

    init(theme: PresentationTheme, sectionId: ItemListSectionId, value: Int, updated: @escaping (Int) -> Void) {
        self.theme = theme
        self.sectionId = sectionId
        self.value = value
        self.updated = updated
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BGSpeedSliderItemNode()
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
            if let nodeValue = node() as? BGSpeedSliderItemNode {
                let makeLayout = nodeValue.asyncLayout()
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async { completion(layout, { _ in apply() }) }
                }
            }
        }
    }
}

final class BGSpeedSliderItemNode: ListViewItemNode {
    private var item: BGSpeedSliderItem?
    private var slider: UISlider?
    private var labels: [UILabel] = []
    private var layoutWidth: CGFloat = 0

    init() {
        super.init(layerBacked: false)
    }

    override func didLoad() {
        super.didLoad()
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 2
        slider.isContinuous = false
        slider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        self.view.addSubview(slider)
        self.slider = slider
        for title in ["Откл.", "Быстро", "Ультра"] {
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 14)
            self.view.addSubview(label)
            self.labels.append(label)
        }
        updateControls()
    }

    func asyncLayout() -> (_ item: BGSpeedSliderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 86), insets: itemListNeighborsGroupedInsets(neighbors, params))
            return (layout, { [weak self] in
                self?.item = item
                self?.layoutWidth = params.width
                self?.updateControls()
            })
        }
    }

    private func updateControls() {
        guard let item else { return }
        self.backgroundColor = item.theme.list.itemBlocksBackgroundColor
        slider?.minimumTrackTintColor = item.theme.list.itemAccentColor
        slider?.maximumTrackTintColor = item.theme.list.itemSecondaryTextColor.withAlphaComponent(0.4)
        slider?.value = Float(item.value)
        slider?.frame = CGRect(x: 20, y: 38, width: max(0, layoutWidth - 40), height: 38)
        for (index, label) in labels.enumerated() {
            label.textColor = index == item.value ? item.theme.list.itemAccentColor : item.theme.list.itemSecondaryTextColor
            let x = index == 0 ? 20.0 : (index == 1 ? layoutWidth / 2 - 48 : layoutWidth - 100)
            label.frame = CGRect(x: x, y: 10, width: 80, height: 22)
            label.textAlignment = index == 0 ? .left : (index == 1 ? .center : .right)
        }
    }

    @objc private func valueChanged() {
        guard let slider else { return }
        let value = min(max(Int(slider.value.rounded()), 0), 2)
        slider.value = Float(value)
        item?.updated(value)
    }
}
