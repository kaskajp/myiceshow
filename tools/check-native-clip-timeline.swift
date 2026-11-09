import Foundation

@main
struct NativeTimelineChecks {
    static func main() throws {
        let clips = [SkatingMove.glide, .threeTurn, .uprightSpin].map { RoutineClip(move: $0) }
        let cases: [(Double, Int, Double)] = [
            (-1, 0, 0), (0, 0, 0), (1, 0, 1), (2, 0, 2), (3, 0, 2),
            (4, 1, 0), (5, 1, 1), (7, 2, 0), (8, 2, 1), (11, 2, 2), (50, 2, 2)
        ]
        for (showTime, expectedIndex, expectedNativeTime) in cases {
            try check(clips: clips, showTime: showTime, index: expectedIndex, nativeTime: expectedNativeTime)
        }
        print("PASS: native 1x timing, end holds, slot boundaries, and clamped show endpoints")

        for showTime in [1.0, 5, 8, 1, 4, 11, 0, 5] {
            let first = NativeClipTimeline.sample(clips: clips, at: showTime, nativeDuration: 2)
            _ = NativeClipTimeline.sample(clips: clips, at: 11 - showTime, nativeDuration: 2)
            let repeated = NativeClipTimeline.sample(clips: clips, at: showTime, nativeDuration: 2)
            guard first?.clipIndex == repeated?.clipIndex, first?.nativeTime == repeated?.nativeTime else {
                throw CheckFailure.failed("Mapping depends on previous seeks")
            }
        }
        print("PASS: out-of-order and repeated show seeks are stateless")

        var edited = clips
        edited[0].duration = 5
        try check(clips: edited, showTime: 4, index: 0, nativeTime: 2)
        try check(clips: edited, showTime: 5, index: 1, nativeTime: 0)
        try check(clips: edited, showTime: 6, index: 1, nativeTime: 1)
        edited.swapAt(0, 1)
        try check(clips: edited, showTime: 3, index: 1, nativeTime: 0)
        try check(clips: edited, showTime: 4, index: 1, nativeTime: 1)
        print("PASS: duration edits and reordering move the native windows")

        guard NativeClipTimeline.sample(clips: [], at: 0, nativeDuration: 2) == nil,
              NativeClipTimeline.sample(clips: clips, at: .nan, nativeDuration: 2) == nil,
              NativeClipTimeline.sample(clips: clips, at: .infinity, nativeDuration: 2) == nil,
              NativeClipTimeline.sample(clips: clips, at: 0, nativeDuration: 0) == nil,
              NativeClipTimeline.sample(clips: clips, at: 0, nativeDuration: .infinity) == nil else {
            throw CheckFailure.failed("Empty or invalid timeline produced a native sample")
        }
        print("PASS: empty routines and invalid times do not invent a clip")

        let before = NativeClipTimeline.sample(clips: clips, at: 4.0.nextDown, nativeDuration: 2)
        guard before?.clipIndex == 0, before?.nativeTime == 2 else {
            throw CheckFailure.failed("Slot switched before its exact boundary")
        }
        print("PASS: the final representable instant before a boundary stays in its slot")
    }

    private static func check(clips: [RoutineClip], showTime: Double, index: Int, nativeTime: Double) throws {
        guard let sample = NativeClipTimeline.sample(clips: clips, at: showTime, nativeDuration: 2),
              sample.clipIndex == index, abs(sample.nativeTime - nativeTime) < 0.00001,
              SkatingMotion.sample(clips: clips, at: showTime).clipID == clips[index].id else {
            throw CheckFailure.failed("Incorrect native sample at show time \(showTime)")
        }
    }

    enum CheckFailure: Error {
        case failed(String)
    }
}
