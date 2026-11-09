import simd

struct LimbPose {
    let start: SIMD3<Float>
    let joint: SIMD3<Float>
    let end: SIMD3<Float>
}

struct SkaterPose {
    let leftLeg: LimbPose
    let rightLeg: LimbPose
    let leftArm: LimbPose
    let rightArm: LimbPose
    let pelvis: SIMD3<Float>
    let shoulders: SIMD3<Float>
    let head: SIMD3<Float>
}

enum SkaterRig {
    static let thighLength: Float = 0.5
    static let shinLength: Float = 0.48
    static let upperArmLength: Float = 0.27
    static let forearmLength: Float = 0.25
    static let torsoLength: Float = 0.5
    static let neckLength: Float = 0.12
    static let headOffset: Float = 0.22
    static let hipWidth: Float = 0.26
    static let shoulderWidth: Float = 0.46
    static let ankleHeight: Float = 0.08
    static let bladeOffset = SIMD3<Float>(0, -0.0675, 0.02)
    private static let neutralLeftAnkle = SIMD3<Float>(-0.14, ankleHeight, 0)
    private static let bladeContactOffset = SIMD3<Float>(0, -ankleHeight, bladeOffset.z)

    static func rootPosition(for sample: MotionSample, pose: SkaterPose) -> SIMD3<Float> {
        guard sample.move == .uprightSpin else { return sample.position }
        let entryOrientation = simd_quatf(angle: sample.entryYaw, axis: [0, 1, 0])
        let orientation = simd_quatf(angle: sample.yaw, axis: [0, 1, 0])
        let anchor = entryOrientation.act(neutralLeftAnkle + bladeContactOffset)
        let contact = orientation.act(pose.leftLeg.end + bladeContactOffset)
        return sample.position + anchor - contact
    }

    static func pose(for sample: MotionSample) -> SkaterPose {
        let shape = sample.shape
        let crouch: Float = sample.move == .lunge ? 0.43 * shape : 0.06 * shape
        let lean: Float = sample.move == .lunge ? 0.4 * shape : 0.08 * shape
        let pelvis = SIMD3<Float>(0, 0.98 - crouch, 0)
        let shoulders = pelvis + SIMD3(0, cos(lean), sin(lean)) * torsoLength
        let hipLeft = pelvis + SIMD3(-hipWidth / 2, 0, 0)
        let hipRight = pelvis + SIMD3(hipWidth / 2, 0, 0)
        let shoulderLeft = shoulders + SIMD3(-shoulderWidth / 2, 0, 0)
        let shoulderRight = shoulders + SIMD3(shoulderWidth / 2, 0, 0)
        var ankleLeft = neutralLeftAnkle
        var ankleRight = SIMD3<Float>(0.14, ankleHeight, 0)

        switch sample.move {
        case .glide:
            ankleRight += SIMD3(0.08, 0.14, -0.4) * shape
        case .threeTurn:
            ankleRight += SIMD3(0.09, 0.16, -0.18) * shape
        case .uprightSpin:
            ankleLeft.x += 0.14 * shape
            ankleRight += SIMD3(-0.04, 0.27, -0.12) * shape
        case .waltzJump:
            ankleRight += SIMD3(0.04, 0.16, -0.22) * shape
        case .lunge:
            ankleLeft.z += 0.35 * shape
            ankleRight.z -= 0.85 * shape
        }

        let reach: Float = sample.move == .uprightSpin ? 0.45 - 0.28 * shape : 0.45
        let wristLeft = shoulderLeft + SIMD3<Float>(-reach, -0.16, 0.15 * shape)
        let wristRight = shoulderRight + SIMD3<Float>(reach, -0.16, 0.15 * shape)

        return SkaterPose(
            leftLeg: leg(from: hipLeft, to: ankleLeft),
            rightLeg: leg(from: hipRight, to: ankleRight),
            leftArm: arm(from: shoulderLeft, to: wristLeft),
            rightArm: arm(from: shoulderRight, to: wristRight),
            pelvis: pelvis,
            shoulders: shoulders,
            head: shoulders + SIMD3(0, headOffset, 0)
        )
    }

    private static func leg(from start: SIMD3<Float>, to end: SIMD3<Float>) -> LimbPose {
        solve(
            from: start, to: end, bendToward: [0, 0, 1],
            upperLength: thighLength, lowerLength: shinLength
        )
    }

    private static func arm(from start: SIMD3<Float>, to end: SIMD3<Float>) -> LimbPose {
        solve(
            from: start, to: end, bendToward: [0, -1, 0],
            upperLength: upperArmLength, lowerLength: forearmLength
        )
    }

    private static func solve(
        from start: SIMD3<Float>, to end: SIMD3<Float>, bendToward pole: SIMD3<Float>,
        upperLength: Float, lowerLength: Float
    ) -> LimbPose {
        let distance = simd_distance(start, end)
        precondition(distance > abs(upperLength - lowerLength) && distance <= upperLength + lowerLength,
                     "Authored pose target is outside the limb's reach")
        let axis = (end - start) / distance
        let bend = simd_normalize(pole - axis * simd_dot(pole, axis))
        let along = (upperLength * upperLength - lowerLength * lowerLength + distance * distance) / (2 * distance)
        let height = max(0, upperLength * upperLength - along * along).squareRoot()
        return LimbPose(start: start, joint: start + axis * along + bend * height, end: end)
    }
}
