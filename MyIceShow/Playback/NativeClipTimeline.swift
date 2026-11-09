import Foundation

struct NativeTimelineSample {
    let clipIndex: Int
    let nativeTime: Double
}

enum NativeClipTimeline {
    static func sample(clips: [RoutineClip], at showTime: Double, nativeDuration: Double) -> NativeTimelineSample? {
        guard nativeDuration.isFinite, nativeDuration > 0,
              let position = SkatingMotion.position(clips: clips, at: showTime) else { return nil }
        return NativeTimelineSample(
            clipIndex: position.clipIndex,
            nativeTime: min(max(position.localTime, 0), nativeDuration)
        )
    }
}
