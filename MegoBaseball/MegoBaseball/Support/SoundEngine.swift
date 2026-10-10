import AVFoundation

/// Square-wave bleeps in the spirit of a 1970s handheld's piezo speaker.
/// Every effect is synthesized once at launch; nothing is loaded from disk.
final class SoundEngine {
    enum Effect: CaseIterable {
        case tick, windup, ball, strike, swingMiss, foul
        case single, extraBase, homeRun, out, run, walk
        case steal, safe, sideRetired, gameStart, gameOver
    }

    private typealias Note = (frequency: Double, duration: Double)

    private let engine = AVAudioEngine()
    private let effectsPlayer = AVAudioPlayerNode()
    private let tickPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(effectsPlayer)
        engine.attach(tickPlayer)
        engine.connect(effectsPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(tickPlayer, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35

        for effect in Effect.allCases {
            buffers[effect] = render(notes(for: effect))
        }

        // Ambient: respects the silent switch and mixes with the player's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    func play(_ effect: Effect) {
        guard let buffer = buffers[effect] else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        // Ticks get their own player so the pitch track never cuts off a result jingle.
        let player = effect == .tick ? tickPlayer : effectsPlayer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func notes(for effect: Effect) -> [Note] {
        switch effect {
        case .tick: return [(1500, 0.015)]
        case .windup: return [(400, 0.05), (600, 0.05)]
        case .ball: return [(880, 0.09)]
        case .strike: return [(330, 0.18)]
        case .swingMiss: return [(600, 0.04), (450, 0.04), (300, 0.04), (200, 0.10)]
        case .foul: return [(700, 0.07), (0, 0.03), (700, 0.07)]
        case .single: return [(523, 0.07), (659, 0.07), (784, 0.12)]
        case .extraBase: return [(523, 0.06), (659, 0.06), (784, 0.06), (1047, 0.15)]
        case .homeRun: return [(392, 0.08), (523, 0.08), (659, 0.08), (784, 0.16), (659, 0.08), (784, 0.30)]
        case .out: return [(196, 0.35)]
        case .run: return [(1047, 0.05), (0, 0.03), (1319, 0.08)]
        case .walk: return [(659, 0.08), (784, 0.12)]
        case .steal: return [(1200, 0.03), (0, 0.02), (1200, 0.03), (0, 0.02), (1200, 0.03)]
        case .safe: return [(784, 0.06), (1047, 0.10)]
        case .sideRetired: return [(392, 0.12), (330, 0.12), (262, 0.25)]
        case .gameStart: return [(262, 0.10), (330, 0.10), (392, 0.10), (523, 0.25)]
        case .gameOver: return [(523, 0.15), (392, 0.15), (330, 0.15), (262, 0.40)]
        }
    }

    /// Renders notes back to back as a square wave. A frequency of 0 is a rest.
    private func render(_ notes: [Note]) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let totalFrames = notes.reduce(0) { $0 + Int($1.duration * sampleRate) }
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)),
              let samples = buffer.floatChannelData?[0] else { return nil }

        let amplitude: Float = 0.25
        let rampFrames = Int(0.003 * sampleRate) // soften clicks at note edges
        var index = 0
        for note in notes {
            let frames = Int(note.duration * sampleRate)
            for i in 0..<frames {
                var value: Float = 0
                if note.frequency > 0 {
                    let phase = (Double(i) * note.frequency / sampleRate).truncatingRemainder(dividingBy: 1)
                    value = phase < 0.5 ? amplitude : -amplitude
                    let edge = min(i, frames - 1 - i)
                    if edge < rampFrames { value *= Float(edge) / Float(rampFrames) }
                }
                samples[index] = value
                index += 1
            }
        }
        buffer.frameLength = AVAudioFrameCount(totalFrames)
        return buffer
    }
}
