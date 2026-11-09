import Foundation
import RealityKit

@main
struct CharacterImportProbe {
    @MainActor
    static func main() async {
        do {
            try await probe()
        } catch {
            FileHandle.standardError.write(Data("Import probe failed: \(error)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    static func probe() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw ProbeError.usage
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let entity = try await Entity(contentsOf: url)
        inspectModels(entity)
        let models = skinnedModels(in: entity)
        print("Skinned models: \(models.count)")
        for model in models {
            guard model.jointNames.count == model.jointTransforms.count else {
                throw ProbeError.jointCountMismatch
            }
            print("Model: \(model.name), joints: \(model.jointNames.count)")
            print("Joint names: \(model.jointNames)")
            print("Materials: \(model.model?.materials.map { $0.name ?? "unnamed" } ?? [])")
        }
        let bounds = entity.visualBounds(relativeTo: nil)
        print("Bounds center: \(bounds.center), extents: \(bounds.extents)")
        print("Root animations: \(entity.availableAnimations.count)")
        for animation in entity.availableAnimations {
            print("Animation: \(animation.definition.name), duration: \(animation.definition.duration)")
        }
        do {
            _ = try ImportedSkater(entity: entity)
            print("Fixture adapter: accepted")
        } catch ImportedSkaterError.incompatibleSkeleton {
            print("Fixture adapter: rejected incompatible skeleton")
        } catch ImportedSkaterError.incompatibleBindPose {
            print("Fixture adapter: rejected incompatible bind/rest pose")
        } catch ImportedSkaterError.missingCostumeMaterial {
            print("Fixture adapter: rejected missing Costume material")
        }
        guard !models.isEmpty else { throw ProbeError.noSkin }
    }

    @MainActor
    static func inspectModels(_ entity: Entity) {
        if let model = entity as? ModelEntity {
            print("Model entity: \(model.name), joint count: \(model.jointNames.count), mesh skeletons: \(model.model?.mesh.contents.skeletons.map { $0.joints.count } ?? [])")
        }
        for child in entity.children { inspectModels(child) }
    }

    @MainActor
    static func skinnedModels(in entity: Entity) -> [ModelEntity] {
        let ownModels: [ModelEntity]
        if let model = entity as? ModelEntity, !model.jointNames.isEmpty {
            ownModels = [model]
        } else {
            ownModels = []
        }
        return ownModels + entity.children.flatMap { skinnedModels(in: $0) }
    }

    enum ProbeError: Error {
        case usage
        case noSkin
        case jointCountMismatch
    }
}
