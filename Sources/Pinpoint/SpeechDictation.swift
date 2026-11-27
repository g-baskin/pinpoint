import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import Speech

/// On-device speech-to-text (Apple Speech framework). Used for voice notes.
@MainActor
final class SpeechDictation: ObservableObject {
    static let shared = SpeechDictation()

    @Published private(set) var isListening = false
    @Published private(set) var level: Float = 0      // 0...1 mic level for the meter
    @Published var lastError: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var onUpdate: ((String, Bool) -> Void)?
    private var silenceWork: DispatchWorkItem?
    private var silenceAfter: TimeInterval?
    private var startedAt = Date()
    private var heardSomething = false

    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Asks for microphone + speech recognition access (macOS shows each prompt once).
    func authorize() async -> Bool {
        let speech: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speech else { lastError = "Speech recognition is off for Pinpoint (System Settings → Privacy & Security → Speech Recognition)."; return false }
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard mic else { lastError = "Microphone access is off for Pinpoint (System Settings → Privacy & Security → Microphone)."; return false }
        return true
    }

    /// Starts listening. `onUpdate(text, isFinal)` receives the running transcript of this session.
    /// `stopAfterSilence`: stop automatically once speech pauses this long (nil = until stop()).
    func start(stopAfterSilence: TimeInterval? = nil, onUpdate: @escaping (String, Bool) -> Void) async {
        if isListening { stop() }
        lastError = nil
        guard await authorize() else { return }
        guard let recognizer, recognizer.isAvailable else { lastError = "Speech recognition isn't available right now."; return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }   // stays on this Mac
        request = req
        self.onUpdate = onUpdate
        silenceAfter = stopAfterSilence
        heardSomething = false
        startedAt = Date()

        let input = engine.inputNode
        // Use the microphone chosen in Settings (default: the system input).
        let uid = AppSettings.shared.micUID
        if !uid.isEmpty, let dev = AudioInputs.device(uid: uid), let au = input.audioUnit {
            var id = dev.id
            AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { lastError = "No microphone found."; return }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            req.append(buffer)
            let level = Self.rms(buffer)
            Task { @MainActor in self?.level = level }
        }
        engine.prepare()
        do { try engine.start() } catch { lastError = "Couldn't start the microphone: \(error.localizedDescription)"; cleanup(); return }
        isListening = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty { self.heardSomething = true }
                    self.onUpdate?(text, result.isFinal)
                    self.armSilenceTimer()
                    if result.isFinal { self.cleanup() }
                }
                if error != nil && self.isListening { self.cleanup() }
            }
        }
        // If nothing is said at all, give up after a while.
        if stopAfterSilence != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in
                guard let self, self.isListening, !self.heardSomething else { return }
                self.stop()
            }
        }
    }

    private func armSilenceTimer() {
        guard let after = silenceAfter else { return }
        silenceWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.stop() }
        silenceWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: w)
    }

    /// Stops listening; the recognizer delivers a final result through onUpdate.
    func stop() {
        guard isListening else { return }
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isListening = false
        level = 0
        silenceWork?.cancel()
        // Let the final result arrive, then tear down.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.task?.finish(); self?.task = nil }
    }

    private func cleanup() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request = nil
        task = nil
        isListening = false
        level = 0
        silenceWork?.cancel()
    }

    nonisolated static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let ch = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        return min(1, sqrt(sum / Float(n)) * 12)
    }
}
