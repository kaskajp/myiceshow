import Foundation
import RealityKit

enum SkaterAppearance: String, CaseIterable, Identifiable {
    case articulated = "Articulated"
    case importedSkin = "Imported skin"

    var id: String { rawValue }
}

enum ImportedSkaterStatus: Equatable {
    case loading
    case ready
    case failed(String)
}

enum ImportedSkaterError: LocalizedError {
    case missingAsset
    case incompatibleSkeleton
    case incompatibleBindPose
    case missingCostumeMaterial

    var errorDescription: String? {
        switch self {
        case .missingAsset: "The skinned test asset is missing from the app bundle."
        case .incompatibleSkeleton: "The test asset's skeleton does not match the pose sampler."
        case .incompatibleBindPose: "The test asset's bind/rest pose does not match the fixture's joint frames and proportions."
        case .missingCostumeMaterial: "The test asset has no named costume material."
        }
    }
}

@MainActor
final class ImportedSkater {
    private static let calibrationTolerance: Float = 0.00001
    let entity: Entity
    private let model: ModelEntity
    private let jointIndices: [Int]
    private let costumeIndex: Int

    init(entity: Entity) throws {
        let models = Self.skinnedModels(in: entity)
        guard models.count == 1, let model = models.first,
              Set(model.jointNames) == Set(SkaterSkeleton.jointNames),
              model.jointNames.count == SkaterSkeleton.jointNames.count,
              model.jointTransforms.count == model.jointNames.count else {
            throw ImportedSkaterError.incompatibleSkeleton
        }
        guard let costumeIndex = model.model?.materials.firstIndex(where: { $0.name == "Costume" }) else {
            throw ImportedSkaterError.missingCostumeMaterial
        }
        try Self.validateBindPose(of: model)
        self.entity = entity
        self.model = model
        self.costumeIndex = costumeIndex
        jointIndices = try model.jointNames.map { name in
            guard let index = SkaterSkeleton.jointNames.firstIndex(of: name) else {
                throw ImportedSkaterError.incompatibleSkeleton
            }
            return index
        }
    }

    static func load() async throws -> ImportedSkater {
        guard let url = Bundle.main.url(forResource: "SkaterFixture", withExtension: "usdz") else {
            throw ImportedSkaterError.missingAsset
        }
        return try await ImportedSkater(entity: Entity(contentsOf: url))
    }

    func update(pose: SkaterPose) {
        let transforms = SkaterSkeleton.transforms(for: pose)
        model.jointTransforms = jointIndices.map { index in
            let transform = transforms[index]
            return Transform(rotation: transform.rotation, translation: transform.translation)
        }
    }

    func updateCostume(_ material: SimpleMaterial) {
        model.model?.materials[costumeIndex] = material
    }

    private static func validateBindPose(of model: ModelEntity) throws {
        guard let skeletons = model.model?.mesh.contents.skeletons,
              skeletons.count == 1, let skeleton = skeletons.first,
              skeleton.joints.count == SkaterSkeleton.jointNames.count,
              Set(skeleton.joints.map(\.name)) == Set(SkaterSkeleton.jointNames) else {
            throw ImportedSkaterError.incompatibleBindPose
        }
        for joint in skeleton.joints {
            guard let index = SkaterSkeleton.jointNames.firstIndex(of: joint.name) else {
                throw ImportedSkaterError.incompatibleBindPose
            }
            let expectedParent = SkaterSkeleton.parentIndices[index].map { SkaterSkeleton.jointNames[$0] }
            let parentName: String?
            if let parent = joint.parentIndex {
                guard skeleton.joints.indices.contains(parent) else {
                    throw ImportedSkaterError.incompatibleBindPose
                }
                parentName = skeleton.joints[parent].name
            } else {
                parentName = nil
            }
            let rest = joint.restPoseTransform
            let identity = SIMD4<Float>(0, 0, 0, 1)
            let rotationError = min(
                simd_distance(rest.rotation.vector, identity),
                simd_distance(rest.rotation.vector, -identity)
            )
            let expectedInverseBind = Transform(translation: -SkaterSkeleton.bindTranslations[index]).matrix
            guard parentName == expectedParent,
                  simd_distance(rest.translation, SkaterSkeleton.restTranslations[index]) <= calibrationTolerance,
                  simd_distance(rest.scale, SIMD3<Float>(repeating: 1)) <= calibrationTolerance,
                  rotationError <= calibrationTolerance,
                  (0..<4).allSatisfy({ column in
                      let difference = abs(joint.inverseBindPoseMatrix[column] - expectedInverseBind[column])
                      return (0..<4).allSatisfy { difference[$0] <= calibrationTolerance }
                  }) else {
                throw ImportedSkaterError.incompatibleBindPose
            }
        }
    }

    private static func skinnedModels(in entity: Entity) -> [ModelEntity] {
        let ownModels: [ModelEntity]
        if let model = entity as? ModelEntity, !model.jointNames.isEmpty {
            ownModels = [model]
        } else {
            ownModels = []
        }
        return ownModels + entity.children.flatMap { skinnedModels(in: $0) }
    }
}
