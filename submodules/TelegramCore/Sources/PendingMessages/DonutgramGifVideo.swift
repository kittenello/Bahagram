import Foundation
import Postbox
import SwiftSignalKit
import DGSimpleSettings

/// GIFs can use the video permission only when that permission is still available.
public func donutgramCanSendGifAsVideo(peer: Peer?) -> Bool {
    guard DGSimpleSettings.shared.gifUnlock else { return false }
    if let peer = peer as? TelegramChannel {
        return peer.hasBannedPermission(.banSendGifs) != nil && peer.hasBannedPermission(.banSendVideos) == nil && peer.hasBannedPermission(.banSendMedia) == nil && peer.hasBannedPermission(.banReadMessages) == nil
    } else if let peer = peer as? TelegramGroup {
        return peer.hasBannedPermission(.banSendGifs) && !peer.hasBannedPermission(.banSendVideos) && !peer.hasBannedPermission(.banSendMedia) && !peer.hasBannedPermission(.banReadMessages)
    }
    return false
}

public func donutgramIsSilentVideo(_ file: TelegramMediaFile) -> Bool {
    for case let .Video(_, _, flags, _, _, _) in file.attributes {
        if flags.contains(.isSilent) { return true }
    }
    return false
}

/// The filename survives delivery, so converted GIF videos can loop after a restart.
public func donutgramIsGifVideo(_ file: TelegramMediaFile) -> Bool {
    return !file.isAnimated && file.fileName == "gif-video.mp4" && donutgramIsSilentVideo(file)
}

private func localGifVideo(account: Account, peerId: PeerId, reference: AnyMediaReference, file: TelegramMediaFile) -> Signal<AnyMediaReference?, NoError> {
    return Signal { subscriber in
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        let dataDisposable = MetaDisposable()
        let fetchDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(peerId), userContentType: .video, reference: reference.resourceReference(file.resource)).start(error: { _ in
            subscriber.putNext(nil)
            subscriber.putCompletion()
        })
        dataDisposable.set((account.postbox.mediaBox.resourceData(file.resource, option: .complete(waitUntilFetchStatus: true))
        |> filter { $0.complete }
        |> take(1)).start(next: { data in
            account.postbox.mediaBox.copyResourceData(from: file.resource.id, to: resource.id, synchronous: true)
            var attributes = file.attributes.filter { attribute in
                switch attribute {
                case .Animated, .Video, .Audio, .FileName: return false
                default: return true
                }
            }
            attributes.append(.FileName(fileName: "gif-video.mp4"))
            attributes.append(.Video(duration: file.duration ?? 0.0, size: file.dimensions ?? PixelDimensions(width: 128, height: 128), flags: [.isSilent, .supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil))
            // image/gif is converted to MP4 by the existing UI media transformer.
            let converted = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: resource.fileId), partialReference: nil, resource: resource, previewRepresentations: file.previewRepresentations, videoThumbnails: [], immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType == "image/gif" ? "image/gif" : "video/mp4", size: data.size, attributes: attributes, alternativeRepresentations: [])
            subscriber.putNext(.standalone(media: converted))
            subscriber.putCompletion()
        }))
        return ActionDisposable {
            fetchDisposable.dispose()
            dataDisposable.dispose()
        }
    }
    |> timeout(60.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
}

func prepareDonutgramGifVideos(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[EnqueueMessage], NoError> {
    guard DGSimpleSettings.shared.gifUnlock, messages.contains(where: { message in
        if case let .message(_, _, _, reference, _, _, _, _, _, _) = message, let file = reference?.media as? TelegramMediaFile {
            return file.isAnimated && !file.isSticker && !file.isCustomEmoji
        }
        return false
    }) else {
        return .single(messages)
    }
    return account.postbox.transaction { transaction in
        return donutgramCanSendGifAsVideo(peer: transaction.getPeer(peerId))
    }
    |> mapToSignal { enabled -> Signal<[EnqueueMessage], NoError> in
        guard enabled else { return .single(messages) }
        return combineLatest(messages.map { message -> Signal<EnqueueMessage, NoError> in
            guard case let .message(text, attributes, inlineStickers, reference?, threadId, replyId, storyId, groupingKey, correlationId, bubbleUp) = message, let file = reference.media as? TelegramMediaFile, file.isAnimated, !file.isSticker, !file.isCustomEmoji else {
                return .single(message)
            }
            return localGifVideo(account: account, peerId: peerId, reference: reference, file: file)
            |> map { converted in
                guard let converted else { return message }
                // Inline-result sending would retain the server's original GIF classification.
                let attributes = attributes.filter { !($0 is OutgoingChatContextResultMessageAttribute) && !($0 is InlineBotMessageAttribute) }
                return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: converted, threadId: threadId, replyToMessageId: replyId, replyToStoryId: storyId, localGroupingKey: groupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUp)
            }
        })
    }
}
