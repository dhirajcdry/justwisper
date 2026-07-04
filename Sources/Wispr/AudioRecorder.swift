import AVFoundation
import CoreAudio

/// Captures microphone audio with AVCaptureSession (NOT AVAudioEngine) so it
/// never engages the audio *output* device — playback from Spotify etc. keeps
/// running untouched. Prefers the built-in mic so Bluetooth headphones don't drop
/// from hi-fi (A2DP) to call-quality (HFP) while recording.
final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    /// Called on the main thread with a normalized 0...1 mic level (~60 ms cadence).
    var onLevel: ((Float) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "ai.wispr.audio")

    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private var configured = false

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    /// The mic that will be used, for display/logging.
    private(set) var deviceName: String = "default"

    /// Session start/stop run here, never on the main thread — `startRunning()`
    /// and `stopRunning()` block (hundreds of ms cold), which otherwise stalls
    /// the flow bar appearing and makes the stop button feel unresponsive.
    private let sessionQueue = DispatchQueue(label: "ai.wispr.session")

    func start() throws {
        lock.withLock { samples.removeAll(keepingCapacity: true) }

        if !configured {
            try configure()          // one-time; must succeed before we run.
            configured = true
        }
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() -> [Float] {
        // Grab what we've captured right now, then tear the session down off the
        // main thread so the UI (and the ✓/✕ buttons) respond instantly.
        let captured = lock.withLock { samples }
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        return captured
    }

    /// A copy of everything captured so far — used for live streaming transcription
    /// while recording is still in progress.
    func snapshot() -> [Float] {
        lock.withLock { samples }
    }

    // MARK: - Setup

    private func configure() throws {
        guard let device = preferredInputDevice() else {
            throw NSError(domain: "Wispr", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone found"])
        }
        deviceName = device.localizedName

        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw NSError(domain: "Wispr", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add mic input"])
        }
        session.addInput(input)

        // Ask for non-interleaved 32-bit float so metering can read channel data.
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
    }

    /// True when the chosen mic is a Bluetooth device (playback may briefly drop).
    private(set) var usingBluetoothMic = false

    /// Choose a mic that won't disturb playback. Bluetooth mics force the device
    /// from A2DP (hi-fi) to HFP (call quality), stuttering whatever's playing, so
    /// we classify by CoreAudio transport type and avoid Bluetooth entirely unless
    /// it's the only microphone available.
    private func preferredInputDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let devices = discovery.devices
        guard !devices.isEmpty else { return AVCaptureDevice.default(for: .audio) }

        let transports = Self.transportTypesByUID()
        func transport(_ d: AVCaptureDevice) -> UInt32 { transports[d.uniqueID] ?? 0 }
        func isBluetooth(_ d: AVCaptureDevice) -> Bool {
            let t = transport(d)
            return t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE
        }

        let chosen: AVCaptureDevice? =
            // 1) The built-in mic — always the safest, never touches Bluetooth.
            devices.first(where: { transport($0) == kAudioDeviceTransportTypeBuiltIn })
            // 2) Any non-Bluetooth mic (USB, aggregate, virtual).
            ?? devices.first(where: { !isBluetooth($0) })
            // 3) Name fallback if the transport lookup came up empty.
            ?? devices.first(where: {
                let n = $0.localizedName.lowercased()
                return n.contains("built-in") || n.contains("macbook")
            })
            // 4) Last resort: whatever exists (may be Bluetooth → can interrupt).
            ?? devices.first

        usingBluetoothMic = chosen.map(isBluetooth) ?? false
        return chosen
    }

    /// Map each audio device's UID → CoreAudio transport type. AVCaptureDevice's
    /// `uniqueID` matches the CoreAudio device UID, letting us classify mics.
    private static func transportTypesByUID() -> [String: UInt32] {
        var result: [String: UInt32] = [:]
        let system = AudioObjectID(kAudioObjectSystemObject)

        var listAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &listAddr, 0, nil, &dataSize) == noErr else { return result }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return result }
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &listAddr, 0, nil, &dataSize, &ids) == noErr else { return result }

        for id in ids {
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, &uid) == noErr,
                  let uidString = uid?.takeRetainedValue() as String? else { continue }

            var transAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport: UInt32 = 0
            var transSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(id, &transAddr, 0, nil, &transSize, &transport) == noErr else { continue }

            result[uidString] = transport
        }
        return result
    }

    // MARK: - Sample handling

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else { return }

        var asbd = asbdPointer.pointee
        guard let inFormat = AVAudioFormat(streamDescription: &asbd) else { return }

        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0,
              let pcm = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: frames)
        else { return }
        pcm.frameLength = frames

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: pcm.mutableAudioBufferList
        )
        guard status == noErr else { return }

        meter(pcm)
        append(pcm, inFormat: inFormat)
    }

    private func meter(_ buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        guard frames > 0, let channel = buffer.floatChannelData else { return }
        let data = channel[0]
        var sum: Float = 0
        for i in 0..<frames { sum += data[i] * data[i] }
        let rms = (sum / Float(frames)).squareRoot()
        let level = min(1.0, (rms * 9).squareRoot())
        DispatchQueue.main.async { [weak self] in self?.onLevel?(level) }
    }

    private func append(_ buffer: AVAudioPCMBuffer, inFormat: AVAudioFormat) {
        if converter == nil || converter?.inputFormat != inFormat {
            converter = AVAudioConverter(from: inFormat, to: targetFormat)
        }
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / inFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil { return }

        let n = Int(out.frameLength)
        guard n > 0, let ch = out.floatChannelData else { return }
        let chunk = Array(UnsafeBufferPointer(start: ch[0], count: n))
        lock.withLock { samples.append(contentsOf: chunk) }
    }
}
