import SwiftUI
import AVFoundation
import ApplicationServices
import ServiceManagement

enum AppState: Equatable {
    case loading
    case idle
    case recording
    case transcribing
    case formatting
    case landed(String)   // transcript just pasted into the named app — brief ✓ confirmation
    case cancelled        // recording was cancelled — brief window to undo (recover the take)
    case preview          // showing the flow bar with sample words (picking a style)
    case notice(String)   // the flow bar explaining why dictation can't start right now
    case error(String)
}

struct Dictation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let text: String
    let date: Date
    let duration: Double
    var latency: Double = 0        // stop → text ready, seconds
    var appName: String? = nil     // where it landed, for insights
    var wordCount: Int { text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }
}

enum Screen: String, CaseIterable {
    case home, history, insights, dictionary, snippets, settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .insights: return "Insights"
        case .dictionary: return "Dictionary"
        case .snippets: return "Snippets"
        case .settings: return "Settings"
        }
    }

    var blurb: String {
        switch self {
        case .insights: return "Deeper analytics on your dictation — words over time, speed trends, and where you dictate most."
        case .dictionary: return "Teach Wisper your names, jargon, and custom spellings so transcription gets them right."
        case .snippets: return "Save phrases you say often and expand them into longer text on command."
        default: return "Coming soon."
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var state: AppState = .loading { didSet { syncOverlay() } }
    @Published var transcript: String = ""
    @Published var logLines: [String] = []
    @Published var autoPaste: Bool = true
    @Published var modelName: String = "base.en"
    @Published var accessibilityGranted: Bool = false
    @Published var micGranted: Bool = false

    // Live waveform: a rolling window of recent mic levels (0...1).
    static let waveformBars = 48
    @Published var levels: [Float] = Array(repeating: 0, count: waveformBars)
    @Published var level: Float = 0

    // History + stats — persisted locally (Application Support/Wispr), capped
    // so the file can't grow without bound. Nothing ever leaves this Mac.
    @Published var history: [Dictation] {
        didSet { Persist.save(Array(history.prefix(5000)), to: "history.json") }
    }
    var totalWords: Int { history.reduce(0) { $0 + $1.wordCount } }

    // Navigation + live recording clock.
    @Published var nav: Screen = .home
    @Published var elapsed: TimeInterval = 0
    private var clockTimer: Timer?

    // Model loading + live transcription.
    @Published var downloadProgress: Double?   // 0...1 while downloading, nil otherwise
    @Published var modelReady: Bool = false
    @Published var partialText: String = ""     // live words while speaking
    @Published var handsFree: Bool = false      // hands-free (double-tap) latch engaged
    private var streamTask: Task<Void, Never>?

    // MARK: - Formatting (the transform pipeline)
    @Published var aiFormatting: Bool { didSet { defaults.set(aiFormatting, forKey: "aiFormatting") } }
    @Published var removeFillers: Bool { didSet { defaults.set(removeFillers, forKey: "removeFillers") } }
    @Published var voiceCommands: Bool { didSet { defaults.set(voiceCommands, forKey: "voiceCommands") } }
    @Published var formatMode: FormatMode { didSet { defaults.set(formatMode.rawValue, forKey: "formatMode") } }
    @Published var soundCues: Bool { didSet { defaults.set(soundCues, forKey: "soundCues") } }
    @Published var aiStatus: AIFormatter.Availability = .notSupported

    // The overlay's look (Galley/Column/Ticker/Proof). syncOverlay() applies a
    // change live if the bar happens to be on screen.
    @Published var flowStyle: FlowBarStyle {
        didSet {
            defaults.set(flowStyle.rawValue, forKey: "flowStyle")
            syncOverlay()
        }
    }

    // Custom vocabulary + snippets (persisted to JSON).
    @Published var vocab: [VocabEntry] { didSet { Persist.save(vocab, to: "dictionary.json") } }
    @Published var snippets: [SnippetEntry] { didSet { Persist.save(snippets, to: "snippets.json") } }

    // Per-app pinned styles: a bundle ID pinned here beats the global Style
    // picker AND auto-resolution — "Slack is always Chat, Xcode is always Raw".
    @Published var appStyles: [AppStyleEntry] { didSet { Persist.save(appStyles, to: "appstyles.json") } }

    // Onboarding.
    @Published var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") } }

    private let aiFormatter = AIFormatter()
    private let defaults = UserDefaults.standard

    let availableModels = ModelCatalog.ids

    private let recorder = AudioRecorder()
    private let engine: WhisperEngine
    private let hotkey = HotkeyMonitor()
    private let overlay = OverlayController()
    private let focus = FocusTracker()
    private var hasStarted = false
    private var recordingStart = Date()
    // Held while recording so macOS App Nap can't throttle capture/UI mid-take.
    private var recordingActivity: NSObjectProtocol?

    init() {
        engine = WhisperEngine()
        let d = UserDefaults.standard
        // AI polish is slow and mostly redundant (Whisper already punctuates well),
        // so it's opt-in. One-time migration flips it off for anyone who had the
        // old default-on behavior; explicit choices after this are respected.
        if !d.bool(forKey: "formatDefaultsV2") {
            d.set(false, forKey: "aiFormatting")
            d.set(true, forKey: "formatDefaultsV2")
        }
        aiFormatting = d.object(forKey: "aiFormatting") as? Bool ?? false
        removeFillers = d.object(forKey: "removeFillers") as? Bool ?? true
        voiceCommands = d.object(forKey: "voiceCommands") as? Bool ?? true
        soundCues = d.object(forKey: "soundCues") as? Bool ?? true
        formatMode = FormatMode(rawValue: d.string(forKey: "formatMode") ?? "") ?? .auto
        flowStyle = FlowBarStyle(rawValue: d.string(forKey: "flowStyle") ?? "") ?? .galley
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        vocab = Persist.load([VocabEntry].self, from: "dictionary.json") ?? []
        snippets = Persist.load([SnippetEntry].self, from: "snippets.json") ?? []
        appStyles = Persist.load([AppStyleEntry].self, from: "appstyles.json") ?? []
        history = Persist.load([Dictation].self, from: "history.json") ?? []
        recorder.onLevel = { [weak self] value in self?.pushLevel(value) }
    }

    var glyph: String {
        switch state {
        case .loading: return "⏳"
        case .idle: return "🎙️"
        case .recording: return "🔴"
        case .transcribing: return "✍️"
        case .formatting: return "✨"
        case .landed: return "✅"
        case .cancelled: return "↩️"
        case .preview: return "🎙️"
        case .notice: return "⚠️"
        case .error: return "⚠️"
        }
    }

    /// The custom-drawn menu bar icon for the current state.
    var statusIcon: NSImage {
        switch state {
        case .recording: return StatusIcon.recording
        case .loading, .transcribing, .formatting: return StatusIcon.busy
        case .error: return StatusIcon.alert
        case .notice: return noticeCanRetry ? StatusIcon.alert : StatusIcon.busy
        case .idle, .landed, .cancelled, .preview: return StatusIcon.idle
        }
    }

    var statusText: String {
        switch state {
        case .loading:
            if let p = downloadProgress, p < 1 { return "Downloading \(Int(p * 100))%" }
            return "Loading model…"
        case .idle: return "Ready"
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .formatting: return "Polishing…"
        case .landed(let app): return "Landed in \(app) ✓"
        case .cancelled: return "Cancelled — undo?"
        case .preview: return "Overlay preview"
        case .notice(let message): return message
        case .error(let message): return "Error: \(message)"
        }
    }

    /// True during the brief post-cancel window where the take can be recovered.
    var isCancelled: Bool {
        if case .cancelled = state { return true }
        return false
    }

    /// Non-nil while the brief "landed" confirmation is showing on the flow bar.
    var landedAppName: String? {
        if case .landed(let name) = state { return name }
        return nil
    }

    /// Non-nil while the flow bar is explaining why dictation can't start.
    var noticeText: String? {
        if case .notice(let message) = state { return message }
        return nil
    }

    /// Label for the flow bar while it's working on your words.
    var busyLabel: String {
        switch state {
        case .formatting: return "POLISHING…"
        default: return "TRANSCRIBING…"
        }
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isBusy: Bool {
        switch state {
        case .transcribing, .formatting: return true
        default: return false
        }
    }

    var canRecord: Bool {
        state == .idle || isRecording || landedAppName != nil || state == .preview || isCancelled
    }

    var micName: String { recorder.deviceName }

    var recordingClock: String {
        let s = Int(elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Stats (for the Today card)

    var wordsToday: Int {
        history.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.wordCount }
    }

    var averageWPM: Int {
        let seconds = history.reduce(0.0) { $0 + $1.duration }
        guard seconds > 0 else { return 0 }
        return Int(Double(totalWords) / (seconds / 60.0))
    }

    /// Rough time saved vs typing at ~40 wpm, minus the time spent speaking.
    var timeSavedMinutes: Int {
        let typeMinutes = Double(totalWords) / 40.0
        let spokenMinutes = history.reduce(0.0) { $0 + $1.duration } / 60.0
        return max(0, Int(typeMinutes - spokenMinutes))
    }

    var timeSavedString: String {
        let m = timeSavedMinutes
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    var streakDays: Int {
        let cal = Calendar.current
        let days = Set(history.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while days.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    var wordsFraction: Double { min(1, Double(wordsToday) / 2000.0) }
    var wpmFraction: Double { min(1, Double(averageWPM) / 200.0) }
    var timeSavedFraction: Double { min(1, Double(timeSavedMinutes) / 240.0) }
    var streakFraction: Double { min(1, Double(streakDays) / 30.0) }

    // MARK: - Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refreshAccessibility(prompt: false)
        refreshMic()
        overlay.configure(model: self)
        focus.start()
        startPermissionWatch()
        Task { await refreshAIStatus() }

        hotkey.onStart = { [weak self] in self?.beginRecording() }
        hotkey.onStop = { [weak self] in self?.endRecording() }
        hotkey.onHandsFreeChange = { [weak self] on in
            self?.handsFree = on
            self?.log(on ? "Hands-free on — tap Right ⌥ to stop." : "Hands-free off.")
        }
        hotkey.onCancel = { [weak self] in self?.cancelRecording() }   // ESC
        hotkey.start()

        Task { await loadModel() }
    }

    private func loadModel() async {
        state = .loading
        modelReady = false
        let onDisk = engine.modelExistsOnDisk(modelName)
        downloadProgress = onDisk ? nil : 0
        let info = ModelCatalog.info(modelName)
        log(onDisk ? "Loading \"\(modelName)\"…" : "Downloading \"\(info.name)\" model (\(info.size))…")
        do {
            try await engine.prepare(model: modelName) { [weak self] p in
                Task { @MainActor in
                    guard let self else { return }
                    if p < 1 { self.downloadProgress = p }
                }
            }
            downloadProgress = nil
            modelReady = true
            state = .idle
            log("Model ready. Hold Right ⌥ to talk, or double-tap for hands-free.")
            // Warm the inference path in the background so the FIRST dictation
            // is as fast as every later one (first ANE pass is the slow one).
            Task { [engine] in await engine.warmUp() }
        } catch {
            downloadProgress = nil
            state = .error("model load failed")
            log("Model load FAILED: \(error)")
        }
    }

    func reloadModel(_ name: String) {
        guard name != modelName else { return }
        modelName = name
        Task { await loadModel() }
    }

    /// The flow bar's visibility is a pure function of state — shown whenever
    /// we're recording or processing, hidden otherwise. Called from state's
    /// didSet so it can never drift out of sync with what's actually happening.
    private func syncOverlay() {
        switch state {
        case .recording, .transcribing, .formatting, .landed, .cancelled, .preview, .notice:
            overlay.show()
        default:
            overlay.hide()
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording { endRecording() } else { beginRecording() }
    }

    func beginRecording() {
        // A new dictation can start right over the "landed ✓" confirmation
        // or an overlay preview.
        if landedAppName != nil { dismissLanded() }
        if isCancelled { discardCancelled() }
        if state == .preview { endPreview() }
        guard state == .idle else {
            hotkey.reset()
            explainWhyNotReady()   // never refuse silently — the bar says why
            log("Ignored record request (state: \(statusText)).")
            return
        }
        do {
            beginActivity()
            try recorder.start()
            recordingStart = Date()
            resetLevels()
            partialText = ""
            startClock()
            startStreaming()
            state = .recording            // didSet → overlay shows
            playCue(.start)
            if recorder.usingBluetoothMic {
                log("Recording… (mic: \(recorder.deviceName)) — Bluetooth mic in use; playback may dip briefly. Connect wired audio or use the built-in mic to avoid this.")
            } else {
                log("Recording… (mic: \(recorder.deviceName))")
            }
        } catch {
            endActivity()
            hotkey.reset()                // keep the key in sync after a failed start
            state = .error("microphone")
            log("Could not start microphone: \(error)")
        }
    }

    private func beginActivity() {
        guard recordingActivity == nil else { return }
        recordingActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "Wispr is recording dictation and must respond instantly."
        )
    }

    private func endActivity() {
        if let a = recordingActivity {
            ProcessInfo.processInfo.endActivity(a)
            recordingActivity = nil
        }
    }

    /// Stop and discard (the ✕ on the flow bar). Also dismisses the landed
    /// confirmation, so ESC always clears whatever the flow bar is showing.
    func cancelRecording() {
        if landedAppName != nil {
            dismissLanded()
            return
        }
        if isCancelled {                  // ✕/ESC on the cancelled bar → let it go
            discardCancelled()
            return
        }
        if state == .preview {
            endPreview()
            return
        }
        if noticeText != nil {
            dismissNotice()
            return
        }
        guard isRecording else { return }
        let samples = recorder.stop()
        endActivity()
        resetLevels()
        stopClock()
        stopStreaming()
        partialText = ""
        handsFree = false
        hotkey.reset()
        playCue(.cancel)

        // Hold the audio briefly so an accidental ESC / ✕ can be undone — the
        // words aren't gone, they're one click from being transcribed.
        let duration = Double(samples.count) / 16_000.0
        if samples.count > 16_000 / 4 {
            heldSamples = samples
            heldDuration = duration
            state = .cancelled            // didSet → overlay stays up with Undo
            armTransientDismiss(after: 5.0)
            log(String(format: "Cancelled — %.1fs held for undo.", duration))
        } else {
            heldSamples = []
            state = .idle
            log("Cancelled.")
        }
    }

    func endRecording() {
        if state == .preview { endPreview(); return }   // ✓ during a preview just closes it
        if noticeText != nil { dismissNotice(); return }
        guard isRecording else { return }
        let samples = recorder.stop()
        endActivity()
        stopClock()
        stopStreaming()
        handsFree = false
        hotkey.reset()
        let duration = Double(samples.count) / 16_000.0
        log(String(format: "Captured %.1fs of audio.", duration))
        resetLevels()

        guard samples.count > 16_000 / 4 else {
            partialText = ""
            state = .idle                 // didSet → overlay hides
            log("Too short — ignoring.")
            return
        }

        deliver(samples: samples, duration: duration)
    }

    /// Transcribe → format → paste a captured take, ending in `.landed`/idle.
    /// Shared by a normal stop and by "Undo" on a cancelled take.
    private func deliver(samples: [Float], duration: Double) {
        state = .transcribing
        let stopped = Date()              // release-to-text latency starts here
        Task {
            var landedIn: String?
            do {
                let result = try await engine.transcribe(samples, mode: .final)
                let raw = result.text
                if raw.isEmpty {
                    log("Whisper returned EMPTY text (silence or model issue?).")
                } else {
                    // Fast, deterministic formatting — always on, instant.
                    var text = cleanUp(raw)
                    let target = focus.lastExternalApp
                    // Optional AI rewrite only when the user turned it on.
                    if aiFormatting {
                        state = .formatting
                        let mode = resolvedMode(for: target)
                        if let polished = await aiFormatter.format(text, mode: mode), !polished.isEmpty {
                            text = polished
                            log("AI-polished (\(mode.label)).")
                        }
                    }
                    let latency = Date().timeIntervalSince(stopped)
                    transcript = text
                    history.insert(Dictation(text: text, date: Date(), duration: duration,
                                             latency: latency, appName: target?.localizedName), at: 0)
                    log(String(format: "Transcribed in %.1fs: \"%@\"", latency, text))
                    if autoPaste { landedIn = paste(text) }
                    playCue(.done)
                }
            } catch {
                log("Transcription FAILED: \(error)")
            }
            partialText = ""
            if let landedIn {
                showLanded(landedIn)      // brief ✓ on the flow bar, then idle
            } else {
                state = .idle             // didSet → overlay hides
            }
        }
    }

    // MARK: - Undo a cancel (recover the take)

    private var heldSamples: [Float] = []
    private var heldDuration: Double = 0

    /// Recover an accidentally-cancelled take: transcribe the audio we held.
    func undoCancel() {
        guard isCancelled, !heldSamples.isEmpty else { return }
        transientTimer?.cancel(); transientTimer = nil
        let samples = heldSamples
        let duration = heldDuration
        heldSamples = []
        log("Undo — recovering the cancelled take.")
        deliver(samples: samples, duration: duration)
    }

    /// Let the cancelled take go for good (timer elapsed, ✕, or a new take).
    private func discardCancelled() {
        transientTimer?.cancel(); transientTimer = nil
        heldSamples = []
        if isCancelled { state = .idle }
    }

    // MARK: - Notices (the bar explains itself instead of failing silently)

    private var noticeTimer: DispatchWorkItem?
    private var noticeReturn: AppState = .idle
    private(set) var noticeCanRetry = false

    /// Why can't dictation start right now? Put the reason on the flow bar —
    /// the hotkey must never appear to do nothing.
    private func explainWhyNotReady() {
        switch state {
        case .loading:
            if let p = downloadProgress {
                showNotice("Still downloading the speech model — \(Int(p * 100))%", returnTo: .loading)
            } else {
                showNotice("Loading the speech model — a few seconds…", returnTo: .loading)
            }
        case .error:
            showNotice("The speech model failed to load. Check your connection and retry.",
                       returnTo: state, retry: true)
        case .notice, .transcribing, .formatting:
            break   // the bar is already up, saying what's happening
        default:
            break
        }
    }

    private func showNotice(_ message: String, returnTo: AppState, retry: Bool = false) {
        noticeReturn = returnTo
        noticeCanRetry = retry
        state = .notice(message)          // didSet → overlay shows
        playCue(.cancel)
        noticeTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismissNotice() }
        noticeTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
    }

    func dismissNotice() {
        noticeTimer?.cancel()
        noticeTimer = nil
        guard case .notice = state else { return }
        state = noticeReturn
    }

    /// The RETRY button on a model-failure notice (and the menu bar item).
    func retryModelLoad() {
        noticeTimer?.cancel()
        noticeTimer = nil
        Task { await loadModel() }        // sets .loading → .idle/.error itself
    }

    // MARK: - Overlay preview (Settings ▸ Overlay — see the style before living with it)

    private var previewTask: Task<Void, Never>?

    /// Show the real flow bar where it actually lives, with sample words typing
    /// themselves out and a moving level meter. Ends on its own, or on ESC / ✕
    /// / ✓ / starting a real dictation.
    func previewFlowBar() {
        guard state == .idle || state == .preview else { return }
        previewTask?.cancel()
        partialText = ""
        elapsed = 0
        state = .preview                 // didSet → overlay shows (and resizes to the style)
        let words = "This is exactly how your words will set themselves while you speak"
            .split(separator: " ").map(String.init)
        previewTask = Task { @MainActor [weak self] in
            var tick = 0
            var shown = 0
            while let self, !Task.isCancelled, self.state == .preview, tick <= 58 {
                // Fake mic level so the waveform breathes like a live take.
                self.pushLevel(Float(0.18 + 0.55 * abs(sin(Double(tick) * 0.62)) * Double.random(in: 0.4...1)))
                self.elapsed = Double(tick) * 0.12
                if tick % 3 == 0, shown < words.count {
                    shown += 1
                    self.partialText = words.prefix(shown).joined(separator: " ")
                }
                tick += 1
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            self?.endPreview()
        }
    }

    private func endPreview() {
        previewTask?.cancel()
        previewTask = nil
        guard state == .preview else { return }
        partialText = ""
        resetLevels()
        elapsed = 0
        state = .idle                    // didSet → overlay hides
    }

    // MARK: - Transient bars (landed ✓ / cancelled ↩) — auto-dismiss, hover to keep

    private var transientTimer: DispatchWorkItem?
    private var barHovering = false

    /// True once the user hit "Copy" on the landed bar — flips it to the
    /// "⌘V to paste anywhere" hint.
    @Published var landedCopied = false

    private func showLanded(_ appName: String) {
        landedCopied = false
        state = .landed(appName)          // didSet → overlay stays up
        armTransientDismiss(after: 3.0)
    }

    /// Auto-dismiss a transient bar after a delay — unless the pointer is over
    /// it. Landed → idle; cancelled → discard the held take.
    private func armTransientDismiss(after seconds: Double) {
        transientTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.barHovering else { return }
            if self.landedAppName != nil { self.state = .idle }
            else if self.isCancelled { self.discardCancelled() }
        }
        transientTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func dismissLanded() {
        transientTimer?.cancel()
        transientTimer = nil
        landedCopied = false
        if landedAppName != nil { state = .idle }
    }

    /// Keep the bar up while the pointer is on it — nothing is more annoying than
    /// a bar vanishing as you reach for its button. Resume with a short grace on exit.
    func setBarHover(_ hovering: Bool) {
        barHovering = hovering
        guard landedAppName != nil || isCancelled else { return }
        if hovering {
            transientTimer?.cancel()
            transientTimer = nil
        } else {
            armTransientDismiss(after: 2.0)
        }
    }

    /// Put the transcript back on the clipboard so the user can paste it (⌘V)
    /// wherever they actually want it — reliable everywhere, unlike a synthetic
    /// ⌘Z which most apps (and web fields in Arc etc.) ignore. The text also
    /// lives in History, so it's never lost.
    func copyLastTranscript() {
        guard let last = lastInsertion else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(last.text, forType: .string)
        landedCopied = true
        if !barHovering { armTransientDismiss(after: 4.0) }  // read the hint; hover keeps it
        log("Copied to clipboard — ⌘V to paste anywhere.")
    }

    // MARK: - Formatting pipeline

    /// Fast, deterministic formatting: voice commands, filler & stutter removal,
    /// snippets, dictionary, casing and spacing. Instant — no model involved.
    private func cleanUp(_ raw: String) -> String {
        TextFormatter(
            removeFillers: removeFillers,
            voiceCommands: voiceCommands,
            dictionary: vocab,
            snippets: snippets
        ).process(raw)
    }

    func refreshAIStatus() async {
        let status = await aiFormatter.availability
        aiStatus = status
        if status != .ready, aiFormatting {
            log("AI reformat: \(status.blurb)")
        }
    }

    /// The app + text of the most recent insertion, for undo.
    private var lastInsertion: (app: NSRunningApplication?, text: String)?

    /// Insert into the focused app. Returns the app's name on success (drives
    /// the "Landed in <app> ✓" confirmation), nil if the paste couldn't happen.
    private func paste(_ text: String) -> String? {
        refreshAccessibility(prompt: false)
        if !accessibilityGranted {
            log("Skipped paste — Accessibility not granted. Enable Wisper in System Settings ▸ Privacy & Security ▸ Accessibility.")
            return nil
        }
        let target = focus.lastExternalApp
        let ok = TextInjector.insert(text, into: target)
        if ok {
            lastInsertion = (target, text)
            let name = target?.localizedName ?? "the focused app"
            log("Pasted into \(name).")
            return name
        } else {
            log("Paste blocked — Accessibility permission missing.")
            return nil
        }
    }

    /// Which style applies right now: a per-app pin wins, then the global Style
    /// picker, and Auto falls back to resolving from the app's bundle ID.
    func resolvedMode(for app: NSRunningApplication?) -> FormatMode {
        if let id = app?.bundleIdentifier,
           let pinned = appStyles.first(where: { $0.bundleID == id }) {
            return pinned.mode
        }
        return formatMode == .auto ? FormatMode.resolve(for: app) : formatMode
    }

    /// Re-insert an existing transcript into the last focused app.
    func reinsert(_ text: String) {
        refreshAccessibility(prompt: false)
        guard accessibilityGranted else {
            refreshAccessibility(prompt: true)
            log("Grant Accessibility to insert into other apps.")
            return
        }
        _ = TextInjector.insert(text, into: focus.lastExternalApp)
        log("Re-inserted into \(focus.lastExternalApp?.localizedName ?? "the focused app").")
    }

    // MARK: - Clock

    private func startClock() {
        elapsed = 0
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = Date().timeIntervalSince(self.recordingStart)
            }
        }
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    // MARK: - Live streaming transcription

    /// While recording, periodically transcribe the audio captured so far so words
    /// appear live. A higher-quality final pass runs in endRecording().
    private func startStreaming() {
        streamTask?.cancel()
        streamTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled, self.isRecording else { break }
                let samples = self.recorder.snapshot()
                guard samples.count > 16_000 / 2 else { continue }
                if let result = try? await self.engine.transcribe(samples, mode: .streaming),
                   !Task.isCancelled, self.isRecording, !result.text.isEmpty {
                    self.partialText = result.text
                }
            }
        }
    }

    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        // Task.cancel() can't reach a decode that's already inside WhisperKit —
        // and the final pass queues behind it on the engine actor. Abort it so
        // release-to-text latency isn't paying for a doomed partial pass.
        engine.abortStreaming()
    }

    // MARK: - Waveform

    private func pushLevel(_ value: Float) {
        level = value
        var next = levels
        next.removeFirst()
        next.append(value)
        levels = next
    }

    private func resetLevels() {
        level = 0
        levels = Array(repeating: 0, count: Self.waveformBars)
    }

    // MARK: - Permissions

    func refreshAccessibility(prompt: Bool) {
        if prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        } else {
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    func refreshMic() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Trigger the system microphone prompt (first run / onboarding).
    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in self?.micGranted = granted }
        }
    }

    /// Poll Accessibility + mic trust so the badges update the instant they're
    /// granted (or revoked) without needing to relaunch.
    private var permTimer: Timer?
    private func startPermissionWatch() {
        permTimer?.invalidate()
        permTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if trusted != self.accessibilityGranted {
                    self.accessibilityGranted = trusted
                    self.log(trusted ? "Accessibility granted ✓ — paste enabled." : "Accessibility revoked.")
                }
                self.refreshMic()
            }
        }
    }

    // MARK: - Sound cues

    private enum Cue { case start, done, cancel }

    private func playCue(_ cue: Cue) {
        guard soundCues else { return }
        let name: String
        switch cue {
        case .start: name = "Tink"
        case .done: name = "Pop"
        case .cancel: name = "Bottle"
        }
        NSSound(named: name)?.play()
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    func setLaunchAtLogin(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            log(on ? "Launch at login enabled." : "Launch at login disabled.")
        } catch {
            log("Launch-at-login change failed: \(error.localizedDescription)")
        }
        objectWillChange.send()
    }

    // MARK: - Onboarding

    func finishOnboarding() {
        hasOnboarded = true
    }

    /// Erase all locally stored dictations (history.json). Irreversible.
    func clearHistory() {
        history.removeAll()
        log("History erased — all stored dictations deleted from this Mac.")
    }

    // MARK: - Overlay position (drag the flow bar anywhere)

    func overlayDragStep() { overlay.dragStep() }
    func endOverlayDrag() {
        overlay.commitDrag()
        objectWillChange.send()   // refresh the Reset button in Settings
    }
    func resetOverlayPosition() {
        overlay.resetPosition()
        objectWillChange.send()
    }
    var hasCustomOverlayPosition: Bool { overlay.hasCustomPosition }

    func copyTranscript(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        log("Copied to clipboard.")
    }

    // MARK: - Log

    func log(_ message: String) {
        NSLog("Wispr: \(message)")
        logLines.append(message)
        if logLines.count > 200 { logLines.removeFirst(logLines.count - 200) }
    }
}
