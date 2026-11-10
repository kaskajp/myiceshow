import Combine
import RealityKit
import SwiftUI

enum StudySample {
    #if SKATER_GLIDE_STUDY
    static let title = "Glide Candidate Study"
    static let jointCount = 15
    static let clip = "Sustained glide candidate (unreviewed)"
    static let notice = "Unreviewed glide — no entry, stop, or transition is authored"
    #elseif SKATER_DCC_STUDY
    static let title = "Skater DCC Export Study"
    static let jointCount = 15
    static let clip = "Calibration (not skating)"
    static let notice = "DCC calibration only — not a production skater or skating clip"
    #else
    static let title = "External Character Study"
    static let jointCount = 41
    static let clip = "Idle"
    static let notice = "Compatibility donor only — not the production skater"
    #endif
}

@main
struct CharacterStudyApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup { StudyView() }
    }
}

struct StudyView: View {
    @StateObject private var study = PlaybackStudy()

    var body: some View {
        VStack(spacing: 12) {
            Text(StudySample.title).font(.headline)
            Text(study.status).font(.caption).accessibilityIdentifier("study-status")
            StudyStage(study: study)
            HStack {
                Button("Scene timeline") { study.useRoute(.scene) }
                Button("Direct skeleton") { study.useRoute(.skeleton) }
            }
            .buttonStyle(.bordered)
            .disabled(!study.ready || study.verifying)
            Text("Route: \(study.route.rawValue)").font(.caption)
            Text(study.clock).monospacedDigit()
            HStack {
                Button("Play") { study.play() }
                Button("Pause") { study.pause() }
                Button("Seek 0%") { study.seek(to: 0) }
                Button("Seek 50%") { study.seek(to: 0.5) }
                Button("Seek 100%") { study.seek(to: 1) }
            }
            .buttonStyle(.bordered)
            .disabled(!study.ready || study.verifying)
            Button("Check seeking") { study.checkSeeking() }
                .buttonStyle(.borderedProminent)
                .disabled(!study.ready || study.verifying)
            Text(study.verdict).font(.caption.monospaced())
                .accessibilityIdentifier("study-verdict")
            Text(study.playbackEvidence).font(.caption.monospaced())
            #if SKATER_GLIDE_STUDY
            Text(study.endpointEvidence).font(.caption.monospaced())
            #endif
            Text(StudySample.notice)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .task { await study.load() }
        .onDisappear { study.stop() }
    }
}

struct StudyStage: UIViewRepresentable {
    let study: PlaybackStudy

    func makeUIView(context: Context) -> ARView { study.view }
    func updateUIView(_ view: ARView, context: Context) {}
}

@MainActor
final class PlaybackStudy: ObservableObject {
    @Published private(set) var status = "Loading study sample"
    @Published private(set) var clock = "0.000 s"
    @Published private(set) var verdict = "Seeking not checked"
    @Published private(set) var playbackEvidence = "Playback not checked"
    @Published private(set) var ready = false
    @Published private(set) var verifying = false
    @Published private(set) var route = PlaybackRoute.skeleton
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)

    private var subscription: (any Cancellable)?
    private var entity: Entity?
    private var model: ModelEntity?
    private var animation: AnimationResource?
    private var sceneAnimation: AnimationResource?
    private var skeletalAnimation: AnimationResource?
    private var controller: AnimationPlaybackController?
    private var frames = 0
    private var pendingCapture: (fraction: Double, frame: Int)?
    private var sequence: [Double] = []
    private var poses: [Double: [Transform]] = [:]
    private var firstPose: [Transform] = []
    private var repeatError: Float = 0
    private var phaseChange: Float = 0
    private var timeError = 0.0
    private var captures = 0
    private var playbackStart: [Transform] = []
    private var playbackFrames = 0
    private var playbackChange: Float = 0
    private var observingPlayback = false
    #if SKATER_GLIDE_STUDY
    @Published private(set) var endpointEvidence = "Endpoint not checked"
    private var referenceFrames: [JointTransforms] = []
    private var frameInterval = 0.0
    private var referenceModelTransform = matrix_identity_float4x4
    private var authoredError: Float = 0
    private var nodeError: Float = 0
    private var pendingEndpointFrame: Int?
    #endif

