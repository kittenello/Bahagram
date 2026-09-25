import Foundation

enum BahogramMediaDownloadService {
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
    case invalidEndpoint
    case invalidResponse
    case server(String)
    case unsupportedResponse
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Укажите корректный HTTPS-адрес своего сервера Cobalt в настройках «Чаты» → «Скачивание»."
        case .invalidResponse:
            return "Сервер Cobalt вернул некорректный ответ."
        case let .server(code):
            return "Ошибка Cobalt: \(code)"
        case .unsupportedResponse:
            return "Сервер запросил локальную обработку, которую этот способ отправки не поддерживает."
        case .emptyResult:
            return "Cobalt не вернул ни одного файла."
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

private struct BahogramCobaltResponse: Decodable {
    struct PickerItem: Decodable {
        let type: String
        let url: URL
    }

    struct ServerError: Decodable {
        let code: String
    }

    let status: String
    let url: URL?
    let filename: String?
    let picker: [PickerItem]?
    let error: ServerError?
}

private struct BahogramCobaltRequest: Encodable {
    let url: String
    let videoQuality = "max"
    let filenameStyle = "basic"
    let downloadMode = "auto"
    let youtubeVideoCodec = "h264"
    let youtubeVideoContainer = "mp4"
    let youtubeBetterAudio = true
    let allowH265 = false
}

private struct BahogramRemoteMedia {
    let url: URL
    let kind: BahogramDownloadedMediaKind
    let filename: String?
}

final class BahogramMediaDownloader {
    private let endpoint: String
    private let sourceURL: URL
    private let session: URLSession
    private let lock = NSLock()
    private var tasks: [URLSessionTask] = []
    private var cancelled = false

    init(endpoint: String, sourceURL: URL) {
        self.endpoint = endpoint
        self.sourceURL = sourceURL
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
        self.lock.unlock()
        for task in tasks {
            task.cancel()
        }
    }

    func start(completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        guard var components = URLComponents(string: self.endpoint), components.scheme?.lowercased() == "https", components.host != nil else {
            completion(.failure(BahogramMediaDownloadError.invalidEndpoint))
            return
        }
        components.query = nil
        components.fragment = nil
        guard let endpointURL = components.url else {
            completion(.failure(BahogramMediaDownloadError.invalidEndpoint))
            return
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(BahogramCobaltRequest(url: self.sourceURL.absoluteString))

        let task = self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }
            if let error {
                self.finish(.failure(error), completion: completion)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode), let data,
                  let cobaltResponse = try? JSONDecoder().decode(BahogramCobaltResponse.self, from: data) else {
                self.finish(.failure(BahogramMediaDownloadError.invalidResponse), completion: completion)
                return
            }

            let remoteMedia: [BahogramRemoteMedia]
            switch cobaltResponse.status {
            case "tunnel", "redirect":
                guard let url = cobaltResponse.url else {
                    self.finish(.failure(BahogramMediaDownloadError.invalidResponse), completion: completion)
                    return
                }
                remoteMedia = [BahogramRemoteMedia(url: url, kind: .unknown, filename: cobaltResponse.filename)]
            case "picker":
                remoteMedia = (cobaltResponse.picker ?? []).map { item in
                    let kind: BahogramDownloadedMediaKind
                    switch item.type {
                    case "photo": kind = .photo
                    case "video": kind = .video
                    case "gif": kind = .gif
                    default: kind = .unknown
                    }
                    return BahogramRemoteMedia(url: item.url, kind: kind, filename: nil)
                }
            case "local-processing":
                self.finish(.failure(BahogramMediaDownloadError.unsupportedResponse), completion: completion)
                return
            case "error":
                self.finish(.failure(BahogramMediaDownloadError.server(cobaltResponse.error?.code ?? "unknown")), completion: completion)
                return
            default:
                self.finish(.failure(BahogramMediaDownloadError.invalidResponse), completion: completion)
                return
            }

            guard !remoteMedia.isEmpty else {
                self.finish(.failure(BahogramMediaDownloadError.emptyResult), completion: completion)
                return
            }
            self.download(remoteMedia, completion: completion)
        }
        self.add(task)
        task.resume()
    }

    private func download(_ remoteMedia: [BahogramRemoteMedia], completion: @escaping (Result<[BahogramDownloadedMedia], Error>) -> Void) {
        let group = DispatchGroup()
        let resultLock = NSLock()
        var results: [BahogramDownloadedMedia?] = Array(repeating: nil, count: remoteMedia.count)
        var firstError: Error?

        for (index, item) in remoteMedia.enumerated() {
            group.enter()
            let task = self.session.downloadTask(with: item.url) { location, response, error in
                defer { group.leave() }
                if let error {
                    resultLock.lock()
                    if firstError == nil { firstError = error }
                    resultLock.unlock()
                    return
                }
                guard let location, let data = try? Data(contentsOf: location) else {
                    resultLock.lock()
                    if firstError == nil { firstError = BahogramMediaDownloadError.invalidResponse }
                    resultLock.unlock()
                    return
                }
                let httpResponse = response as? HTTPURLResponse
                let mimeType = httpResponse?.mimeType ?? self.mimeType(for: item.filename ?? item.url.lastPathComponent)
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
