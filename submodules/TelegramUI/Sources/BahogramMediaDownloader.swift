import Foundation
import AVFoundation
import YouTubeKit

enum BahogramMediaDownloadService: Equatable {
    case tiktok
    case youtubeShorts

    var caption: String {
        switch self {
        case .tiktok:
            return "Скачано с TikTok"
        case .youtubeShorts:
            return "Скачано с YouTube"
        }
    }
}

enum BahogramDownloadedMediaKind: Equatable {
    case photo
    case video
    case gif
    case unknown
}

struct BahogramDownloadedMedia {
    let data: Data
    let kind: BahogramDownloadedMediaKind
    let filename: String
    let mimeType: String
}

enum BahogramMediaDownloadError: LocalizedError {
    case invalidResponse
    case emptyResult
    case noCompatibleVideo

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Не удалось получить медиа по ссылке."
        case .emptyResult:
            return "На странице не найдено фото или видео."
        case .noCompatibleVideo:
            return "Для этого Shorts не найден подходящий MP4-поток."
        }
    }
}

func bahogramDownloadService(for url: URL) -> BahogramMediaDownloadService? {
    guard let host = url.host?.lowercased() else {
        return nil
    }
    if host == "tiktok.com" || host.hasSuffix(".tiktok.com") {
        return .tiktok
    }
    if host == "youtube.com" || host.hasSuffix(".youtube.com") {
        let path = url.path.lowercased()
        if path == "/shorts" || path.hasPrefix("/shorts/") {
            return .youtubeShorts
        }
    }
    return nil
}

private struct BahogramRemoteMedia {
    let url: URL
    let kind: BahogramDownloadedMediaKind
    let filename: String?
}

final class BahogramMediaDownloader {
    private let sourceURL: URL
    private let service: BahogramMediaDownloadService
    private let session: URLSession
    private let lock = NSLock()
    private var tasks: [URLSessionTask] = []
    private var extractionTask: Task<Void, Never>?
    private var cancelled = false

