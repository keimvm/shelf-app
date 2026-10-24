import CoreGraphics
import Foundation

/// Detects a shake from timestamped cursor positions (F3).
///
/// Movement is split into segments of at least `minimumSegmentLength`. While the cursor keeps going
/// the way of the last segment, the segment's end follows it, so the next segment starts where the
/// cursor turned. When the direction of a segment turns by more than `reversalAngle` from the
/// previous one, that is a reversal, in any direction. A shake is reported once `requiredReversals`
/// reversals fall within `timeWindow`.
/// It fires at most once until `reset()` (one shake per drag).
///
/// Time is passed in by the caller, so the detector has no clock or UI dependency.
struct ShakeDetector {
    var sensitivity: ShakeSensitivity

    private var anchor: CGPoint?
    private var lastDirection: CGVector?
    private var reversalTimes: [TimeInterval] = []
    private(set) var hasFired = false

    init(sensitivity: ShakeSensitivity = .standard) {
        self.sensitivity = sensitivity
    }

    /// Adds a cursor sample. Returns `true` only for the sample that completes a shake.
    mutating func add(_ point: CGPoint, at time: TimeInterval) -> Bool {
        guard !hasFired else { return false }
        guard let anchor else {
            self.anchor = point
            return false
        }

        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        // Still heading the same way: move the anchor along, so it ends up at the turning point.
        // Otherwise a swing shorter than two segments can leave the anchor between both ends.
        if let lastDirection, dx * lastDirection.dx + dy * lastDirection.dy > 0 {
            self.anchor = point
            return false
        }
        let length = hypot(dx, dy)
        guard length >= sensitivity.minimumSegmentLength else { return false }

        let direction = CGVector(dx: dx / length, dy: dy / length)
        let previous = lastDirection
        self.anchor = point
        lastDirection = direction

        guard let previous else { return false }
        let cosine = Double(direction.dx * previous.dx + direction.dy * previous.dy)
        guard cosine < cos(sensitivity.reversalAngle * .pi / 180) else { return false }

        reversalTimes.append(time)
        reversalTimes.removeAll { time - $0 > sensitivity.timeWindow }
        guard reversalTimes.count >= sensitivity.requiredReversals else { return false }

        hasFired = true
        return true
    }

    /// Clears all state. Call when a drag ends.
    mutating func reset() {
        anchor = nil
        lastDirection = nil
        reversalTimes.removeAll()
        hasFired = false
    }
}
