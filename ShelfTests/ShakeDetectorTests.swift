import CoreGraphics
import Foundation
import Testing
@testable import Shelf

struct ShakeDetectorTests {
    private struct Sample {
        var point: CGPoint
        var time: TimeInterval
    }

    /// Back-and-forth strokes along `axis`, sampled `stepsPerStroke` times per stroke.
    /// `strokes` strokes contain `strokes - 1` reversals.
    private func zigzag(
        strokes: Int,
        amplitude: CGFloat = 80,
        axis: CGVector = CGVector(dx: 1, dy: 0),
        strokeDuration: TimeInterval = 0.08,
        stepsPerStroke: Int = 8,
        start: CGPoint = CGPoint(x: 500, y: 500),
        startTime: TimeInterval = 100
    ) -> [Sample] {
        var samples = [Sample(point: start, time: startTime)]
        var position: CGFloat = 0
        var time = startTime
        for stroke in 0..<strokes {
            let sign: CGFloat = stroke.isMultiple(of: 2) ? 1 : -1
            for _ in 0..<stepsPerStroke {
                position += sign * amplitude / CGFloat(stepsPerStroke)
                time += strokeDuration / Double(stepsPerStroke)
                let point = CGPoint(x: start.x + axis.dx * position, y: start.y + axis.dy * position)
                samples.append(Sample(point: point, time: time))
            }
        }
        return samples
    }

    /// Feeds samples and returns the indices at which the detector reported a shake.
    private func feed(_ samples: [Sample], to detector: inout ShakeDetector) -> [Int] {
        samples.indices.filter { detector.add(samples[$0].point, at: samples[$0].time) }
    }

    @Test func straightMovementIsNotAShake() {
        var detector = ShakeDetector()
        let samples = (0..<100).map { Sample(point: CGPoint(x: Double($0) * 10, y: 300), time: Double($0) * 0.01) }
        #expect(feed(samples, to: &detector).isEmpty)
    }

    @Test(arguments: ShakeSensitivity.allCases)
    func firesExactlyAtRequiredReversals(sensitivity: ShakeSensitivity) {
        var tooFew = ShakeDetector(sensitivity: sensitivity)
        #expect(feed(zigzag(strokes: sensitivity.requiredReversals), to: &tooFew).isEmpty)

        var enough = ShakeDetector(sensitivity: sensitivity)
        #expect(feed(zigzag(strokes: sensitivity.requiredReversals + 1), to: &enough).count == 1)
        #expect(enough.hasFired)
    }

    @Test(arguments: [
        CGVector(dx: 0, dy: 1),
        CGVector(dx: 0.7071, dy: 0.7071),
        CGVector(dx: -0.7071, dy: 0.7071),
    ])
    func directionDoesNotMatter(axis: CGVector) {
        var detector = ShakeDetector()
        #expect(feed(zigzag(strokes: 5, axis: axis), to: &detector).count == 1)
    }

    @Test func firesOnlyOncePerDrag() {
        var detector = ShakeDetector()
        #expect(feed(zigzag(strokes: 12), to: &detector).count == 1)
    }

    @Test func resetAllowsFiringAgain() {
        var detector = ShakeDetector()
        #expect(feed(zigzag(strokes: 5), to: &detector).count == 1)
        detector.reset()
        #expect(!detector.hasFired)
        #expect(feed(zigzag(strokes: 5, startTime: 200), to: &detector).count == 1)
    }

    @Test func slowShakeOutsideTimeWindowIsIgnored() {
        var detector = ShakeDetector()
        // Each stroke takes longer than the window, so reversals never accumulate.
        let slow = zigzag(strokes: 10, strokeDuration: ShakeSensitivity.standard.timeWindow * 1.1)
        #expect(feed(slow, to: &detector).isEmpty)
    }

    @Test func smallJitterIsIgnored() {
        var detector = ShakeDetector()
        let amplitude = ShakeSensitivity.standard.minimumSegmentLength / 2
        #expect(feed(zigzag(strokes: 20, amplitude: amplitude), to: &detector).isEmpty)
    }

    @Test func swingShorterThanTwoSegmentsStillCounts() {
        // After a 40pt approach, eased 30pt swings used to leave the anchor between both ends, where
        // neither end was a full segment away, so no reversal was ever counted.
        var samples = (1...20).map { Sample(point: CGPoint(x: 500 + 2 * Double($0), y: 500), time: 0.015 * Double($0)) }
        var time = 0.6
        var position = 0.0
        for stroke in 0..<8 {
            let target = stroke.isMultiple(of: 2) ? 15.0 : -15.0
            for step in 1...14 {
                let eased = (1 - cos(Double(step) / 14 * .pi)) / 2
                time += 1.0 / 120
                samples.append(Sample(point: CGPoint(x: 540 + position + (target - position) * eased, y: 500), time: time))
            }
            position = target
        }
        var detector = ShakeDetector(sensitivity: .highest)
        #expect(feed(samples, to: &detector).count == 1)
    }

    @Test func gentleCurveIsNotAShake() {
        var detector = ShakeDetector()
        // A full circle turns gradually; no single segment-to-segment turn exceeds the reversal angle.
        let samples = (0...120).map { i -> Sample in
            let angle = Double(i) / 120 * 2 * .pi
            return Sample(point: CGPoint(x: 500 + 150 * cos(angle), y: 500 + 150 * sin(angle)), time: Double(i) * 0.005)
        }
        #expect(feed(samples, to: &detector).isEmpty)
    }

    @Test func higherSensitivityFiresOnSmallerShake() {
        let samples = zigzag(strokes: 5, amplitude: 22)
        var standard = ShakeDetector(sensitivity: .standard)
        var highest = ShakeDetector(sensitivity: .highest)
        #expect(feed(samples, to: &standard).isEmpty)
        #expect(feed(samples, to: &highest).count == 1)
    }

    @Test func higherSensitivityFiresOnSlowerShake() {
        let samples = zigzag(strokes: 5, strokeDuration: 0.45)
        var standard = ShakeDetector(sensitivity: .standard)
        var highest = ShakeDetector(sensitivity: .highest)
        #expect(feed(samples, to: &standard).isEmpty)
        #expect(feed(samples, to: &highest).count == 1)
    }

    @Test(arguments: ShakeSensitivity.allCases)
    func aimingCorrectionIsNotAShake(sensitivity: ShakeSensitivity) {
        // Overshoot the target, come back, and nudge forward again: two quick reversals.
        var detector = ShakeDetector(sensitivity: sensitivity)
        var samples = [Sample(point: CGPoint(x: 100, y: 500), time: 0)]
        for (x, time) in [(600.0, 0.45), (560.0, 0.6), (585.0, 0.7)] {
            samples.append(Sample(point: CGPoint(x: x, y: 500), time: time))
        }
        #expect(feed(samples, to: &detector).isEmpty)
    }
}
