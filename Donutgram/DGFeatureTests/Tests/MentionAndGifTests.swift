import XCTest
import UIKit
import CoreText
import Postbox
import TelegramCore
import InteractiveTextComponent
import DGSimpleSettings

final class MentionAndGifTests: XCTestCase {
    private let embeddedKey = NSAttributedString.Key("Attribute__EmbeddedItem")

    private func text(_ string: String) -> NSAttributedString {
        return NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: 17.0), .foregroundColor: UIColor.blue])
    }

    private func group(rights: TelegramChatBannedRightsFlags = [], role: TelegramGroupRole = .member) -> TelegramGroup {
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(1)), title: "Test", photo: [], participantCount: 2, role: role, membership: .Member, flags: [], defaultBannedRights: TelegramChatBannedRights(flags: rights, untilDate: Int32.max), migrationReference: nil, creationDate: 0, version: 1)
    }

    func testMentionPreservesTextAndUTF16OffsetsAfterEmoji() {
        let source = self.text("🙂 @alice, ссылка")
        let range = (source.string as NSString).range(of: "@alice")
        let result = textWithMentionAvatars(source, entities: [MessageTextEntity(range: range.location ..< NSMaxRange(range), type: .Mention)], peers: [])
        XCTAssertEqual(result.string, source.string)
        XCTAssertEqual(result.length, source.length)
        XCTAssertNotNil(result.attribute(self.embeddedKey, at: range.location, effectiveRange: nil))
        XCTAssertNil(result.attribute(self.embeddedKey, at: range.location + 1, effectiveRange: nil))
        XCTAssertNotNil(result.attribute(NSAttributedString.Key(kCTRunDelegateAttributeName as String), at: range.location, effectiveRange: nil))
    }

    func testNamedMentionPreservesComposedFirstCharacter() {
        let peer = self.group()
        let source = self.text("👩‍💻 Анна")
        let result = textWithMentionAvatars(source, entities: [MessageTextEntity(range: 0 ..< source.length, type: .TextMention(peerId: peer.id))], peers: [EnginePeer(peer)])
        XCTAssertEqual(result.string, source.string)
        let first = (source.string as NSString).rangeOfComposedCharacterSequence(at: 0)
        for index in 0 ..< NSMaxRange(first) {
            XCTAssertNotNil(result.attribute(self.embeddedKey, at: index, effectiveRange: nil))
        }
        XCTAssertNil(result.attribute(self.embeddedKey, at: NSMaxRange(first), effectiveRange: nil))
    }

    func testSpoilersAndCodeDoNotResolveMentionAvatars() {
        let source = self.text("@alice @bob")
        let entities = [MessageTextEntity(range: 0 ..< 6, type: .Mention), MessageTextEntity(range: 0 ..< 6, type: .Spoiler), MessageTextEntity(range: 7 ..< 11, type: .Mention), MessageTextEntity(range: 7 ..< 11, type: .Code)]
        let result = textWithMentionAvatars(source, entities: entities, peers: [])
        XCTAssertEqual(result, source)
    }

    func testInvalidEntityOffsetsLeaveTextUntouched() {
        let source = self.text("@alice")
        let result = textWithMentionAvatars(source, entities: [MessageTextEntity(range: -1 ..< 4, type: .Mention), MessageTextEntity(range: 0 ..< 99, type: .Mention)], peers: [])
        XCTAssertEqual(result, source)
    }

    func testMentionLinkAndFollowingTextStayAtOriginalOffsets() {
        let source = NSMutableAttributedString(attributedString: self.text("@alice и @bob"))
        let url = URL(string: "https://t.me/alice")!
        source.addAttribute(.link, value: url, range: NSRange(location: 0, length: 6))
        let entities = [MessageTextEntity(range: 0 ..< 6, type: .Mention), MessageTextEntity(range: 9 ..< 13, type: .Mention)]
        let result = textWithMentionAvatars(source, entities: entities, peers: [])
        XCTAssertEqual(result.string, source.string)
        for index in 0 ..< 6 {
            XCTAssertEqual(result.attribute(.link, at: index, effectiveRange: nil) as? URL, url)
        }
        XCTAssertNotNil(result.attribute(self.embeddedKey, at: 9, effectiveRange: nil))
    }

    func testOrdinarySilentVideosAreNotTreatedAsConvertedGifs() {
        let resource = LocalFileMediaResource(fileId: 1)
        let video = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 1), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: 10, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: 1.0, size: PixelDimensions(width: 100, height: 100), flags: [.isSilent], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])
        XCTAssertFalse(donutgramIsGifVideo(video))
        let converted = video.withUpdatedAttributes([.FileName(fileName: "gif-video.mp4"), .Video(duration: 1.0, size: PixelDimensions(width: 100, height: 100), flags: [.isSilent], preloadSize: nil, coverTime: nil, videoCodec: nil)])
        XCTAssertTrue(donutgramIsGifVideo(converted))
        XCTAssertFalse(converted.isAnimated)
        XCTAssertTrue(converted.isVideo)
    }

    func testGifFallbackRequiresVideoPermissionAndEnabledSetting() {
        let previous = DGSimpleSettings.shared.gifUnlock
        defer { DGSimpleSettings.shared.gifUnlock = previous }
        DGSimpleSettings.shared.gifUnlock = true
        XCTAssertTrue(donutgramCanSendGifAsVideo(peer: self.group(rights: [.banSendGifs, .banSendStickers])))
        XCTAssertFalse(donutgramCanSendGifAsVideo(peer: self.group(rights: [.banSendGifs, .banSendVideos])))
        XCTAssertFalse(donutgramCanSendGifAsVideo(peer: self.group(rights: [.banSendGifs, .banSendMedia])))
        XCTAssertFalse(donutgramCanSendGifAsVideo(peer: self.group()))
        XCTAssertFalse(donutgramCanSendGifAsVideo(peer: self.group(rights: [.banSendGifs], role: .creator(rank: nil))))
        DGSimpleSettings.shared.gifUnlock = false
        XCTAssertFalse(donutgramCanSendGifAsVideo(peer: self.group(rights: [.banSendGifs])))
    }
}
