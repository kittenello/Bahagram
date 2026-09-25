import Foundation
import UIKit
import AVFoundation
import Postbox
import TelegramCore
import OverlayStatusController
import PresentationDataUtils
import UndoUI
import BGSimpleSettings

extension ChatControllerImpl {
    func bahogramTryStartMediaDownload(_ messages: [EnqueueMessage], postpone: Bool, commit: Bool) -> Bool {
        guard messages.count == 1 else {
            return false
        }
        guard case let .message(text, _, inlineStickers, mediaReference, _, _, _, _, _, _) = messages[0], mediaReference == nil, inlineStickers.isEmpty else {
            return false
        }
        let linkText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard linkText.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, let url = URL(string: linkText), let service = bahogramDownloadService(for: url) else {
            return false
        }

        let settings = BGSimpleSettings.shared
        switch service {
        case .tiktok where !settings.downloadTikTok:
            return false
        case .youtubeShorts where !settings.downloadYouTubeShorts:
            return false
        default:
            break
        }

        guard self.bahogramMediaDownloader == nil else {
            self.bahogramDisplayMediaDownloadError("Дождитесь окончания текущего скачивания.")
            return true
        }

        let downloader = BahogramMediaDownloader(endpoint: settings.cobaltEndpoint, sourceURL: url)
        self.bahogramMediaDownloader = downloader
        let statusController = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: { [weak downloader] in
            downloader?.cancel()
        }))
        self.present(statusController, in: .window(.root))

        downloader.start { [weak self, weak statusController] result in
            statusController?.dismiss()
            guard let self else {
                return
            }
            self.bahogramMediaDownloader = nil
            switch result {
            case let .success(downloadedMedia):
                let convertedMessages = self.bahogramEnqueueMessages(from: downloadedMedia, original: messages[0], service: service, addCaption: settings.signDownloadedMedia)
                guard !convertedMessages.isEmpty else {
                    self.bahogramDisplayMediaDownloadError("Не удалось подготовить скачанные файлы к отправке.")
                    return
                }
                self.sendMessages(convertedMessages, media: true, postpone: postpone, commit: commit)
            case let .failure(error):
                if (error as? URLError)?.code != .cancelled {
                    self.bahogramDisplayMediaDownloadError(error.localizedDescription)
                }
            }
        }
        return true
    }

    private func bahogramEnqueueMessages(from downloadedMedia: [BahogramDownloadedMedia], original: EnqueueMessage, service: BahogramMediaDownloadService, addCaption: Bool) -> [EnqueueMessage] {
        guard case let .message(_, originalAttributes, _, _, threadId, replyToMessageId, replyToStoryId, _, correlationId, bubbleUpEmojiOrStickersets) = original else {
            return []
        }
        let attributes = originalAttributes.filter { !($0 is TextEntitiesMessageAttribute) }
        var result: [EnqueueMessage] = []
        var groupingKey: Int64?

        for (index, item) in downloadedMedia.enumerated() {
            if downloadedMedia.count > 1, index % 10 == 0 {
                groupingKey = Int64.random(in: Int64.min ... Int64.max)
            }
            guard let mediaReference = self.bahogramMediaReference(item) else {
                continue
            }
            result.append(.message(
                text: addCaption && index == 0 ? service.caption : "",
                attributes: attributes,
                inlineStickers: [:],
                mediaReference: mediaReference,
                threadId: threadId,
                replyToMessageId: replyToMessageId,
                replyToStoryId: replyToStoryId,
                localGroupingKey: downloadedMedia.count > 1 ? groupingKey : nil,
                correlationId: index == 0 ? correlationId : nil,
                bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets
            ))
        }
        return result
    }

    private func bahogramMediaReference(_ item: BahogramDownloadedMedia) -> AnyMediaReference? {
        let inferredKind: BahogramDownloadedMediaKind
        if item.kind != .unknown {
            inferredKind = item.kind
        } else if item.mimeType.hasPrefix("image/") && item.mimeType != "image/gif" {
            inferredKind = .photo
        } else if item.mimeType.hasPrefix("video/") {
            inferredKind = .video
        } else if item.mimeType == "image/gif" {
            inferredKind = .gif
        } else {
            inferredKind = .unknown
        }

        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(item.data.count))
        self.context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: item.data, synchronous: true)

        if inferredKind == .photo, let image = UIImage(data: item.data) {
            let width = Int32(max(1, image.cgImage?.width ?? Int(image.size.width * image.scale)))
            let height = Int32(max(1, image.cgImage?.height ?? Int(image.size.height * image.scale)))
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: width, height: height), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
            let media = TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
            return .standalone(media: media)
        }

        var attributes: [TelegramMediaFileAttribute] = [.FileName(fileName: item.filename)]
        if inferredKind == .video {
            var duration = 0.0
            var dimensions = PixelDimensions(width: 0, height: 0)
            let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bahogram-\(UUID().uuidString).mp4")
            if (try? item.data.write(to: temporaryURL, options: .atomic)) != nil {
                let asset = AVURLAsset(url: temporaryURL)
                duration = asset.duration.seconds.isFinite ? max(0.0, asset.duration.seconds) : 0.0
                if let videoTrack = asset.tracks(withMediaType: .video).first {
                    let transformedSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                    dimensions = PixelDimensions(width: Int32(max(0.0, abs(transformedSize.width))), height: Int32(max(0.0, abs(transformedSize.height))))
                }
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            attributes.append(.Video(duration: duration, size: dimensions, flags: .supportsStreaming, preloadSize: nil, coverTime: nil, videoCodec: nil))
        } else if inferredKind == .gif {
            attributes.append(.Animated)
        }
        let media = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: item.mimeType, size: Int64(item.data.count), attributes: attributes, alternativeRepresentations: [])
        return .standalone(media: media)
    }

    private func bahogramDisplayMediaDownloadError(_ text: String) {
        self.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: "Не удалось скачать", text: text, timeout: 5.0, customUndoText: nil), elevatedLayout: false, position: .bottom, action: { _ in false }), in: .current)
    }
}
