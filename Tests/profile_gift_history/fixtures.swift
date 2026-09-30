import Foundation

typealias StarGiftReference = Int

struct GenericGift: Codable { var id: Int }
struct UniqueGift: Codable { var id: Int; var slug: String }
enum Gift: Codable { case generic(GenericGift); case unique(UniqueGift) }

struct StarGift: Codable {
    var gift: Gift
    var reference: StarGiftReference?
    var date: Int32
    var _fromPeerId: Int?
    var text: String?
    var number: Int?
}

struct DisappearedGift: Codable {
    var gift: StarGift
    var position: Int32
    var previousReference: StarGiftReference?
    var nextReference: StarGiftReference?
    var lastSeen: Int32
    var isMissing: Bool
}

enum History {
    // PRODUCTION_HELPERS
}

var checks = 0
func expect(_ condition: Bool, _ message: String) {
    checks += 1
    if !condition { fatalError(message) }
}

func gift(_ id: Int, reference: Bool = true) -> StarGift {
    // Ordinary bears share their catalog ID; date/sender distinguish instances.
    let kind: Gift = id % 2 == 0 ? .generic(GenericGift(id: 1)) : .unique(UniqueGift(id: id, slug: "gift-\(id)"))
    return StarGift(gift: kind, reference: reference ? id : nil, date: Int32(id), _fromPeerId: id, text: nil, number: nil)
}

func ids(_ history: [DisappearedGift]) -> [Int] {
    return history.map { Int($0.gift.date) }
}

func snapshot(_ gifts: [StarGift]) -> [DisappearedGift] {
    var result = History.giftsWithDisappeared(current: gifts, history: [])
    for index in result.indices { result[index].lastSeen = 123 }
    return result
}

func roundTrip(_ history: [DisappearedGift]) -> [DisappearedGift] {
    return try! JSONDecoder().decode([DisappearedGift].self, from: JSONEncoder().encode(history))
}

func checkPositions(_ history: [DisappearedGift]) {
    for index in history.indices {
        expect(history[index].position == Int32(index), "noncontiguous saved position")
        expect(history[index].previousReference == (index > 0 ? history[index - 1].gift.reference : nil), "stale previous anchor")
        expect(history[index].nextReference == (index + 1 < history.count ? history[index + 1].gift.reference : nil), "stale next anchor")
    }
}

// Every subset of six gifts, with Telegram references, without them, and mixed.
// Delete missing gifts one at a time and reconstruct the view from its saved cache.
for referenceMode in 0..<3 {
    let original = (1...6).map { gift($0, reference: referenceMode == 0 || (referenceMode == 2 && $0 % 2 == 0)) }
    for mask in 0..<64 {
        let current = original.enumerated().filter { (mask & (1 << $0.offset)) == 0 }.map { $0.element }
        var history = snapshot(original)
        for index in history.indices { history[index].isMissing = (mask & (1 << index)) != 0 }
        history = History.giftsWithDisappeared(current: current, history: history)
        expect(ids(history) == Array(1...6), "disappearance moved an existing gift")
        let missing = history.filter { $0.isMissing }.map { $0.gift }
        // The UI receives only missing entries, unlike the full persisted history.
        expect(ids(History.giftsWithDisappeared(current: current, history: history.filter { $0.isMissing })) == ids(history), "UI and cache order disagree")
        for removed in missing.reversed() {
            let expected = ids(history).filter { $0 != Int(removed.date) }
            history = History.removingDisappearedGift(removed, current: current, history: history)!
            expect(ids(history) == expected, "deleting a gift reordered its survivors")
            checkPositions(history)
            history = roundTrip(history)
            expect(ids(History.giftsWithDisappeared(current: current, history: history)) == expected, "reopening changed the order")
            expect(ids(History.giftsWithDisappeared(current: current, history: history.filter { $0.isMissing })) == expected, "reopened UI changed the order")
        }
        expect(History.removingDisappearedGift(gift(99), current: current, history: history) == nil, "unknown deletion modified history")
        let newCurrent = [gift(99)] + current
        let withNewGift = History.giftsWithDisappeared(current: newCurrent, history: snapshot(original).enumerated().map {
            var entry = $0.element
            entry.isMissing = (mask & (1 << $0.offset)) != 0
            return entry
        })
        if !current.isEmpty {
            expect(ids(withNewGift) == [99] + Array(1...6), "new live gift broke the old order")
        }
    }
}

// Two removed bears at the beginning: deleting either keeps banana/lollipop order.
let current = [gift(3), gift(5), gift(7)]
var bears = snapshot([gift(2), gift(4)] + current)
bears[0].isMissing = true
bears[1].isMissing = true
let afterFirst = History.removingDisappearedGift(gift(2), current: current, history: bears)!
expect(ids(afterFirst) == [4, 3, 5, 7], "first bear removal moved banana")
let afterBoth = History.removingDisappearedGift(gift(4), current: current, history: afterFirst)!
expect(ids(afterBoth) == [3, 5, 7], "second bear removal changed live order")

// Legacy entries may both point to one live predecessor or successor.
for useNext in [false, true] {
    let anchor = gift(1)
    let missing = [2, 4].enumerated().map { index, id in
        DisappearedGift(gift: gift(id), position: Int32(index + 1), previousReference: useNext ? nil : 1, nextReference: useNext ? 1 : nil, lastSeen: 123, isMissing: true)
    }
    expect(ids(History.giftsWithDisappeared(current: [anchor], history: missing)) == (useNext ? [2, 4, 1] : [1, 2, 4]), "shared anchor reversed missing bears")
}

// Reappearance consumes a cached missing gift exactly once, including no-reference gifts.
let returned = gift(2, reference: false)
var disappeared = snapshot([returned, gift(4, reference: false)])
disappeared[0].isMissing = true
disappeared[1].isMissing = true
let reappeared = History.giftsWithDisappeared(current: [returned], history: disappeared)
expect(ids(reappeared) == [2, 4], "reappearance duplicated a bear")
expect(!reappeared[0].isMissing, "returned gift still marked missing")
expect(History.removingDisappearedGift(returned, current: [returned], history: disappeared) == nil, "live gift can be removed from memory")

// A cycle in old anchors must terminate and preserve positional fallback.
let cyclic = [
    DisappearedGift(gift: gift(2), position: 0, previousReference: 4, nextReference: 4, lastSeen: 123, isMissing: true),
    DisappearedGift(gift: gift(4), position: 1, previousReference: 2, nextReference: 2, lastSeen: 123, isMissing: true)
]
expect(ids(History.giftsWithDisappeared(current: [gift(7)], history: cyclic)) == [2, 4, 7], "cyclic legacy anchors changed fallback")
print("Profile gift history: \(checks) checks passed")
