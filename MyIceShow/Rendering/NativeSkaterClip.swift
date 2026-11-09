import Foundation
import RealityKit

@MainActor
struct NativeSkaterClip {
    let entity: Entity
    let model: ModelEntity
    let animation: AnimationResource

    init(entity: Entity) throws {
        let models = Self.skinnedModels(in: entity)
        guard models.count == 1, let model = models.first,
              model.jointNames.count == SkaterSkeleton.jointNames.count,
              Set(model.jointNames) == Set(SkaterSkeleton.jointNames),
              model.jointTransforms.count == model.jointNames.count else {
            throw NativeClipError.incompatibleSkeleton
        }
        let scenes = entity.availableAnimations.filter { $0.definition.name == "default subtree animation" }
        guard scenes.count == 1, let scene = scenes.first else {
            throw NativeClipError.missingAnimation
        }
        let tracks = Self.skeletalTracks(in: scene.definition)
        guard tracks.count == 1, var track = tracks.first,
              track.jointNames == model.jointNames,
              track.frames.count >= 2,
              track.duration.isFinite, track.duration > 0,
              abs(track.duration - scene.definition.duration) < 0.00001,
              track.frames.allSatisfy({ frame in
                  frame.count == model.jointNames.count && frame.allSatisfy { transform in
                      transform.translation.indices.allSatisfy { transform.translation[$0].isFinite }
                          && transform.scale.indices.allSatisfy { transform.scale[$0].isFinite }
                          && transform.rotation.vector.indices.allSatisfy { transform.rotation.vector[$0].isFinite }
                  }
              }) else {
            throw NativeClipError.incompatibleAnimation
        }
        track.bindTarget = .jointTransforms
        track.fillMode = .both
        self.entity = entity
        self.model = model
        animation = try AnimationResource.generate(with: track)
    }

    static func load() async throws -> NativeSkaterClip {
        guard let url = Bundle.main.url(forResource: "SkaterCalibration", withExtension: "usdz") else {
            throw NativeClipError.missingAsset
        }
        let entity = try await Entity(contentsOf: url)
        try Task.checkCancellation()
        return try NativeSkaterClip(entity: entity)
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
}

enum NativeClipError: LocalizedError {
    case missingAsset
    case incompatibleSkeleton
    case missingAnimation
    case incompatibleAnimation

    var errorDescription: String? {
        switch self {
        case .missingAsset: "The native calibration asset is missing from the app bundle."
        case .incompatibleSkeleton: "The calibration asset does not contain the expected skater skeleton."
        case .missingAnimation: "The calibration asset has no unique imported scene animation."
        case .incompatibleAnimation: "The calibration clip cannot be bound directly to its skinned model."
        }
    }
}
