import Combine
import Observation
import RealityKit

@MainActor
@Observable
final class NativeClipPlayer {
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var isReady = false
    private(set) var status = "Loading native calibration clip…"
    var isControllerPaused: Bool { controller?.isPaused == true }

    @ObservationIgnored let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    @ObservationIgnored private var clip: NativeSkaterClip?
    @ObservationIgnored private var controller: AnimationPlaybackController?
    @ObservationIgnored private var subscription: (any Cancellable)?

    func load() async {
        do {
            let loaded = try await NativeSkaterClip.load()
            try Task.checkCancellation()
            clip = loaded
            duration = loaded.animation.definition.duration
            configureScene(with: loaded.entity)
            isReady = true
            seek(to: 0)
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
        } catch is CancellationError {
            status = "Preview load cancelled."
        } catch {
            status = "Preview import failed: \(error.localizedDescription)"
        }
    }

    func play() {
        guard isReady, let clip else { return }
        if controller?.isValid != true || elapsed >= duration {
            controller?.stop()
            controller = clip.model.playAnimation(clip.animation, transitionDuration: 0, startsPaused: true)
            controller?.time = 0
            elapsed = 0
        }
        controller?.resume()
        isPlaying = true
        status = "Playing native calibration"
    }

    func pause() {
        guard isReady else { return }
        refresh()
        controller?.pause()
        isPlaying = false
        status = elapsed >= duration ? "Calibration completed" : "Paused"
    }

    func seek(to time: Double) {
        guard isReady, time.isFinite, let clip else { return }
        if controller?.isValid != true || controller?.isComplete == true {
            controller?.stop()
            controller = clip.model.playAnimation(clip.animation, transitionDuration: 0, startsPaused: true)
        }
        controller?.pause()
        controller?.time = min(max(time, 0), duration)
        elapsed = controller?.time ?? 0
        isPlaying = false
        status = "Paused"
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
        controller?.stop()
        controller = nil
        view.scene.anchors.removeAll()
        clip = nil
        isReady = false
        isPlaying = false
    }

    private func refresh() {
        guard isPlaying, let controller else { return }
        if controller.isComplete || (controller.isValid && controller.time >= duration) {
            if controller.isValid {
                controller.pause()
                controller.time = duration
            }
            elapsed = duration
            isPlaying = false
            status = "Calibration completed"
            return
        }
        guard controller.isValid else {
            isPlaying = false
            status = "Native playback became unavailable. Reopen the preview to try again."
            isReady = false
            return
        }
        elapsed = min(max(controller.time, 0), duration)
    }

    private func configureScene(with entity: Entity) {
        view.environment.background = .color(.init(white: 0.94, alpha: 1))
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(entity)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 45
        camera.look(at: [0, 1, 0], from: [3, 2.4, 5], relativeTo: nil)
        anchor.addChild(camera)
        let light = DirectionalLight()
        light.light.intensity = 2500
        light.look(at: [0, 0.8, 0], from: [2, 4, 3], relativeTo: nil)
        anchor.addChild(light)
        view.scene.addAnchor(anchor)
    }
}
