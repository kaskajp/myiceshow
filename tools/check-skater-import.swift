import Foundation
import RealityKit

@main
struct SkaterImportChecks {
    @MainActor
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else {
                throw CheckFailure.failed("Usage: check-skater-import /path/to/SkaterFixture.usdz")
            }
            let root = try await Entity(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            guard let model = skinnedModel(in: root), let component = model.model,
                  let skeleton = component.mesh.contents.skeletons.first else {
                throw CheckFailure.failed("Fixture has no skinned mesh")
            }
            let imported = try ImportedSkater(entity: root)
            try checkPlayback(imported, model: model)
            _ = try ImportedSkater(entity: root)
            print("PASS: fixture playback and revalidation after posing")

            let mutations: [(String, (inout MeshResource.Skeleton) -> Void)] = [
                ("rest offset", { $0.joints[4].restPoseTransform.translation.y += 0.01 }),
                ("rest rotation", {
                    $0.joints[9].restPoseTransform.rotation = simd_quatf(angle: 0.1, axis: [0, 1, 0])
                }),
                ("rest scale", { $0.joints[0].restPoseTransform.scale.x = 1.01 }),
                ("inverse bind offset", { $0.joints[4].inverseBindPoseMatrix.columns.3.y += 0.01 }),
                ("inverse bind axes", { $0.joints[9].inverseBindPoseMatrix.columns.0.x = -1 }),
                ("wrong parent", { $0.joints[4].parentIndex = 0 }),
                ("nonfinite rest", { $0.joints[3].restPoseTransform.translation.x = .nan }),
                ("nonfinite rotation", { $0.joints[3].restPoseTransform.rotation.vector.x = .nan }),
                ("nonfinite scale", { $0.joints[3].restPoseTransform.scale.z = .infinity }),
                ("nonfinite bind", { $0.joints[3].inverseBindPoseMatrix.columns.2.z = .nan })
            ]
            for (label, mutate) in mutations {
                var changed = skeleton
                mutate(&changed)
                let candidate = try makeModel(component: component, skeleton: changed)
                do {
                    _ = try ImportedSkater(entity: candidate)
                    throw CheckFailure.failed("Accepted \(label)")
                } catch ImportedSkaterError.incompatibleBindPose {
                    print("PASS: rejected \(label)")
                }
            }

            var equivalent = skeleton
            equivalent.joints[3].restPoseTransform.rotation = simd_quatf(real: -1, imag: .zero)
            equivalent.joints[4].restPoseTransform.translation.y += 0.000001
            equivalent.joints[4].inverseBindPoseMatrix.columns.3.y += 0.000001
            _ = try ImportedSkater(entity: makeModel(component: component, skeleton: equivalent))
            print("PASS: equivalent quaternion sign and export rounding accepted")

            let reordered = try reorderedModel(component: component, skeleton: skeleton)
            guard reordered.jointNames != model.jointNames else {
                throw CheckFailure.failed("Reordering did not change model joint order")
            }
            try checkPlayback(ImportedSkater(entity: reordered), model: reordered)
            print("PASS: reordered joints map sampled poses by name")
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    static func checkPlayback(_ imported: ImportedSkater, model: ModelEntity) throws {
        for move in SkatingMove.allCases {
            let clips = [RoutineClip(move: move)]
            for fraction in [0.0, 0.75, 0.25, 1.0, 0.25] {
                let sample = SkatingMotion.sample(clips: clips, at: clips[0].duration * fraction)
                let pose = SkaterRig.pose(for: sample)
                imported.update(pose: pose)
                let expected = SkaterSkeleton.transforms(for: pose)
                guard model.jointTransforms.count == expected.count else {
                    throw CheckFailure.failed("Pose assignment dropped joints")
                }
                for (name, transform) in zip(model.jointNames, model.jointTransforms) {
                    guard let index = SkaterSkeleton.jointNames.firstIndex(of: name) else {
                        throw CheckFailure.failed("Unexpected posed joint \(name)")
                    }
                    let target = expected[index]
                    let rotationError = min(
                        simd_distance(transform.rotation.vector, target.rotation.vector),
                        simd_distance(transform.rotation.vector, -target.rotation.vector)
                    )
                    guard simd_distance(transform.translation, target.translation) < 0.00001,
                          rotationError < 0.00001 else {
                        throw CheckFailure.failed("Wrong pose for \(name) in \(move.rawValue)")
                    }
                }
            }
        }
    }

    @MainActor
    static func makeModel(component: ModelComponent, skeleton: MeshResource.Skeleton) throws -> ModelEntity {
        var contents = component.mesh.contents
        contents.skeletons = MeshSkeletonCollection([skeleton])
        return try ModelEntity(mesh: MeshResource.generate(from: contents), materials: component.materials)
    }

    @MainActor
    static func reorderedModel(component: ModelComponent, skeleton: MeshResource.Skeleton) throws -> ModelEntity {
        let order = [0, 1] + Array(3..<skeleton.joints.count) + [2]
        let newIndices = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        var reordered = skeleton
        reordered.joints = order.map { index in
            var joint = skeleton.joints[index]
            joint.parentIndex = joint.parentIndex.map { newIndices[$0]! }
            return joint
        }
        var contents = component.mesh.contents
        contents.skeletons = MeshSkeletonCollection([reordered])
        contents.models = MeshModelCollection(contents.models.map { original in
            var mesh = original
            mesh.parts = MeshPartCollection(original.parts.map { originalPart in
                var part = originalPart
                if let skin = part.jointInfluences {
                    let influences = skin.influences.map { influence in
                        MeshJointInfluence(jointIndex: newIndices[influence.jointIndex]!, weight: influence.weight)
                    }
                    part.jointInfluences = MeshResource.JointInfluences(
                        influences: MeshBuffer(influences),
                        influencesPerVertex: influences.count / part.positions.count
                    )
                }
                return part
            })
            return mesh
        })
        return try ModelEntity(mesh: MeshResource.generate(from: contents), materials: component.materials)
    }

    @MainActor
    static func skinnedModel(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity, !model.jointNames.isEmpty { return model }
        return entity.children.compactMap { skinnedModel(in: $0) }.first
    }

    enum CheckFailure: Error {
        case failed(String)
    }
}