    func load() async {
        guard entity == nil else { return }
        do {
            guard let url = Bundle.main.url(forResource: "StudyAsset", withExtension: "usdz") else {
                throw StudyError.missingAsset
            }
            let loaded = try await Entity(contentsOf: url)
            try Task.checkCancellation()
            let models = Self.skinnedModels(in: loaded)
            guard models.count == 1, let skinned = models.first,
                  skinned.jointNames.count == StudySample.jointCount,
                  skinned.jointTransforms.count == StudySample.jointCount else {
                throw StudyError.unexpectedSkeleton
            }
            guard let resource = loaded.availableAnimations.first(where: {
                $0.definition.name == "default subtree animation"
            }) else { throw StudyError.missingAnimation }
            let tracks = Self.skeletalTracks(in: resource.definition)
            guard tracks.count == 1, var track = tracks.first,
                  track.jointNames == skinned.jointNames else {
                throw StudyError.unexpectedAnimationBinding
            }
            #if SKATER_GLIDE_STUDY
            guard abs(track.duration - 3) < 0.00001,
                  track.frames.count > 1, track.frameInterval.isFinite, track.frameInterval > 0,
                  abs(Double(track.frames.count - 1) * Double(track.frameInterval) - track.duration) < 0.00001 else {
                throw StudyError.unexpectedAnimationBinding
            }
            referenceFrames = track.frames
            frameInterval = Double(track.frameInterval)
            #endif
            track.bindTarget = .jointTransforms
            track.fillMode = .both
            let skeletalResource = try AnimationResource.generate(with: track)
            sceneAnimation = resource
            skeletalAnimation = skeletalResource
            animation = skeletalResource
            entity = loaded
            model = skinned
            #if SKATER_GLIDE_STUDY
            referenceModelTransform = skinned.transformMatrix(relativeTo: nil)
            #endif
            configureScene(with: loaded)
            controller = skinned.playAnimation(skeletalResource, transitionDuration: 0, startsPaused: true)
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                Task { @MainActor [weak self] in self?.frame() }
            }
            ready = true
            status = "Ready: \(StudySample.jointCount) joints; \(StudySample.clip); \(String(format: "%.6f", resource.definition.duration)) s"
            seek(to: 0)
        } catch is CancellationError {
            status = "Load cancelled"
        } catch {
            status = "Import failed: \(error)"
        }
    }

    func play() {
        guard let target = playbackTarget, let model, let animation else { return }
        controller?.stop()
        pendingCapture = nil
        playbackStart = model.jointTransforms
        playbackFrames = 0
        playbackChange = 0
        observingPlayback = true
        #if SKATER_GLIDE_STUDY
        pendingEndpointFrame = nil
        endpointEvidence = "Endpoint not checked"
        #endif
        controller = target.playAnimation(animation, transitionDuration: 0, startsPaused: false)
        status = "Playing \(StudySample.clip)"
    }

    func pause() {
        controller?.pause()
        observingPlayback = false
        status = "Paused"
    }

    func seek(to fraction: Double) {
        guard let target = playbackTarget, let animation else { return }
        observingPlayback = false
        #if SKATER_GLIDE_STUDY
        pendingEndpointFrame = nil
        endpointEvidence = "Endpoint not checked"
        #endif
        if controller?.isValid != true || controller?.isComplete == true {
            controller?.stop()
            controller = target.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        }
        controller?.pause()
        controller?.time = fraction * animation.definition.duration
        pendingCapture = (fraction, frames + 8)
        status = "Seeking \(Int(fraction * 100))%"
    }

    func useRoute(_ route: PlaybackRoute) {
        controller?.stop()
        controller = nil
        self.route = route
        animation = route == .scene ? sceneAnimation : skeletalAnimation
        verdict = "Seeking not checked"
        playbackEvidence = "Playback not checked"
        seek(to: 0)
    }

    func checkSeeking() {
        verifying = true
        poses = [:]
        firstPose = []
        repeatError = 0
        phaseChange = 0
        timeError = 0
        captures = 0
        #if SKATER_GLIDE_STUDY
        authoredError = 0
        nodeError = 0
        #endif
        verdict = "Checking out-of-order poses"
        sequence = [0, 0.25, 0.75, 0.25, 0.5, 1, 0, 0.5, 1]
        seek(to: sequence.removeFirst())
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
        controller?.stop()
        pendingCapture = nil
        verifying = false
        ready = false
        #if SKATER_GLIDE_STUDY
        pendingEndpointFrame = nil
        #endif
    }

    private func frame() {
        frames += 1
        if frames.isMultiple(of: 6), let controller, controller.isValid {
            clock = String(format: "%.6f / %.6f s", controller.time, controller.duration)
        }
        if observingPlayback, let controller, let model, let animation {
            playbackFrames += 1
            playbackChange = max(playbackChange, Self.difference(playbackStart, model.jointTransforms))
            let finished = controller.isComplete || controller.time >= animation.definition.duration
            if finished || playbackFrames.isMultiple(of: 12) {
                playbackEvidence = String(format: "Playback: %d frames; joint change %.8f", playbackFrames, playbackChange)
            }
            if finished {
                observingPlayback = false
                if controller.isValid {
                    controller.pause()
                    controller.time = animation.definition.duration
                }
                clock = String(format: "%.6f / %.6f s", animation.definition.duration, animation.definition.duration)
                status = "Playback completed"
                #if SKATER_GLIDE_STUDY
                pendingEndpointFrame = frames + 8
                #endif
            }
        }
        #if SKATER_GLIDE_STUDY
        if let pendingEndpointFrame, frames >= pendingEndpointFrame, let model, let expected = referenceFrames.last {
            self.pendingEndpointFrame = nil
            let poseError = Self.difference(Array(expected), model.jointTransforms)
            let transformError = Self.matrixDifference(referenceModelTransform, model.transformMatrix(relativeTo: nil))
            let retained = poseError < 0.00001 && transformError < 0.00001
            endpointEvidence = String(format: "%@: endpoint pose %.8f; node %.8f", retained ? "PASS" : "NOT RETAINED", poseError, transformError)
        }
        #endif
        guard let pendingCapture, frames >= pendingCapture.frame, let model,
              let controller, let animation else { return }
        self.pendingCapture = nil
        let pose = model.jointTransforms
        let target = pendingCapture.fraction
        timeError = max(timeError, abs(controller.time - target * animation.definition.duration))
        #if SKATER_GLIDE_STUDY
        let authoredIndex = Int((target * animation.definition.duration / frameInterval).rounded())
        let expectedError = referenceFrames.indices.contains(authoredIndex)
            ? Self.difference(Array(referenceFrames[authoredIndex]), pose) : Float.infinity
        authoredError = max(authoredError, expectedError)
        nodeError = max(nodeError, Self.matrixDifference(referenceModelTransform, model.transformMatrix(relativeTo: nil)))
        #endif
        if verifying {
            if firstPose.isEmpty { firstPose = pose }
            phaseChange = max(phaseChange, Self.difference(firstPose, pose))
            if let earlier = poses[target] {
                repeatError = max(repeatError, Self.difference(earlier, pose))
            }
            poses[target] = pose
            captures += 1
            if !sequence.isEmpty {
                seek(to: sequence.removeFirst())
                return
            }
            verifying = false
            #if SKATER_GLIDE_STUDY
            let passed = phaseChange > 0.00001 && repeatError < 0.00001 && timeError < 0.00001 && authoredError < 0.00001 && nodeError < 0.00001
            #else
            let passed = phaseChange > 0.00001 && repeatError < 0.00001 && timeError < 0.00001
            #endif
            verdict = String(format: "%@: %d captures\nphase %.8f; repeat %.8f; time %.8f", passed ? "PASS" : "NOT PROVEN", captures, phaseChange, repeatError, timeError)
            #if SKATER_GLIDE_STUDY
            verdict += String(format: "\nauthored %.8f; node %.8f", authoredError, nodeError)
            #endif
        }
        clock = String(format: "%.6f / %.6f s", controller.time, controller.duration)
        status = "Paused at \(Int(target * 100))%; \(StudySample.jointCount) joints"
    }

    private func configureScene(with entity: Entity) {
        view.environment.background = .color(.init(white: 0.92, alpha: 1))
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(entity)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 45
        #if SKATER_GLIDE_STUDY
        camera.look(at: [-0.8, 1, 1.6], from: [4, 3.4, 8], relativeTo: nil)
        let ice = ModelEntity(mesh: .generatePlane(width: 8, depth: 8), materials: [SimpleMaterial(color: .init(white: 0.98, alpha: 1), isMetallic: false)])
        ice.position = [-1, 0, 1.6]
        anchor.addChild(ice)
        #else
        camera.look(at: [0, 1, 0], from: [3, 2.4, 5], relativeTo: nil)
        #endif
        anchor.addChild(camera)
        let light = DirectionalLight()
        light.light.intensity = 2500
        light.look(at: [0, 0.8, 0], from: [2, 4, 3], relativeTo: nil)
        anchor.addChild(light)
        view.scene.addAnchor(anchor)
    }

    private var playbackTarget: Entity? {
        route == .scene ? entity : model
    }

    #if SKATER_GLIDE_STUDY
    private static func matrixDifference(_ first: simd_float4x4, _ second: simd_float4x4) -> Float {
        (0..<4).reduce(0) { maximum, column in
            let error = abs(first[column] - second[column])
            guard error.indices.allSatisfy({ error[$0].isFinite }) else { return .infinity }
            return max(maximum, error.max())
        }
    }
    #endif

    private static func difference(_ first: [Transform], _ second: [Transform]) -> Float {
        guard first.count == second.count, !first.isEmpty else { return .infinity }
        return zip(first, second).reduce(0) { result, pair in
            let position = simd_distance(pair.0.translation, pair.1.translation)
            let scale = simd_distance(pair.0.scale, pair.1.scale)
            let rotation = min(
                simd_distance(pair.0.rotation.vector, pair.1.rotation.vector),
                simd_distance(pair.0.rotation.vector, -pair.1.rotation.vector)
            )
            guard position.isFinite, scale.isFinite, rotation.isFinite else { return .infinity }
            return max(result, position, scale, rotation)
        }
    }

    private static func skinnedModels(in entity: Entity) -> [ModelEntity] {
        let own = (entity as? ModelEntity).map { $0.jointNames.isEmpty ? [] : [$0] } ?? []
        return own + entity.children.flatMap { skinnedModels(in: $0) }
    }

    private static func skeletalTracks(in definition: any AnimationDefinition) -> [SampledAnimation<JointTransforms>] {
        if let track = definition as? SampledAnimation<JointTransforms> { return [track] }
        if let group = definition as? AnimationGroup {
            return group.group.flatMap { skeletalTracks(in: $0) }
        }
        if let view = definition as? AnimationView, let source = view.source {
            return skeletalTracks(in: source)
        }
        return []
    }

    enum StudyError: Error {
        case missingAsset
        case unexpectedSkeleton
        case missingAnimation
        case unexpectedAnimationBinding
    }

    enum PlaybackRoute: String {
        case scene = "Imported scene timeline"
        case skeleton = "Explicit skeletal binding"
    }
}
