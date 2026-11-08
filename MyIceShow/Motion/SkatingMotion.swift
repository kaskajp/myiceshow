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
    var shape: Float = 0
    var move: SkatingMove = .glide
    var clipID: UUID?
}

enum SkatingMotion {
    static let maximumDuration: Double = 60
    static let maximumClipDuration: Double = 8
    static let jumpFlightDuration: Double = 0.6
    static let pathRadius: Double = 3.2

    static func duration(of clips: [RoutineClip]) -> Double {
        clips.reduce(0) { $0 + $1.duration }
    }

    static func sample(clips: [RoutineClip], at time: Double) -> MotionSample {
        let elapsed = min(max(time, 0), duration(of: clips))
        var startTime: Double = 0
        var distance: Double = 0
        var rotation: Double = 0

        for clip in clips {
            let endTime = startTime + clip.duration
            if elapsed < endTime {
                return sample(
                    clip: clip,
                    localTime: elapsed - startTime,
                    distance: distance,
                    rotation: rotation
                )
            }
            startTime = endTime
            distance += clip.move.travel
            rotation += setupRotation(for: clip.move, after: rotation) + clip.move.rotation
        }

        var result = rootSample(distance: distance, rotation: rotation)
        result.clipID = clips.last?.id
        result.move = clips.last?.move ?? .glide
        return result
    }

    private static func sample(
        clip: RoutineClip,
        localTime: Double,
        distance: Double,
        rotation: Double
    ) -> MotionSample {
        let progress = localTime / clip.duration
        let travel = eased(progress)
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

    private static func eased(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
    }
}
