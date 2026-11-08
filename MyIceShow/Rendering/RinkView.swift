import RealityKit
import SwiftUI

struct RinkView: UIViewRepresentable {
    let sample: MotionSample
    let costume: CostumeColor
    let appearance: SkaterAppearance
    let onImportStatus: (ImportedSkaterStatus) -> Void

    func makeCoordinator() -> RinkRenderer {
        RinkRenderer()
    }

    func makeUIView(context: Context) -> ARView {
        context.coordinator.makeView(onImportStatus: onImportStatus)
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.update(sample: sample, costume: costume, appearance: appearance)
    }

    static func dismantleUIView(_ view: ARView, coordinator: RinkRenderer) {
        coordinator.stopLoading()
    }
}

@MainActor
final class RinkRenderer {
    private let skater = Entity()
    private let articulatedSkater = Entity()
    private let torso = ModelEntity()
    private var bones: [String: ModelEntity] = [:]
    private var joints: [String: ModelEntity] = [:]
    private var currentCostume: CostumeColor?
    private var importedSkater: ImportedSkater?
    private var importTask: Task<Void, Never>?
    private var lastSample = MotionSample()
    private var lastCostume = CostumeColor.lilac
    private var lastAppearance = SkaterAppearance.importedSkin

    func makeView(onImportStatus: @escaping (ImportedSkaterStatus) -> Void) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 0.88, green: 0.91, blue: 0.98, alpha: 1))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField]
        let world = AnchorEntity(world: .zero)
        world.addChild(makeRink())
        world.addChild(skater)
        skater.addChild(articulatedSkater)
        makeSkater()
        importTask = Task { [weak self] in
            do {
                let imported = try await ImportedSkater.load()
                try Task.checkCancellation()
                guard let self else { return }
                importedSkater = imported
                skater.addChild(imported.entity)
                currentCostume = nil
                update(sample: lastSample, costume: lastCostume, appearance: lastAppearance)
                onImportStatus(.ready)
            } catch {
                guard !Task.isCancelled else { return }
                onImportStatus(.failed(error.localizedDescription))
            }
        }

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 43
        camera.look(at: [0, 0.35, 0], from: [5.5, 5.8, 7.5], relativeTo: nil)
        world.addChild(camera)

        let light = DirectionalLight()
        light.light.intensity = 2_500
        light.shadow = .init(maximumDistance: 20, depthBias: 1)
        light.look(at: .zero, from: [3, 8, 4], relativeTo: nil)
        world.addChild(light)
        view.scene.addAnchor(world)
        return view
    }

    func stopLoading() {
        importTask?.cancel()
    }

    func update(sample: MotionSample, costume: CostumeColor, appearance: SkaterAppearance) {
        lastSample = sample
        lastCostume = costume
        lastAppearance = appearance
        let pose = SkaterRig.pose(for: sample)
        skater.position = SkaterRig.rootPosition(for: sample, pose: pose)
        skater.orientation = simd_quatf(angle: sample.yaw, axis: [0, 1, 0])
        articulatedSkater.isEnabled = appearance == .articulated
        importedSkater?.entity.isEnabled = appearance == .importedSkin
        importedSkater?.update(pose: pose)
        if currentCostume != costume {
            torso.model?.materials = [material(costume.uiColor)]
            bones["shoulders"]?.model?.materials = [material(costume.uiColor)]
            importedSkater?.updateCostume(material(costume.uiColor))
            currentCostume = costume
        }

        setBone("leftThigh", from: pose.leftLeg.start, to: pose.leftLeg.joint)
        setBone("leftShin", from: pose.leftLeg.joint, to: pose.leftLeg.end)
        setBone("rightThigh", from: pose.rightLeg.start, to: pose.rightLeg.joint)
        setBone("rightShin", from: pose.rightLeg.joint, to: pose.rightLeg.end)
        setBone("leftUpperArm", from: pose.leftArm.start, to: pose.leftArm.joint)
        setBone("leftForearm", from: pose.leftArm.joint, to: pose.leftArm.end)
        setBone("rightUpperArm", from: pose.rightArm.start, to: pose.rightArm.joint)
        setBone("rightForearm", from: pose.rightArm.joint, to: pose.rightArm.end)
        setBone("body", from: pose.pelvis, to: pose.shoulders)
        setBone("hips", from: pose.leftLeg.start, to: pose.rightLeg.start)
        setBone("shoulders", from: pose.leftArm.start, to: pose.rightArm.start)
        setBone("neck", from: pose.shoulders, to: pose.shoulders + [0, SkaterRig.neckLength, 0])
        joints["head"]?.position = pose.head
        joints["hair"]?.position = pose.head + [0, 0.09, -0.015]
        joints["bun"]?.position = pose.head + [0, 0.11, -0.13]
        joints["leftSkate"]?.position = pose.leftLeg.end
        joints["rightSkate"]?.position = pose.rightLeg.end
        joints["leftBlade"]?.position = pose.leftLeg.end + SkaterRig.bladeOffset
        joints["rightBlade"]?.position = pose.rightLeg.end + SkaterRig.bladeOffset
        joints["leftKnee"]?.position = pose.leftLeg.joint
        joints["rightKnee"]?.position = pose.rightLeg.joint
        joints["leftElbow"]?.position = pose.leftArm.joint
        joints["rightElbow"]?.position = pose.rightArm.joint
        joints["leftHand"]?.position = pose.leftArm.end
        joints["rightHand"]?.position = pose.rightArm.end
    }

    private func makeSkater() {
        let skin = UIColor(red: 0.77, green: 0.53, blue: 0.39, alpha: 1)
        let leggings = UIColor(red: 0.2, green: 0.22, blue: 0.34, alpha: 1)
        for side in ["left", "right"] {
            addBone("\(side)Thigh", length: SkaterRig.thighLength, radius: 0.065, color: leggings)
            addBone("\(side)Shin", length: SkaterRig.shinLength, radius: 0.065, color: leggings)
            addBone("\(side)UpperArm", length: SkaterRig.upperArmLength, radius: 0.045, color: skin)
            addBone("\(side)Forearm", length: SkaterRig.forearmLength, radius: 0.045, color: skin)
            addJoint("\(side)Knee", mesh: .generateSphere(radius: 0.065), color: leggings)
            addJoint("\(side)Elbow", mesh: .generateSphere(radius: 0.045), color: skin)
            addJoint("\(side)Hand", mesh: .generateSphere(radius: 0.055), color: skin)
        }
        addBone("hips", length: SkaterRig.hipWidth, radius: 0.09, color: leggings)
        addBone("shoulders", length: SkaterRig.shoulderWidth, radius: 0.07, color: .systemPurple)
        addBone("neck", length: SkaterRig.neckLength, radius: 0.055, color: skin)
        torso.model = ModelComponent(mesh: .generateSphere(radius: 1), materials: [material(.systemPurple)])
        torso.scale = [0.2, SkaterRig.torsoLength / 2, 0.16]
        articulatedSkater.addChild(torso)
        bones["body"] = torso

        addJoint("head", mesh: .generateSphere(radius: 0.16), color: skin)
        addJoint("hair", mesh: .generateSphere(radius: 0.145), color: .darkGray)
        addJoint("bun", mesh: .generateSphere(radius: 0.085), color: .darkGray)
        for side in ["left", "right"] {
            addJoint("\(side)Skate", mesh: .generateBox(size: [0.14, 0.12, 0.3], cornerRadius: 0.035), color: .white)
            addJoint("\(side)Blade", mesh: .generateBox(size: [0.025, 0.025, 0.36]), color: .gray)
        }
    }

    private func makeRink() -> Entity {
        let rink = Entity()
        let ice = ModelEntity(
            mesh: .generateCylinder(height: 0.08, radius: 4.3),
            materials: [material(UIColor(red: 0.95, green: 0.99, blue: 1, alpha: 1))]
        )
        ice.position.y = -0.04
        rink.addChild(ice)
        addRing(to: rink, radius: 4.25, height: 0.14, thickness: 0.1, color: .white)
        addRing(to: rink, radius: 4.25, height: 0.025, thickness: 0.13, color: UIColor(red: 0.55, green: 0.54, blue: 0.85, alpha: 1))
        addRing(to: rink, radius: 1.15, height: 0.005, thickness: 0.025, color: UIColor(red: 0.69, green: 0.8, blue: 0.92, alpha: 1))
        return rink
    }

    private func addRing(to parent: Entity, radius: Float, height: Float, thickness: Float, color: UIColor) {
        let segments = 72
        let length = 2 * Float.pi * radius / Float(segments)
        let mesh = MeshResource.generateBox(size: [length + 0.01, height, thickness])
        let ringMaterial = material(color)
        for segment in 0..<segments {
            let angle = Float(segment) * 2 * .pi / Float(segments)
            let part = ModelEntity(mesh: mesh, materials: [ringMaterial])
            part.position = [radius * sin(angle), height / 2 - 0.025, radius * cos(angle)]
            part.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
            parent.addChild(part)
        }
    }

    private func addBone(_ name: String, length: Float, radius: Float, color: UIColor) {
        let entity = ModelEntity(mesh: .generateSphere(radius: 1), materials: [material(color)])
        entity.scale = [radius, length / 2, radius]
        bones[name] = entity
        articulatedSkater.addChild(entity)
    }

    private func addJoint(_ name: String, mesh: MeshResource, color: UIColor) {
        let entity = ModelEntity(mesh: mesh, materials: [material(color)])
        joints[name] = entity
        articulatedSkater.addChild(entity)
    }

    private func setBone(_ name: String, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        guard let entity = bones[name] else { preconditionFailure("Missing rig bone: \(name)") }
        entity.position = (start + end) / 2
        entity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(end - start))
    }

    private func material(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.7, isMetallic: false)
    }
}
