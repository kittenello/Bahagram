import Foundation
import SwiftSignalKit
import Speech
import ConvertOpusToAAC

public struct LocallyTranscribedAudio {
    public var text: String
    public var isFinal: Bool
}

public enum LocalAudioTranscriptionError: Error {
    /// Speech recognition is denied or restricted for the app.
    case notAuthorized
    /// Apple has no speech recognizer for the app or the system language.
    case unsupportedLanguage
    /// A recognizer exists but can't run right now, e.g. it needs the network for this language.
    case unavailable
    /// Decoding the audio or recognizing speech failed, or no speech was recognized.
    case failed

    /// The text shown to the user (the Bahogram UI is Russian-only).
    public var bahogramText: String {
        switch self {
        case .notAuthorized:
            return "Нет доступа к распознаванию речи. Разрешите его в настройках iOS."
        case .unsupportedLanguage:
            return "Apple не распознаёт речь на языке приложения и системы."
        case .unavailable:
            return "Распознавание речи Apple сейчас недоступно. Проверьте интернет и включена ли диктовка в настройках клавиатуры."
        case .failed:
            return "Не удалось распознать речь."
        }
    }
}

private struct TranscriptionResult {
    var text: String
    var confidence: Float
    var isFinal: Bool
}

// Only accessed on the main queue.
private var sharedRecognizers: [String: SFSpeechRecognizer] = [:]

private func requestSpeechAuthorization() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        SFSpeechRecognizer.requestAuthorization { status in
            Queue.mainQueue().async {
                subscriber.putNext(status == .authorized)
                subscriber.putCompletion()
            }
        }
        return EmptyDisposable
    }
}

// Splits "ru_RU", "en-US", "pt-br" or "zh-Hant" into a lowercased language and an uppercased region, if there is one.
// "@" keywords are dropped, and a Chinese script stands in for its usual region.
private func languageAndRegion(_ identifier: String) -> (language: String, region: String?) {
    let base = identifier.split(separator: "@").first.map(String.init) ?? identifier
    let parts = base.split(whereSeparator: { $0 == "_" || $0 == "-" }).map(String.init)
    let language = parts.first?.lowercased() ?? ""
    var region = parts.dropFirst().first(where: { $0.count == 2 || ($0.count == 3 && Int($0) != nil) })?.uppercased()
    if region == nil, language == "zh", let script = parts.dropFirst().first(where: { $0.count == 4 })?.lowercased() {
        region = script == "hant" ? "TW" : "CN"
    }
    return (language, region)
}

// Recognizer locales to try: the app language first, then the system one. Each language is mapped to a supported
// locale, preferring its own region (the app's pt-br), then the system region, then the language's region (ru-RU), then US.
private func recognizerLocaleIdentifiers(appLocale: String) -> [String] {
    let supported = SFSpeechRecognizer.supportedLocales().map { $0.identifier }.sorted()
    let app = languageAndRegion(appLocale)
    let system = languageAndRegion(Locale.current.identifier)
    var result: [String] = []
    for (language, region) in [(app.language, app.region ?? system.region), (system.language, system.region)] where !language.isEmpty {
        let matches = supported.filter { languageAndRegion($0).language == language }
        let preferredRegions = [region, language.uppercased(), "US"].compactMap { $0 }
        var identifier: String?
        for region in preferredRegions {
            if let match = matches.first(where: { languageAndRegion($0).region == region }) {
                identifier = match
                break
            }
        }
        if let identifier = identifier ?? matches.first, !result.contains(identifier) {
            result.append(identifier)
        }
    }
    return result
}

private func speechRecognizer(localeIdentifier: String) -> SFSpeechRecognizer? {
    if let recognizer = sharedRecognizers[localeIdentifier] {
        return recognizer
    }
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
        return nil
    }
    recognizer.defaultTaskHint = .dictation
    sharedRecognizers[localeIdentifier] = recognizer
    return recognizer
}

private func recognizeSpeech(path: String, recognizer: SFSpeechRecognizer) -> Signal<TranscriptionResult?, NoError> {
    return Signal { subscriber in
        let tempFilePath = NSTemporaryDirectory() + "/\(UInt64.random(in: 0 ... UInt64.max)).m4a"
        let _ = try? FileManager.default.copyItem(atPath: path, toPath: tempFilePath)

        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: tempFilePath))
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        // On device when iOS has a model for this language, otherwise on Apple's servers.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        let task = recognizer.recognitionTask(with: request, resultHandler: { result, error in
            if let result = result {
                let segments = result.bestTranscription.segments
                var confidence: Float = 0.0
                for segment in segments {
                    confidence += segment.confidence
                }
                if !segments.isEmpty {
                    confidence /= Float(segments.count)
                }
                subscriber.putNext(TranscriptionResult(text: result.bestTranscription.formattedString, confidence: confidence, isFinal: result.isFinal))

                if result.isFinal {
                    subscriber.putCompletion()
                }
            } else {
                print("transcribeAudio: locale: \(recognizer.locale.identifier), error: \(String(describing: error))")

                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        })

        return ActionDisposable {
            task.cancel()
            let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
        }
    }
    |> runOn(.mainQueue())
}

/// Recognizes speech in an AAC (m4a) file. Tries the app and the system language and keeps the most confident result.
private func transcribeAudio(path: String, appLocale: String) -> Signal<Swift.Result<LocallyTranscribedAudio, LocalAudioTranscriptionError>, NoError> {
    return requestSpeechAuthorization()
    |> mapToSignal { isAuthorized -> Signal<Swift.Result<LocallyTranscribedAudio, LocalAudioTranscriptionError>, NoError> in
        if !isAuthorized {
            return .single(.failure(.notAuthorized))
        }
        let recognizers = recognizerLocaleIdentifiers(appLocale: appLocale).compactMap(speechRecognizer(localeIdentifier:))
        if recognizers.isEmpty {
            return .single(.failure(.unsupportedLanguage))
        }
        let availableRecognizers = recognizers.filter { $0.isAvailable }
        if availableRecognizers.isEmpty {
            return .single(.failure(.unavailable))
        }

        var results: Signal<[TranscriptionResult], NoError> = .single([])
        for recognizer in availableRecognizers {
            results = results
            |> mapToSignal { current -> Signal<[TranscriptionResult], NoError> in
                return recognizeSpeech(path: path, recognizer: recognizer)
                |> map { result -> [TranscriptionResult] in
                    if let result = result {
                        return current + [result]
                    } else {
                        return current
                    }
                }
            }
        }

        return results
        |> map { results -> Swift.Result<LocallyTranscribedAudio, LocalAudioTranscriptionError> in
            guard let best = results.filter({ !$0.text.isEmpty }).max(by: { $0.confidence < $1.confidence }) else {
                return .failure(.failed)
            }
            return .success(LocallyTranscribedAudio(text: best.text, isFinal: best.isFinal))
        }
    }
    |> runOn(.mainQueue())
}

/// Recognizes speech in a voice message (Opus) or round video (MP4) file: its audio track is decoded to AAC first.
public func transcribeMediaFile(path: String, appLocale: String, allocateTempFile: @escaping () -> String) -> Signal<Swift.Result<LocallyTranscribedAudio, LocalAudioTranscriptionError>, NoError> {
    return convertOpusToAAC(sourcePath: path, allocateTempFile: allocateTempFile)
    |> mapToSignal { convertedPath -> Signal<Swift.Result<LocallyTranscribedAudio, LocalAudioTranscriptionError>, NoError> in
        guard let convertedPath = convertedPath else {
            return .single(.failure(.failed))
        }
        return transcribeAudio(path: convertedPath, appLocale: appLocale)
    }
}