    init(sourceURL: URL, service: BahogramMediaDownloadService) {
        self.sourceURL = sourceURL
        self.service = service
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60.0
        configuration.timeoutIntervalForResource = 600.0
        configuration.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: configuration)
    }

    deinit {
        self.session.invalidateAndCancel()
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let tasks = self.tasks
        let extractionTask = self.extractionTask
        self.lock.unlock()
        extractionTask?.cancel()
        for task in tasks {
            task.cancel()
        }
    }

    func start(completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        switch self.service {
        case .tiktok:
            self.startTikTok(completion: completion)
        case .youtubeShorts:
            self.startYouTube(completion: completion)
        }
    }

    private func startTikTok(completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        var components = URLComponents(string: "https://www.tikwm.com/api/")!
        components.queryItems = [URLQueryItem(name: "url", value: self.sourceURL.absoluteString), URLQueryItem(name: "hd", value: "1")]
        guard let url = components.url else {
            self.startTikTokDirect(completion: completion)
            return
        }
        let task = self.session.dataTask(with: url) { [weak self] data, response, _ in
            guard let self else { return }
            if let response = response as? HTTPURLResponse, (200 ... 299).contains(response.statusCode),
               let data, let media = self.tikWMMedia(from: data), !media.isEmpty {
                self.download(media, completion: completion)
            } else {
                self.startTikTokDirect(completion: completion)
            }
        }
        self.add(task)
        task.resume()
    }

    private func tikWMMedia(from data: Data) -> [BahogramRemoteMedia]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = root["code"] as? Int, code == 0,
              let item = root["data"] as? [String: Any] else { return nil }
        let postId = (item["id"] as? String) ?? "post"
        if let images = item["images"] as? [String], !images.isEmpty {
            let media = images.enumerated().compactMap { index, address -> BahogramRemoteMedia? in
                guard let url = URL(string: address) else { return nil }
                return BahogramRemoteMedia(url: url, kind: .photo, filename: "tiktok-\(postId)-\(index + 1).jpg")
            }
            return media.count == images.count ? media : nil
        }
        for key in ["hdplay", "play"] {
            if let address = item[key] as? String, let url = URL(string: address) {
                return [BahogramRemoteMedia(url: url, kind: .video, filename: "tiktok-\(postId).mp4")]
            }
        }
        return nil
    }

    private func startTikTokDirect(completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        var request = URLRequest(url: self.sourceURL)
        // TikTok returns a different JSON schema to mobile Safari.
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        let task = self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.finish(.failure(error), completion: completion)
                return
            }
            guard let response = response as? HTTPURLResponse, (200 ... 299).contains(response.statusCode),
                  let data, let html = String(data: data, encoding: .utf8),
                  let media = self.tikTokMedia(from: html), !media.isEmpty else {
                self.finish(.failure(BahogramMediaDownloadError.emptyResult), completion: completion)
                return
            }
            self.download(media, completion: completion)
        }
        self.add(task)
        task.resume()
    }

    private func tikTokMedia(from html: String) -> [BahogramRemoteMedia]? {
        guard let marker = html.range(of: "<script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\""),
              let openingEnd = html[marker.upperBound...].firstIndex(of: ">"),
              let closing = html[html.index(after: openingEnd)...].range(of: "</script>") else {
            return nil
        }
        let json = String(html[html.index(after: openingEnd)..<closing.lowerBound])
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scope = root["__DEFAULT_SCOPE__"] as? [String: Any],
              let detail = scope["webapp.video-detail"] as? [String: Any],
              let itemInfo = detail["itemInfo"] as? [String: Any],
              let item = itemInfo["itemStruct"] as? [String: Any] else {
            return nil
        }
        let postId = (item["id"] as? String) ?? "post"
        if let imagePost = item["imagePost"] as? [String: Any],
           let images = imagePost["images"] as? [[String: Any]], !images.isEmpty {
            let media = images.enumerated().compactMap { index, image -> BahogramRemoteMedia? in
                guard let imageURL = image["imageURL"] as? [String: Any],
                      let urls = imageURL["urlList"] as? [String],
                      let first = urls.first, let url = URL(string: first) else { return nil }
                return BahogramRemoteMedia(url: url, kind: .photo, filename: "tiktok-\(postId)-\(index + 1).jpg")
            }
            return media.count == images.count ? media : nil
        }
        guard let video = item["video"] as? [String: Any] else { return nil }
        let variants = (video["bitrateInfo"] as? [[String: Any]]) ?? []
        let ordered = variants.sorted { lhs, rhs in
            let lhsQuality = (lhs["Bitrate"] as? Int) ?? 0
            let rhsQuality = (rhs["Bitrate"] as? Int) ?? 0
            return lhsQuality > rhsQuality
        }
        for variant in ordered {
            guard (variant["CodecType"] as? String)?.lowercased() == "h264",
                  let address = variant["PlayAddr"] as? [String: Any],
                  let urls = address["UrlList"] as? [String],
                  let first = urls.first, let url = URL(string: first) else { continue }
            return [BahogramRemoteMedia(url: url, kind: .video, filename: "tiktok-\(postId).mp4")]
        }
        if let address = video["playAddr"] as? String, let url = URL(string: address) {
            return [BahogramRemoteMedia(url: url, kind: .video, filename: "tiktok-\(postId).mp4")]
        }
        return nil
    }

    private func startYouTube(completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let streams = try await YouTube(url: self.sourceURL, methods: [.local, .remote]).streams
                try Task.checkCancellation()
                let progressive = streams.filter { $0.isProgressive && $0.fileExtension == .mp4 && $0.isNativelyPlayable }
                    .max { ($0.videoResolution ?? 0) < ($1.videoResolution ?? 0) }
                let video = streams.filter { $0.includesVideoTrack && !$0.includesAudioTrack && $0.fileExtension == .mp4 && $0.isNativelyPlayable }
                    .max { ($0.videoResolution ?? 0) < ($1.videoResolution ?? 0) }
                let audio = streams.filter { $0.includesAudioTrack && !$0.includesVideoTrack && $0.fileExtension == .m4a && $0.isNativelyPlayable }
                    .max { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }
                let filename = "shorts-\(self.sourceURL.lastPathComponent).mp4"
                if let video, let audio, (video.videoResolution ?? 0) > (progressive?.videoResolution ?? 0) {
                    self.downloadYouTube(videoURL: video.url, audioURL: audio.url, filename: filename, completion: completion)
                } else if let progressive {
                    self.download([BahogramRemoteMedia(url: progressive.url, kind: .video, filename: filename)], completion: completion)
                } else if let video, let audio {
                    self.downloadYouTube(videoURL: video.url, audioURL: audio.url, filename: filename, completion: completion)
                } else {
                    self.finish(.failure(BahogramMediaDownloadError.noCompatibleVideo), completion: completion)
                }
            } catch {
                self.finish(.failure(error), completion: completion)
            }
        }
        self.lock.lock()
        self.extractionTask = task
        let cancelled = self.cancelled
        self.lock.unlock()
        if cancelled { task.cancel() }
    }

    private func downloadYouTube(videoURL: URL, audioURL: URL, filename: String, completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        let group = DispatchGroup()
        let resultLock = NSLock()
        var savedFiles: [URL?] = [nil, nil]
        var firstError: Error?
        for (index, url) in [videoURL, audioURL].enumerated() {
            group.enter()
            let task = self.session.downloadTask(with: url) { location, response, error in
                defer { group.leave() }
                resultLock.lock()
                defer { resultLock.unlock() }
                if let error {
                    if firstError == nil { firstError = error }
                    return
                }
                guard let response = response as? HTTPURLResponse, (200 ... 299).contains(response.statusCode), let location else {
                    if firstError == nil { firstError = BahogramMediaDownloadError.invalidResponse }
                    return
                }
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(index == 0 ? "mp4" : "m4a")
                do {
                    try FileManager.default.moveItem(at: location, to: destination)
                    savedFiles[index] = destination
                } catch {
                    if firstError == nil { firstError = error }
                }
            }
            self.add(task)
            task.resume()
        }
        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self else { return }
            let files = savedFiles.compactMap { $0 }
            if let firstError {
                files.forEach { try? FileManager.default.removeItem(at: $0) }
                self.finish(.failure(firstError), completion: completion)
                return
            }
            guard files.count == 2 else {
                files.forEach { try? FileManager.default.removeItem(at: $0) }
                self.finish(.failure(BahogramMediaDownloadError.emptyResult), completion: completion)
                return
            }
            self.mergeYouTube(videoFile: files[0], audioFile: files[1], filename: filename, completion: completion)
        }
    }

    private func mergeYouTube(videoFile: URL, audioFile: URL, filename: String, completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        let videoAsset = AVURLAsset(url: videoFile)
        let audioAsset = AVURLAsset(url: audioFile)
        let composition = AVMutableComposition()
        do {
            guard let sourceVideo = videoAsset.tracks(withMediaType: .video).first,
                  let sourceAudio = audioAsset.tracks(withMediaType: .audio).first,
                  let targetVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let targetAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw BahogramMediaDownloadError.noCompatibleVideo
            }
            try targetVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: sourceVideo, at: .zero)
            try targetAudio.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(audioAsset.duration, videoAsset.duration)), of: sourceAudio, at: .zero)
            targetVideo.preferredTransform = sourceVideo.preferredTransform
        } catch {
            [videoFile, audioFile].forEach { try? FileManager.default.removeItem(at: $0) }
            self.finish(.failure(error), completion: completion)
            return
        }
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            [videoFile, audioFile].forEach { try? FileManager.default.removeItem(at: $0) }
            self.finish(.failure(BahogramMediaDownloadError.noCompatibleVideo), completion: completion)
            return
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        exporter.outputURL = output
        exporter.outputFileType = .mp4
        exporter.exportAsynchronously { [weak self] in
            defer { [videoFile, audioFile, output].forEach { try? FileManager.default.removeItem(at: $0) } }
            guard let self else { return }
            if exporter.status == .completed, let data = try? Data(contentsOf: output) {
                self.finish(.success([BahogramDownloadedMedia(data: data, kind: .video, filename: filename, mimeType: "video/mp4")]), completion: completion)
            } else {
                self.finish(.failure(exporter.error ?? BahogramMediaDownloadError.invalidResponse), completion: completion)
            }
        }
    }

    private func download(_ remoteMedia: [BahogramRemoteMedia], completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        let group = DispatchGroup()
        let resultLock = NSLock()
        var results: [BahogramDownloadedMedia?] = Array(repeating: nil, count: remoteMedia.count)
        var firstError: Error?

        for (index, item) in remoteMedia.enumerated() {
            group.enter()
            var request = URLRequest(url: item.url)
            request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            if self.service == .tiktok {
                request.setValue("https://www.tiktok.com/", forHTTPHeaderField: "Referer")
            }
            let task = self.session.downloadTask(with: request) { location, response, error in
                defer { group.leave() }
                if let error {
                    resultLock.lock()
                    if firstError == nil { firstError = error }
                    resultLock.unlock()
                    return
                }
                guard let response = response as? HTTPURLResponse, (200 ... 299).contains(response.statusCode),
                      let location, let data = try? Data(contentsOf: location) else {
                    resultLock.lock()
                    if firstError == nil { firstError = BahogramMediaDownloadError.invalidResponse }
                    resultLock.unlock()
                    return
                }
                let mimeType = response.mimeType ?? self.mimeType(for: item.filename ?? item.url.lastPathComponent)
                let filename = item.filename ?? self.filename(for: item.url, mimeType: mimeType, index: index)
                resultLock.lock()
                results[index] = BahogramDownloadedMedia(data: data, kind: item.kind, filename: filename, mimeType: mimeType)
                resultLock.unlock()
            }
            self.add(task)
            task.resume()
        }

        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self else {
                return
            }
            if let firstError {
                self.finish(.failure(firstError), completion: completion)
                return
            }
            let media = results.compactMap { $0 }
            guard media.count == remoteMedia.count else {
                self.finish(.failure(BahogramMediaDownloadError.emptyResult), completion: completion)
                return
            }
            self.finish(.success(media), completion: completion)
        }
    }

    private func add(_ task: URLSessionTask) {
        self.lock.lock()
        self.tasks.append(task)
        let cancelled = self.cancelled
        self.lock.unlock()
        if cancelled {
            task.cancel()
        }
    }

    private func finish(_ result: Result<[BahogramDownloadedMedia], Error>, completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        self.lock.lock()
        let cancelled = self.cancelled
        self.tasks.removeAll()
        self.lock.unlock()
        DispatchQueue.main.async {
            if cancelled {
                completion(.failure(URLError(.cancelled)))
            } else {
                completion(result)
            }
        }
    }

    private func mimeType(for filename: String) -> String {
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        case "mov": return "video/quicktime"
        case "mp4", "m4v": return "video/mp4"
        default: return "application/octet-stream"
        }
    }

    private func filename(for url: URL, mimeType: String, index: Int) -> String {
        let lastPathComponent = url.lastPathComponent
        if !lastPathComponent.isEmpty, URL(fileURLWithPath: lastPathComponent).pathExtension.count > 0 {
            return lastPathComponent
        }
        let fileExtension: String
        switch mimeType {
        case "image/jpeg": fileExtension = "jpg"
        case "image/png": fileExtension = "png"
        case "image/webp": fileExtension = "webp"
        case "image/gif": fileExtension = "gif"
        case "video/quicktime": fileExtension = "mov"
        default: fileExtension = "mp4"
        }
        return "download-\(index + 1).\(fileExtension)"
    }
}
