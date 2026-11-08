import RealityKit
import SwiftUI

struct RinkView: UIViewRepresentable {
    let sample: MotionSample
    let costume: CostumeColor

    func makeCoordinator() -> RinkRenderer {
        RinkRenderer()
    }

    func makeUIView(context: Context) -> ARView {
        context.coordinator.makeView()
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.update(sample: sample, costume: costume)
    }
}

@MainActor
final class RinkRenderer {
    private let skater = Entity()
    private let torso = ModelEntity()
    private var bones: [String: ModelEntity] = [:]
    private var joints: [String: ModelEntity] = [:]
    private var currentCostume: CostumeColor?

    func makeView() -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 0.88, green: 0.91, blue: 0.98, alpha: 1))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField]
        let world = AnchorEntity(world: .zero)
        world.addChild(makeRink())
        world.addChild(skater)
        makeSkater()

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 43
        camera.look(at: [0, 0.35, 0], from: [5.5, 5.8, 7.5], relativeTo: nil)
        world.addChild(camera)

        let light = DirectionalLight()
        light.light.intensity = 2_500
        light.look(at: .zero, from: [3, 8, 4], relativeTo: nil)
        world.addChild(light)
        view.scene.addAnchor(world)
        return view
    }

    func update(sample: MotionSample, costume: CostumeColor) {
        skater.position = sample.position
        skater.orientation = simd_quatf(angle: sample.yaw, axis: [0, 1, 0])
        if currentCostume != costume {
            torso.model?.materials = [material(costume.uiColor)]
            currentCostume = costume
        }

        let shape = sample.shape
        let crouch: Float = sample.move == .lunge ? 0.43 * shape : 0.06 * shape
        let hipHeight: Float = 0.98 - crouch
        let lean: Float = sample.move == .lunge ? 0.23 * shape : 0.04 * shape
        let hipLeft = SIMD3<Float>(-0.13, hipHeight, 0)
        let hipRight = SIMD3<Float>(0.13, hipHeight, 0)
        let shoulderLeft = SIMD3<Float>(-0.23, hipHeight + 0.49, lean)
        let shoulderRight = SIMD3<Float>(0.23, hipHeight + 0.49, lean)
        var ankleLeft = SIMD3<Float>(-0.14, 0.08, 0)
        var ankleRight = SIMD3<Float>(0.14, 0.08, 0)
        var kneeLeft = SIMD3<Float>(-0.14, hipHeight * 0.53, 0.05)
        var kneeRight = SIMD3<Float>(0.14, hipHeight * 0.53, 0.05)

        switch sample.move {
        case .glide:
            ankleRight += SIMD3(0.08, 0.14, -0.4) * shape
            kneeRight += SIMD3(0.03, 0.06, -0.12) * shape
        case .threeTurn:
            ankleRight += SIMD3(0.09, 0.16, -0.18) * shape
        case .uprightSpin:
            ankleLeft.x += 0.14 * shape
            ankleRight += SIMD3(-0.04, 0.27, -0.12) * shape
            kneeRight += SIMD3(0.05, 0.08, 0.1) * shape
        case .waltzJump:
            ankleRight += SIMD3(0.04, 0.16, -0.22) * shape
        case .lunge:
            ankleLeft.z += 0.35 * shape
            kneeLeft.z += 0.43 * shape
            ankleRight.z -= 0.85 * shape
            kneeRight.z -= 0.42 * shape
        }

        let armReach: Float = sample.move == .uprightSpin ? 0.45 - 0.28 * shape : 0.45
        let elbowLeft = shoulderLeft + SIMD3<Float>(-armReach * 0.55, -0.1, 0.06)
        let elbowRight = shoulderRight + SIMD3<Float>(armReach * 0.55, -0.1, 0.06)
        let wristLeft = shoulderLeft + SIMD3<Float>(-armReach, -0.16, 0.15 * shape)
        let wristRight = shoulderRight + SIMD3<Float>(armReach, -0.16, 0.15 * shape)

        setBone("leftThigh", from: hipLeft, to: kneeLeft)
        setBone("leftShin", from: kneeLeft, to: ankleLeft)
        setBone("rightThigh", from: hipRight, to: kneeRight)
        setBone("rightShin", from: kneeRight, to: ankleRight)
        setBone("leftUpperArm", from: shoulderLeft, to: elbowLeft)
        setBone("leftForearm", from: elbowLeft, to: wristLeft)
        setBone("rightUpperArm", from: shoulderRight, to: elbowRight)
        setBone("rightForearm", from: elbowRight, to: wristRight)
        setBone("body", from: [0, hipHeight, 0], to: [0, hipHeight + 0.5, lean])
        joints["head"]?.position = [0, hipHeight + 0.72, lean]
        joints["hair"]?.position = [0, hipHeight + 0.81, lean - 0.015]
        joints["bun"]?.position = [0, hipHeight + 0.83, lean - 0.13]
        joints["leftSkate"]?.position = ankleLeft
        joints["rightSkate"]?.position = ankleRight
        joints["leftBlade"]?.position = ankleLeft + [0, -0.065, 0.02]
        joints["rightBlade"]?.position = ankleRight + [0, -0.065, 0.02]
    }

    private func makeSkater() {
        let skin = UIColor(red: 0.77, green: 0.53, blue: 0.39, alpha: 1)
        let leggings = UIColor(red: 0.2, green: 0.22, blue: 0.34, alpha: 1)
        for name in ["leftThigh", "leftShin", "rightThigh", "rightShin"] {
            addBone(name, radius: 0.065, color: leggings)
        }
        for name in ["leftUpperArm", "leftForearm", "rightUpperArm", "rightForearm"] {
            addBone(name, radius: 0.045, color: skin)
        }
        torso.model = ModelComponent(mesh: .generateSphere(radius: 1), materials: [material(.systemPurple)])
        skater.addChild(torso)
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

    private func addBone(_ name: String, radius: Float, color: UIColor) {
        let entity = ModelEntity(mesh: .generateSphere(radius: 1), materials: [material(color)])
        entity.scale = [radius, 0.2, radius]
        bones[name] = entity
        skater.addChild(entity)
    }

    private func addJoint(_ name: String, mesh: MeshResource, color: UIColor) {
        let entity = ModelEntity(mesh: mesh, materials: [material(color)])
        joints[name] = entity
        skater.addChild(entity)
    }

    private func setBone(_ name: String, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        guard let entity = bones[name] else { return }
        entity.position = (start + end) / 2
        entity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(end - start))
        let radius: Float = name == "body" ? 0.2 : name.contains("Arm") || name.contains("Forearm") ? 0.045 : 0.065
        entity.scale = [radius, simd_distance(start, end) / 2, radius]
    }

    private func material(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.7, isMetallic: false)
    }
}
