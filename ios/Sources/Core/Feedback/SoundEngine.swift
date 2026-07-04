import AVFoundation

/// Plays feedback cues. Sampled cues (chess/checkers/go pieces, 2048 tiles) play
/// bundled CC0 `.wav` files; everything else is synthesized. Both paths share the
/// `.ambient` session so they respect the silent switch and mix with music.
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let synthNodes: [AVAudioPlayerNode]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var synthBuffers: [SoundCue: AVAudioPCMBuffer] = [:]
    private var filePlayers: [SoundCue: [AVAudioPlayer]] = [:]
    private var nextNode = 0
    private var sessionReady = false
    private var engineReady = false

    private init() {
        synthNodes = (0..<5).map { _ in AVAudioPlayerNode() }
        for node in synthNodes {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    /// Render synth fallbacks + load the sampled file pools. Idempotent.
    func prewarm() {
        if synthBuffers.isEmpty {
            for cue in SoundCue.allCases {
                synthBuffers[cue] = Self.renderBuffer(for: cue, format: format)
            }
        }
        if filePlayers.isEmpty {
            for cue in SoundCue.allCases {
                guard let name = cue.soundFile,
                      let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
                // A few players per cue so rapid repeats can overlap.
                let pool = (0..<3).compactMap { _ -> AVAudioPlayer? in
                    let player = try? AVAudioPlayer(contentsOf: url)
                    player?.prepareToPlay()
                    return player
                }
                if !pool.isEmpty { filePlayers[cue] = pool }
            }
        }
    }

    /// Play a cue. Never throws; degrades silently if audio can't start.
    func play(_ cue: SoundCue) {
        prewarm()
        guard configureSession() else { return }

        if let pool = filePlayers[cue], let player = (pool.first { !$0.isPlaying } ?? pool.first) {
            player.currentTime = 0
            player.play()
            return
        }

        guard let buffer = synthBuffers[cue], ensureEngineStarted() else { return }
        let node = synthNodes[nextNode]
        nextNode = (nextNode + 1) % synthNodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    @discardableResult
    private func configureSession() -> Bool {
        if sessionReady { return true }
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return false
        }
        #endif
        sessionReady = true
        return true
    }

    private func ensureEngineStarted() -> Bool {
        if engineReady { return true }
        guard configureSession() else { return false }
        do {
            engine.prepare()
            try engine.start()
            for node in synthNodes { node.play() }
            engineReady = true
            return true
        } catch {
            return false
        }
    }

    /// Pure synthesis: render a cue's note sequence into a mono PCM buffer with a
    /// short attack/release envelope per note (no clicks) and a plucked decay.
    static func renderBuffer(for cue: SoundCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let noteFrames = max(1, Int((cue.noteDuration * sampleRate).rounded()))
        let totalFrames = noteFrames * cue.notes.count
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(totalFrames)

        let peak: Float = 0.45
        let attack = max(1, Int(0.006 * sampleRate))
        let release = max(1, Int(0.030 * sampleRate))
        let channelCount = Int(format.channelCount)
        var writeIndex = 0

        for frequency in cue.notes {
            let phaseIncrement = 2.0 * Double.pi * frequency / sampleRate
            var phase = 0.0
            for n in 0..<noteFrames {
                let raw: Double
                switch cue.waveform {
                case .sine: raw = sin(phase)
                case .triangle: raw = (2.0 / Double.pi) * asin(sin(phase))
                }
                var envelope = 0.8
                if n < attack {
                    envelope = 0.8 * Double(n) / Double(attack)
                } else if n > noteFrames - release {
                    envelope = 0.8 * Double(noteFrames - n) / Double(release)
                }
                let decay = 1.0 - 0.35 * (Double(n) / Double(noteFrames))
                let sample = Float(raw * envelope * decay) * peak
                for channel in 0..<channelCount { channels[channel][writeIndex] = sample }
                phase += phaseIncrement
                writeIndex += 1
            }
        }
        return buffer
    }
}
