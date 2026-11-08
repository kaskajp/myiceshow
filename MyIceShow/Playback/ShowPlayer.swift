import AVFoundation
import Observation
import QuartzCore

@MainActor
@Observable
final class ShowPlayer: NSObject {
    private(set) var elapsed: Double = 0
    private(set) var isPlaying = false
    private(set) var errorMessage: String?
    var soundEnabled = true {
        didSet { audioPlayer?.volume = soundEnabled ? 0.35 : 0 }
    }

    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private let displayTarget = PlaybackDisplayTarget()
    @ObservationIgnored private var duration: Double = 0
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        displayTarget.player = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pause() }
        }
    }

    func play(duration: Double) {
        guard duration > 0 else { return }
        self.duration = duration
        errorMessage = nil

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            if audioPlayer == nil {
                audioPlayer = try AVAudioPlayer(data: TimingPulse.audioData())
            }
            guard let audioPlayer else { return }
            if elapsed >= duration { elapsed = 0 }
            audioPlayer.volume = soundEnabled ? 0.35 : 0
            audioPlayer.currentTime = elapsed
            guard audioPlayer.play() else {
                errorMessage = "The timing audio could not start. Please try again."
                return
            }
            displayLink?.invalidate()
            let link = CADisplayLink(target: displayTarget, selector: #selector(PlaybackDisplayTarget.refresh))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
            isPlaying = true
        } catch {
            errorMessage = "Timing audio is unavailable: \(error.localizedDescription)"
        }
    }

    func pause() {
        if isPlaying { refresh() }
        audioPlayer?.pause()
        displayLink?.invalidate()
        displayLink = nil
        isPlaying = false
    }

    func seek(to time: Double, duration: Double) {
        self.duration = duration
        elapsed = min(max(time, 0), duration)
        audioPlayer?.currentTime = elapsed
        if elapsed >= duration { pause() }
    }

    func reset() {
        pause()
        elapsed = 0
        audioPlayer?.currentTime = 0
    }

    fileprivate func refresh() {
        guard let audioPlayer, isPlaying else { return }
        elapsed = min(audioPlayer.currentTime, duration)
        guard elapsed >= duration || !audioPlayer.isPlaying else { return }
        audioPlayer.pause()
        displayLink?.invalidate()
        displayLink = nil
        isPlaying = false
    }
}

@MainActor
private final class PlaybackDisplayTarget: NSObject {
    weak var player: ShowPlayer?

    @objc func refresh() {
        player?.refresh()
    }
}
