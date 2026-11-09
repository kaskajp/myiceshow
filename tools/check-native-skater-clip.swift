import Foundation
import RealityKit

@main
struct NativeClipChecks {
    @MainActor
    static func main() async {
        do {
            guard CommandLine.arguments.count == 3 else {
                throw CheckFailure.failed("Usage: check-native-skater-clip calibration.usdz fixture.usdz")
            }
            let entity = try await Entity(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let clip = try NativeSkaterClip(entity: entity)
            guard let scene = entity.availableAnimations.first(where: {
                $0.definition.name == "default subtree animation"
            }), let original = tracks(in: scene.definition).first,
                  let rebound = clip.animation.definition as? SampledAnimation<JointTransforms>,
                  rebound.jointNames == original.jointNames,
                  rebound.frames.count == original.frames.count,
                  abs(rebound.duration - original.duration) < 0.00001 else {
                throw CheckFailure.failed("Native track layout or timing changed")
            }
            for (source, bound) in zip(original.frames, rebound.frames) {
                guard source.count == bound.count else { throw CheckFailure.failed("Lost joints") }
                for (first, second) in zip(source, bound) {
                    let rotationError = min(
                        simd_distance(first.rotation.vector, second.rotation.vector),
                        simd_distance(first.rotation.vector, -second.rotation.vector)
                    )
                    guard simd_distance(first.translation, second.translation) < 0.00001,
                          simd_distance(first.scale, second.scale) < 0.00001,
                          rotationError < 0.00001 else {
                        throw CheckFailure.failed("Native joint frame replaced or retargeted")
                    }
                }
            }
            print("PASS: native joint frames, ordering, and duration preserved")
            do {
                _ = try ImportedSkater(entity: entity)
                throw CheckFailure.failed("Procedural adapter accepted native DCC bind frames")
            } catch ImportedSkaterError.incompatibleBindPose {
                print("PASS: procedural adapter still rejects native DCC bind frames")
            }
            let fixture = try await Entity(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
            do {
                _ = try NativeSkaterClip(entity: fixture)
                throw CheckFailure.failed("Fixture without native scene clip was accepted")
            } catch NativeClipError.missingAnimation {
                print("PASS: no-clip fixture rejected without procedural fallback")
            }

            let mutations: [(String, (inout SampledAnimation<JointTransforms>) -> Void)] = [
                ("different joint order", { $0.jointNames.swapAt(9, 10) }),
                ("nonfinite joint frame", { $0.frames[0][0].translation.x = .nan })
            ]
            for (label, mutate) in mutations {
                let candidate = entity.clone(recursive: true)
                var changed = original
                mutate(&changed)
                changed.name = "default subtree animation"
                let resource = try AnimationResource.generate(with: changed)
                candidate.components.set(AnimationLibraryComponent(animations: ["calibration": resource]))
                do {
                    _ = try NativeSkaterClip(entity: candidate)
                    throw CheckFailure.failed("Accepted \(label)")
                } catch NativeClipError.incompatibleAnimation {
                    print("PASS: rejected \(label)")
                }
            }
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func tracks(in definition: any AnimationDefinition) -> [SampledAnimation<JointTransforms>] {
        if let track = definition as? SampledAnimation<JointTransforms> { return [track] }
        if let group = definition as? AnimationGroup { return group.group.flatMap { tracks(in: $0) } }
        if let view = definition as? AnimationView, let source = view.source { return tracks(in: source) }
        return []
    }

    enum CheckFailure: Error {
        case failed(String)
    }
}
