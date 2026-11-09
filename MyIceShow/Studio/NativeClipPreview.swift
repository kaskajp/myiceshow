import RealityKit
import SwiftUI

struct NativeClipPreview: View {
    let clips: [RoutineClip]
    let showPlayer: ShowPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = NativeClipPlayer()
    @State private var followsShow = false
    @State private var entryTime: Double?

    private var duration: Double { followsShow ? SkatingMotion.duration(of: clips) : player.duration }
    private var elapsed: Double { followsShow ? showPlayer.elapsed : player.elapsed }
    private var isPlaying: Bool { followsShow ? showPlayer.isPlaying : player.isPlaying }
    private var timelineSample: NativeTimelineSample? {
        NativeClipTimeline.sample(clips: clips, at: showPlayer.elapsed, nativeDuration: player.duration)
    }
    private var status: String {
        guard player.isReady, followsShow else { return player.status }
        if let error = showPlayer.errorMessage { return error }
        guard let sample = timelineSample else { return "No routine slots. Add a move in Studio to study show timing." }
        return "Slot \(sample.clipIndex + 1): \(clips[sample.clipIndex].move.title) · calibration, not this move"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Native clip preview")
                        .font(.title2.bold())
                    Text("DCC calibration only — not skating")
                        .font(.headline)
                    Text("Show mode samples calibration from Studio's clock, restarting the bend per slot and holding its end. Closing restores your show position. This is not skating animation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Single clip") { switchMode(followShow: false) }
                            .accessibilityAddTraits(followsShow ? [] : .isSelected)
                        Button("Show timeline") { switchMode(followShow: true) }
                            .accessibilityAddTraits(followsShow ? .isSelected : [])
                    }
                    .buttonStyle(.bordered)
                    .disabled(!player.isReady)
                    NativeClipStage(player: player)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .accessibilityLabel("Native animated skater calibration")
                    Text(status)
                        .font(.caption)
                        .accessibilityIdentifier("native-clip-status")
                    Text(String(format: "%.3f / %.3f s", elapsed, duration))
                        .monospacedDigit()
                        .accessibilityIdentifier("native-clip-time")
                    if followsShow && player.isReady {
                        Text(String(format: "Native clip: %.3f / %.3f s · controller %@", player.elapsed, player.duration, player.isControllerPaused ? "paused" : "not paused"))
                            .font(.caption.monospacedDigit())
                            .accessibilityIdentifier("native-clip-driven-time")
                    }
                    VStack(spacing: 16) {
                        Slider(value: Binding(
                            get: { elapsed },
                            set: { seek(to: $0) }
                        ), in: 0...max(duration, 0.001))
                        .accessibilityLabel(followsShow ? "Study show position" : "Native clip position")
                        HStack {
                            Button(isPlaying ? "Pause preview" : "Play preview", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                                togglePlayback()
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.white)
                            Spacer()
                            Button("Restart preview", systemImage: "backward.end.fill") { seek(to: 0) }
                                .buttonStyle(.bordered)
                        }
                        HStack {
                            Button("Start") { seek(to: 0) }
                            Spacer()
                            Button("Midpoint") { seek(to: duration / 2) }
                            Spacer()
                            Button("End") { seek(to: duration) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                    .disabled(!player.isReady || (followsShow && clips.isEmpty))
                    if followsShow {
                        ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                            Button("Seek slot \(index + 1): \(clip.move.title)") {
                                seek(to: clips.prefix(index).reduce(0) { $0 + $1.duration })
                            }
                            .buttonStyle(.bordered)
                            .disabled(!player.isReady)
                        }
                    }
                    Text("No procedural pose replacement, retargeting, or saved-show changes. Production skating clips and coach review are still needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .background(StudioTheme.background)
            .foregroundStyle(StudioTheme.ink)
            .tint(StudioTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            entryTime = showPlayer.elapsed
            await player.load()
        }
        .onChange(of: showPlayer.elapsed) { _, _ in
            if followsShow { applyShowTime() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                player.pause()
                showPlayer.pause()
            }
        }
        .onDisappear {
            showPlayer.pause()
            if let entryTime { showPlayer.seek(to: entryTime, duration: SkatingMotion.duration(of: clips)) }
            player.stop()
        }
    }

    private func switchMode(followShow: Bool) {
        player.pause()
        showPlayer.pause()
        followsShow = followShow
        if followsShow { applyShowTime() } else { player.seek(to: 0) }
    }

    private func seek(to time: Double) {
        guard followsShow else {
            player.seek(to: time)
            return
        }
        showPlayer.pause()
        showPlayer.seek(to: time, duration: duration)
        applyShowTime()
    }

    private func togglePlayback() {
        guard followsShow else {
            if player.isPlaying { player.pause() } else { player.play() }
            return
        }
        if showPlayer.isPlaying { showPlayer.pause() } else { showPlayer.play(duration: duration) }
        applyShowTime()
    }

    private func applyShowTime() {
        guard let sample = timelineSample else { return }
        player.seek(to: sample.nativeTime)
    }
}

private struct NativeClipStage: UIViewRepresentable {
    let player: NativeClipPlayer

    func makeUIView(context: Context) -> ARView { player.view }
    func updateUIView(_ view: ARView, context: Context) {}
}
