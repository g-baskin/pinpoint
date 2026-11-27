import AppKit
import SwiftUI
import ZoomiesCore

/// "Add more context?" — appears next to new markup. Type right away, say "yes" and talk, or hold ⌥ / the mic to talk.
struct NotePromptView: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var speech = SpeechDictation.shared
    let annotationID: UUID
    let autoListen: Bool
    let close: () -> Void

    @State private var text = ""
    @State private var baseText = ""          // text before the current dictation session
    @State private var dictated = ""          // what the current session produced
    @State private var flagsMonitor: Any?
    @State private var optionHeld = false
    @State private var holdStart: Date?
    @State private var external: ExternalDictation?
    @State private var answered = false        // the first spoken/typed burst was checked for "yes"/"no"
    @FocusState private var focused: Bool

    private var annotation: Annotation? { model.annotations.first { $0.id == annotationID } }
    private var isPin: Bool { annotation?.kind == .note }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble").foregroundStyle(.secondary)
                Text(isPin ? "What's this note about?" : "Add more context?").font(.headline)
                Spacer()
                if speech.isListening {
                    LevelMeter(level: speech.level)
                    Text("Listening…").font(.caption).foregroundStyle(.red)
                }
            }
            TextField(isPin ? "Type or speak your note" : "Type here, or say “yes” and keep talking", text: $text, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
                .onChange(of: text) { old, new in
                    // Typing while dictating takes over from the mic.
                    if speech.isListening && new != baseText + dictated { speech.stop(); return }
                    // A dictation app (Wispr Flow…) pastes a whole phrase at once: treat a leading "yes" / a lone "no" as the answer.
                    if !speech.isListening && !answered && old.isEmpty && new.count >= 2 {
                        answered = true
                        handleAnswer(new)
                    }
                }
                .frame(width: 340)
            if let err = speech.lastError {
                Text(err).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true).frame(width: 340, alignment: .leading)
            }
            HStack(spacing: 8) {
                micButton
                Text(external.map { $0.hint + " · or the mic for built-in" } ?? "Hold ⌥ or the mic to talk")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Skip", action: skip).keyboardShortcut(.cancelAction)
                Button("Save", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .onAppear {
            text = annotation?.note ?? ""
            baseText = text
            answered = !text.isEmpty
            external = AppSettings.shared.activeExternalDictation
            // Keep the note box focused so a dictation app can type straight into it.
            focused = true
            DispatchQueue.main.async { focused = true }
            if external == nil {
                installOptionKeyPushToTalk()
                if autoListen && text.isEmpty { startDictation(stopAfterSilence: 2.2, autoAnswer: true) }
            } else if external?.usesOption == false {
                installOptionKeyPushToTalk()
            }
        }
        .onDisappear {
            if let m = flagsMonitor { NSEvent.removeMonitor(m) }
            speech.stop()
        }
    }

    private var micButton: some View {
        Image(systemName: speech.isListening ? "mic.fill" : "mic")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(speech.isListening ? .white : .primary)
            .frame(width: 30, height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(speech.isListening ? Color.red : Color.gray.opacity(0.2)))
            .help("Hold to talk, or click to start/stop")
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard holdStart == nil else { return }
                    holdStart = Date()
                    if !speech.isListening { startDictation(stopAfterSilence: nil, autoAnswer: false) }
                }
                .onEnded { _ in
                    let held = Date().timeIntervalSince(holdStart ?? Date())
                    holdStart = nil
                    // A quick click toggles hands-free mode (stops on a pause); a long press is push-to-talk.
                    if held > 0.35 { speech.stop() } else if speech.isListening && held <= 0.35 && !dictated.isEmpty { speech.stop() }
                })
    }

    private func installOptionKeyPushToTalk() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { e in
            let down = e.modifierFlags.contains(.option)
            if down && !optionHeld { optionHeld = true; startDictation(stopAfterSilence: nil, autoAnswer: false) }
            else if !down && optionHeld { optionHeld = false; speech.stop() }
            return e
        }
    }

    /// `autoAnswer`: the prompt just opened; a leading "yes" is dropped and "no"/"skip" dismisses it.
    private func startDictation(stopAfterSilence: TimeInterval?, autoAnswer: Bool) {
        baseText = text.isEmpty ? "" : text + (text.hasSuffix(" ") ? "" : " ")
        dictated = ""
        Task {
            await speech.start(stopAfterSilence: stopAfterSilence) { raw, isFinal in
                var t = raw
                if autoAnswer {
                    let lower = t.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                    if ["no", "nope", "skip", "cancel", "no thanks", "never mind"].contains(lower) {
                        if isFinal || lower.count >= 2 { speech.stop(); skip(); return }
                    }
                    if let r = t.range(of: #"^\s*(yes|yeah|yep|sure|ok|okay)\b[\s,.!]*"#, options: [.regularExpression, .caseInsensitive]) {
                        t.removeSubrange(r)
                        if let first = t.first { t.replaceSubrange(t.startIndex...t.startIndex, with: String(first).uppercased()) }
                    }
                }
                dictated = t
                text = baseText + t
            }
        }
    }

    /// "no"/"skip" dismisses; a leading "yes," is dropped.
    private func handleAnswer(_ phrase: String) {
        let lower = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if ["no", "nope", "skip", "cancel", "no thanks", "never mind"].contains(lower) { text = ""; skip(); return }
        if let r = phrase.range(of: #"^\s*(yes|yeah|yep|sure|ok|okay)\b[\s,.!]*"#, options: [.regularExpression, .caseInsensitive]) {
            var t = phrase; t.removeSubrange(r)
            if let first = t.first { t.replaceSubrange(t.startIndex...t.startIndex, with: String(first).uppercased()) }
            text = t
        }
    }

    private func save() {
        speech.stop()
        model.setNote(annotationID, text)
        close()
    }

    private func skip() {
        speech.stop()
        // An empty pin is pointless: remove it. Other markup stays, just without a note.
        if isPin && (annotation?.note ?? "").isEmpty { model.removeAnnotation(annotationID) }
        close()
    }
}

struct LevelMeter: View {
    let level: Float
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Float(i) / 5 < level ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(5 + i * 2))
            }
        }
    }
}
