import simd

struct SkaterJointTransform {
    let translation: SIMD3<Float>
    let rotation: simd_quatf
}

enum SkaterSkeleton {
    private static let identityRotation = simd_quatf(real: 1, imag: .zero)
    static let jointNames = [
        "pelvis", "pelvis/spine", "pelvis/spine/head",
        "pelvis/leftHip", "pelvis/leftHip/leftKnee", "pelvis/leftHip/leftKnee/leftAnkle",
        "pelvis/rightHip", "pelvis/rightHip/rightKnee", "pelvis/rightHip/rightKnee/rightAnkle",
        "pelvis/spine/leftShoulder", "pelvis/spine/leftShoulder/leftElbow",
        "pelvis/spine/leftShoulder/leftElbow/leftWrist",
        "pelvis/spine/rightShoulder", "pelvis/spine/rightShoulder/rightElbow",
        "pelvis/spine/rightShoulder/rightElbow/rightWrist"
    ]
    static let parentIndices: [Int?] = [nil, 0, 1, 0, 3, 4, 0, 6, 7, 1, 9, 10, 1, 12, 13]

    static func transforms(for pose: SkaterPose) -> [SkaterJointTransform] {
        let upright = simd_quatf(from: [0, 1, 0], to: simd_normalize(pose.shoulders - pose.pelvis))
        let world = [
            SkaterJointTransform(translation: pose.pelvis, rotation: identityRotation),
            SkaterJointTransform(translation: pose.shoulders, rotation: upright),
            SkaterJointTransform(translation: pose.head, rotation: upright)
        ] + limbTransforms(pose.leftLeg, restAxis: [0, -1, 0], keepsEndLevel: true)
            + limbTransforms(pose.rightLeg, restAxis: [0, -1, 0], keepsEndLevel: true)
            + limbTransforms(pose.leftArm, restAxis: [-1, 0, 0], keepsEndLevel: false)
            + limbTransforms(pose.rightArm, restAxis: [1, 0, 0], keepsEndLevel: false)

        return world.enumerated().map { index, transform in
            guard let parentIndex = parentIndices[index] else { return transform }
            let parent = world[parentIndex]
            return SkaterJointTransform(
                translation: parent.rotation.inverse.act(transform.translation - parent.translation),
                rotation: parent.rotation.inverse * transform.rotation
            )
        }
    }

    private static func limbTransforms(
        _ limb: LimbPose, restAxis: SIMD3<Float>, keepsEndLevel: Bool
    ) -> [SkaterJointTransform] {
        let upper = simd_quatf(from: restAxis, to: simd_normalize(limb.joint - limb.start))
        let lower = simd_quatf(from: restAxis, to: simd_normalize(limb.end - limb.joint))
        return [
            SkaterJointTransform(translation: limb.start, rotation: upper),
            SkaterJointTransform(translation: limb.joint, rotation: lower),
            SkaterJointTransform(translation: limb.end, rotation: keepsEndLevel ? identityRotation : lower)
        ]
    }
}
