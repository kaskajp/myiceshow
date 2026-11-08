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
    case missingCostumeMaterial

    var errorDescription: String? {
        switch self {
        case .missingAsset: "The skinned test asset is missing from the app bundle."
        case .incompatibleSkeleton: "The test asset's skeleton does not match the pose sampler."
        case .missingCostumeMaterial: "The test asset has no named costume material."
        }
    }
}

@MainActor
final class ImportedSkater {
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
