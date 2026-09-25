import AVFoundation
import Foundation
import Observation
import Speech

/// On-device Mandarin recognition for one short answer at a time.
///
/// Uses `DictationTranscriber`, not `SpeechTranscriber`. The two look interchangeable and
/// are not: `SpeechTranscriber` is the long-form module and ignores contextual strings, so
/// hinting it at the expected word compiles and does nothing. `DictationTranscriber` is
/// the short-utterance module, takes `ContentHint.shortForm`, and honours the hints, which
/// is what lifts isolated-word accuracy from poor to usable.
@MainActor
@Observable
final class DictationRecogniser: SpeechRecognising {
    private(set) var availability: SpeechAvailability = .notPrepared
    private(set) var partialText = ""

    private let requestedLocale = Locale(identifier: "zh-CN")
    private var resolvedLocale: Locale?

    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?
    private var finalText = ""
    private var finalAlternatives: [String] = []
    private var isListening = false

    // MARK: - Preparation

    func prepare() async -> SpeechAvailability {
        // Locales have to be resolved through the framework and compared on BCP-47.
        // Constructing Locale(identifier: "zh_CN") by hand and comparing it to the
        // framework's own zh-CN silently fails to match.
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            availability = .unsupported(reason: "Mandarin dictation is not available on this device.")
            return availability
        }
        resolvedLocale = locale

        guard await requestMicrophoneAccess() else {
            availability = .needsPermission
            return availability
        }

        // The locale must be reserved before any module is built with it, whether or not
        // the model needs downloading. Skipping this on the already-installed path makes
        // the framework log "Cannot use modules with unallocated locales" for every
        // transcriber, and it says that becomes an error in a future release.
        guard await reserveLocale(locale) else {
            availability = .unsupported(reason: "Mandarin dictation could not be reserved on this device.")
            return availability
        }

        switch await AssetInventory.status(forModules: [Self.makeTranscriber(locale: locale)]) {
        case .installed:
            break
        case .supported, .downloading:
            availability = .downloadingModel(progress: 0)
            do {
                try await installModel(for: locale)
            } catch {
                availability = .unsupported(reason: "The Mandarin speech model could not be downloaded.")
                return availability
            }
        case .unsupported:
            availability = .unsupported(reason: "Mandarin dictation is not available on this device.")
            return availability
        @unknown default:
            availability = .unsupported(reason: "Mandarin dictation is not available on this device.")
            return availability
        }

        // Resolved now rather than on the first tap. This is the slow part of arming the
        // microphone, and doing it here means a card does not spend it while the user is
        // already talking.
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [Self.makeTranscriber(locale: locale)]
        )

        availability = .ready
        return availability
    }

    /// Reservations are a limited, app-wide resource. This app only ever wants Mandarin,
    /// so one is claimed and kept.
    private func reserveLocale(_ locale: Locale) async -> Bool {
        let reserved = await AssetInventory.reservedLocales
        if reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            return true
        }

        if reserved.count >= AssetInventory.maximumReservedLocales, let spare = reserved.first {
            _ = await AssetInventory.release(reservedLocale: spare)
        }

        return (try? await AssetInventory.reserve(locale: locale)) ?? false
    }

    /// One place to build the module, so the asset request and status check are asking
    /// about exactly what listening will use.
    private nonisolated static func makeTranscriber(locale: Locale) -> DictationTranscriber {
        DictationTranscriber(
            locale: locale,
            contentHints: [.shortForm],
            transcriptionOptions: [],
            // Alternatives have to be asked for. Without this option `result.alternatives`
            // is always empty, and grading them achieves nothing.
            reportingOptions: [.volatileResults, .alternativeTranscriptions],
            attributeOptions: []
        )
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    private func installModel(for locale: Locale) async throws {
        let module = Self.makeTranscriber(locale: locale)

        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
            return
        }

        let progress = request.progress
        let watcher = Task { @MainActor in
            while !Task.isCancelled && !progress.isFinished {
                availability = .downloadingModel(progress: progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer { watcher.cancel() }

        try await request.downloadAndInstall()
    }

    // MARK: - Listening

    func start(hints: [String]) async throws {
        guard !isListening, let locale = resolvedLocale else { return }

        partialText = ""
        finalText = ""
        finalAlternatives = []

        let transcriber = Self.makeTranscriber(locale: locale)
        self.transcriber = transcriber

        // This is the payoff for using the dictation module: the expected answer and its
        // pinyin bias recognition toward the word actually being asked for.
        let context = AnalysisContext()
        context.contextualStrings = [.general: hints.filter { !$0.isEmpty }]

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        let analyzer = SpeechAnalyzer(
            inputSequence: stream,
            modules: [transcriber],
            analysisContext: context
        )
        self.analyzer = analyzer

        if analyzerFormat == nil {
            analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber]
            )
        }

        resultsTask = Task { @MainActor [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self?.finalText = text
                        // The runner-up transcriptions are worth keeping: on an isolated
                        // word the right answer is often sitting in second place.
                        self?.finalAlternatives = result.alternatives.map {
                            String($0.characters)
                        }
                    } else {
                        self?.partialText = text
                    }
                }
            } catch {
                // A cancelled or torn-down stream is the normal way this ends.
            }
        }

        try startCapture()
        isListening = true
    }

    private func startCapture() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        if let analyzerFormat, analyzerFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        } else {
            converter = nil
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let converted = Self.convert(buffer, using: self.converter, to: self.analyzerFormat)
            self.inputContinuation?.yield(AnalyzerInput(buffer: converted))
        }

        engine.prepare()
        try engine.start()
    }

    /// The microphone hands back its own hardware format; the analyser wants its own.
    private nonisolated static func convert(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter?,
        to format: AVAudioFormat?
    ) -> AVAudioPCMBuffer {
        guard let converter, let format else { return buffer }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return buffer
        }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        return error == nil ? output : buffer
    }

    func stop() async -> SpeechOutcome {
        guard isListening else { return currentOutcome }
        isListening = false

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        inputContinuation?.finish()
        inputContinuation = nil

        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value

        resultsTask = nil
        analyzer = nil
        transcriber = nil
        converter = nil

        return currentOutcome
    }

    /// The final transcript when there is one, otherwise whatever the live one reached.
    private var currentOutcome: SpeechOutcome {
        SpeechOutcome(
            best: finalText.isEmpty ? partialText : finalText,
            alternatives: finalAlternatives
        )
    }

    func cancel() {
        guard isListening else { return }
        isListening = false

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil

        let analyzer = self.analyzer
        self.analyzer = nil
        transcriber = nil
        converter = nil
        partialText = ""
        finalText = ""
        finalAlternatives = []

        Task { await analyzer?.cancelAndFinishNow() }
    }
}
