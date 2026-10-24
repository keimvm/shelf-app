import CoreGraphics
import Foundation

/// Shake sensitivity levels (F1, F3). Higher levels need fewer or shorter swings and accept slower
/// ones. Every level needs at least three reversals, because aiming at a drop target (overshoot, back,
/// nudge forward) often makes two. Values were tuned in Phase 5 (verification.md §3).
enum ShakeSensitivity: String, CaseIterable, Sendable {
    case standard
    case high
    case highest

    var title: String {
        switch self {
        case .standard: "標準"
        case .high: "高"
        case .highest: "最高"
        }
    }

    /// Direction reversals needed within `timeWindow`.
    var requiredReversals: Int {
        switch self {
        case .standard: 4
        case .high: 3
        case .highest: 3
        }
    }

    /// Minimum cursor travel (points) before a movement counts as a segment with a direction.
    var minimumSegmentLength: CGFloat {
        switch self {
        case .standard: 24
        case .high: 24
        case .highest: 20
        }
    }

    /// How far back (seconds) reversals are counted.
    var timeWindow: TimeInterval {
        switch self {
        case .standard: 0.9
        case .high: 0.8
        case .highest: 1.1
        }
    }

    /// Minimum turn between consecutive segments (degrees) that counts as a reversal.
    var reversalAngle: Double { 120 }
}
