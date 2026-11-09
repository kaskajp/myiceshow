import Foundation
import simd

enum SkatingMove: String, CaseIterable, Identifiable, Codable {
    case glide
    case threeTurn
    case uprightSpin
    case waltzJump
    case lunge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glide: "Glide"
        case .threeTurn: "Three-turn"
        case .uprightSpin: "Upright spin"
        case .waltzJump: "Waltz jump"
        case .lunge: "Lunge"
        }
    }

    var symbol: String {
        switch self {
        case .glide: "wind"
        case .threeTurn: "arrow.turn.up.left"
        case .uprightSpin: "arrow.trianglehead.2.clockwise.rotate.90"
        case .waltzJump: "sparkles"
        case .lunge: "figure.flexibility"
        }
    }

    var defaultDuration: Double {
        switch self {
        case .glide, .uprightSpin, .lunge: 4
        case .threeTurn, .waltzJump: 3
        }
    }

    var minimumDuration: Double {
        switch self {
        case .glide: 2
        case .threeTurn, .waltzJump: 2.5
        case .uprightSpin, .lunge: 3
        }
    }

    var travel: Double {
        switch self {
        case .glide: 2.8
        case .threeTurn: 1.5
        case .uprightSpin: 0
        case .waltzJump: 2
        case .lunge: 2.2
        }
    }

    var rotation: Double {
        switch self {
        case .threeTurn, .waltzJump: .pi
        case .uprightSpin: 6 * .pi
        case .glide, .lunge: 0
        }
    }
}

struct RoutineClip: Identifiable, Codable, Equatable {
    let id: UUID
    let move: SkatingMove
    var duration: Double

    init(move: SkatingMove) {
        id = UUID()
        self.move = move
        duration = move.defaultDuration
    }
}

struct MotionSample {
    var position: SIMD3<Float> = .zero
    var yaw: Float = 0
    var entryYaw: Float = 0
    var shape: Float = 0
    var move: SkatingMove = .glide
    var clipID: UUID?
}

struct RoutinePosition {
    let clipIndex: Int
    let localTime: Double
}

enum SkatingMotion {
    static let maximumDuration: Double = 60
    static let maximumClipDuration: Double = 8
    static let jumpFlightDuration: Double = 0.6
    static let pathRadius: Double = 3.2

    static func duration(of clips: [RoutineClip]) -> Double {
        clips.reduce(0) { $0 + $1.duration }
    }

    static func position(clips: [RoutineClip], at time: Double) -> RoutinePosition? {
        guard time.isFinite else { return nil }
        let elapsed = min(max(time, 0), duration(of: clips))
        var startTime: Double = 0
        for (index, clip) in clips.enumerated() {
            let endTime = startTime + clip.duration
            if elapsed < endTime || index == clips.count - 1 {
                return RoutinePosition(clipIndex: index, localTime: elapsed - startTime)
            }
            startTime = endTime
        }
        return nil
    }

    static func sample(clips: [RoutineClip], at time: Double) -> MotionSample {
        guard let position = position(clips: clips, at: time) else {
            return rootSample(distance: 0, rotation: 0)
        }
        var distance: Double = 0
        var rotation: Double = 0
        for clip in clips.prefix(position.clipIndex) {
            distance += clip.move.travel
            rotation += setupRotation(for: clip.move, after: rotation) + clip.move.rotation
        }
        let index = position.clipIndex
        return sample(
            clip: clips[index], localTime: position.localTime,
            distance: distance, rotation: rotation,
            entrySpeed: index == 0 ? 0 : boundarySpeed(clips[index - 1], clips[index]),
            exitSpeed: index + 1 == clips.count ? 0 : boundarySpeed(clips[index], clips[index + 1])
        )
    }

    private static func sample(
        clip: RoutineClip,
        localTime: Double,
        distance: Double,
        rotation: Double,
        entrySpeed: Double,
        exitSpeed: Double
    ) -> MotionSample {
        let progress = localTime / clip.duration
        let travel = travelProgress(
            progress, distance: clip.move.travel, duration: clip.duration,
            entrySpeed: entrySpeed, exitSpeed: exitSpeed
        )
        let rotationProgress = clip.move == .waltzJump
            ? flightProgress(localTime: localTime, duration: clip.duration)
            : eased(progress)
        let setup = setupRotation(for: clip.move, after: rotation)
        let takeoff = (clip.duration - jumpFlightDuration) / 2
        let setupProgress = setup == 0 ? 0 : eased(min(localTime / takeoff, 1))
        var result = rootSample(
            distance: distance + clip.move.travel * travel,
            rotation: rotation + setup * setupProgress + clip.move.rotation * rotationProgress
        )
        result.entryYaw = rootSample(distance: distance, rotation: rotation).yaw
        result.shape = Float(pow(sin(.pi * progress), 2))
        result.move = clip.move
        result.clipID = clip.id

        if clip.move == .waltzJump {
            result.position.y = Float(2.4 * rotationProgress * (1 - rotationProgress))
        }
        return result
    }

    private static func rootSample(distance: Double, rotation: Double) -> MotionSample {
        let angle = -0.9 + distance / pathRadius
        return MotionSample(
            position: SIMD3(Float(pathRadius * sin(angle)), 0, Float(pathRadius * cos(angle))),
            yaw: Float(angle + .pi / 2 + rotation)
        )
    }

    private static func flightProgress(localTime: Double, duration: Double) -> Double {
        let takeoff = (duration - jumpFlightDuration) / 2
        return min(max((localTime - takeoff) / jumpFlightDuration, 0), 1)
    }

    private static func setupRotation(for move: SkatingMove, after rotation: Double) -> Double {
        guard move == .waltzJump else { return 0 }
        return -atan2(sin(rotation), cos(rotation))
    }

    private static func boundarySpeed(_ first: RoutineClip, _ second: RoutineClip) -> Double {
        min(first.move.travel / first.duration, second.move.travel / second.duration)
    }

    private static func travelProgress(
        _ progress: Double, distance: Double, duration: Double,
        entrySpeed: Double, exitSpeed: Double
    ) -> Double {
        guard distance > 0 else { return 0 }
        let entryTangent = entrySpeed * duration / distance
        let exitTangent = exitSpeed * duration / distance
        let squared = progress * progress
        let cubed = squared * progress
        return 3 * squared - 2 * cubed
            + (cubed - 2 * squared + progress) * entryTangent
            + (cubed - squared) * exitTangent
    }

    private static func eased(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
    }
}
