// Phase 5 harness: feeds synthetic cursor traces into the product ShakeDetector (compiled from
// Shelf/Drag) and reports which sensitivities fire. Deterministic (seeded noise). Test code.
//
//   harness [--values file]   prints a hit table for intentional shakes and a list of ordinary drags

import CoreGraphics
import Foundation

struct Sample { let point: CGPoint; let time: TimeInterval }

/// Small deterministic RNG so every run gives the same traces.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class Trace {
    var samples: [Sample] = []
    var point = CGPoint(x: 1000, y: 700)
    var time: TimeInterval = 0
    var rng: SplitMix
    let hz: Double
    var noise: Double

    init(seed: UInt64, hz: Double = Double(ProcessInfo.processInfo.environment["HZ"] ?? "120")!, noise: Double = 1.5) {
        rng = SplitMix(state: seed)
        self.hz = hz
        self.noise = noise
        samples.append(Sample(point: point, time: time))
    }

    private func jitter() -> CGFloat { noise > 0 ? CGFloat(Double.random(in: -noise...noise, using: &rng)) : 0 }

    /// Moves to `target` over `duration` with eased motion (slow at both ends, like a hand).
    func move(to target: CGPoint, duration: TimeInterval) {
        let start = point
        let steps = max(Int(duration * hz), 1)
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let eased = CGFloat((1 - cos(t * .pi)) / 2)
            time += 1 / hz
            let p = CGPoint(x: start.x + (target.x - start.x) * eased + jitter(), y: start.y + (target.y - start.y) * eased + jitter())
            samples.append(Sample(point: p, time: time))
        }
        point = target
    }

    func moveBy(_ dx: CGFloat, _ dy: CGFloat, duration: TimeInterval) {
        move(to: CGPoint(x: point.x + dx, y: point.y + dy), duration: duration)
    }

    func pause(_ duration: TimeInterval) {
        let steps = Int(duration * hz)
        for _ in 0..<steps {
            time += 1 / hz
            samples.append(Sample(point: CGPoint(x: point.x + jitter(), y: point.y + jitter()), time: time))
        }
    }

    /// `count` half cycles of length `amplitude` along `angle`, each taking `swing` seconds.
    /// Amplitude and timing vary by `variation` (fraction) per swing.
    func shake(amplitude: Double, swing: TimeInterval, count: Int, angle: Double = 0, variation: Double = 0.2) {
        let ux = cos(angle * .pi / 180), uy = sin(angle * .pi / 180)
        var sign = 1.0
        for index in 0..<count {
            let a = amplitude * (index == 0 ? 0.5 : 1) * Double.random(in: (1 - variation)...(1 + variation), using: &rng)
            let d = swing * (index == 0 ? 0.6 : 1) * Double.random(in: (1 - variation)...(1 + variation), using: &rng)
            // Hands drift sideways a little while shaking.
            let drift = Double.random(in: -0.15...0.15, using: &rng) * a
            moveBy(CGFloat(sign * a * ux - drift * uy), CGFloat(sign * a * uy + drift * ux), duration: d)
            sign = -sign
        }
    }
}

func fires(_ trace: Trace, _ sensitivity: ShakeSensitivity) -> Bool {
    var detector = ShakeDetector(sensitivity: sensitivity)
    return trace.samples.contains { detector.add($0.point, at: $0.time) }
}

let levels = ShakeSensitivity.allCases
let seeds: [UInt64] = Array(1...20)

/// Share of seeds (0...1) that fire for a trace builder.
func rate(_ sensitivity: ShakeSensitivity, _ build: (Trace) -> Void) -> Double {
    let hits = seeds.filter { seed in
        let trace = Trace(seed: seed)
        trace.moveBy(300, 120, duration: 0.5) // carry the item away from its source first
        build(trace)
        return fires(trace, sensitivity)
    }.count
    return Double(hits) / Double(seeds.count)
}

func cell(_ value: Double) -> String { value >= 0.95 ? "  ●" : value <= 0.05 ? "  ·" : String(format: "%3d", Int(value * 100)) }

print("== Intentional shakes: hit rate per level (● ≥95%, · ≤5%, else %) ==")
print("rows: amplitude pt / swing ms; columns: half cycles 3 4 5 6 8")
let amplitudes: [Double] = [30, 50, 80, 120, 200]
let swings: [Double] = [0.08, 0.12, 0.18, 0.25, 0.35, 0.5]
let counts = [3, 4, 5, 6, 8]
for level in levels {
    print("-- \(level.rawValue)")
    for amplitude in amplitudes {
        var line = String(format: "%4.0fpt ", amplitude)
        for swing in swings {
            line += String(format: " %3.0fms", swing * 1000)
            for count in counts {
                line += cell(rate(level) { $0.shake(amplitude: amplitude, swing: swing, count: count, angle: Double.random(in: -30...30)) })
            }
            line += " |"
        }
        print(line)
    }
}

print("\n== Ordinary drags: false-positive rate per level ==")
typealias Case = (String, (Trace) -> Void)
let ordinary: [Case] = [
    ("straight 600pt in 0.6s", { $0.moveBy(600, -200, duration: 0.6) }),
    ("L-shaped path (90° turns)", { t in t.moveBy(400, 0, duration: 0.4); t.moveBy(0, 300, duration: 0.3); t.moveBy(-300, 0, duration: 0.3) }),
    ("aim: overshoot 40pt and back", { t in t.moveBy(500, 0, duration: 0.45); t.moveBy(-40, 0, duration: 0.18); t.pause(0.2) }),
    ("aim: overshoot, back, nudge forward", { t in t.moveBy(500, 0, duration: 0.45); t.moveBy(-40, 0, duration: 0.18); t.moveBy(15, 0, duration: 0.12); t.pause(0.2) }),
    ("aim: two small corrections ±20pt", { t in t.moveBy(500, 50, duration: 0.45); t.moveBy(-25, 0, duration: 0.15); t.moveBy(20, 0, duration: 0.15); t.moveBy(-12, 0, duration: 0.12) }),
    ("hover over list, wiggle ±15pt ×3", { t in for _ in 0..<3 { t.moveBy(0, 40, duration: 0.25); t.moveBy(15, 0, duration: 0.1); t.moveBy(-15, 0, duration: 0.1) } }),
    ("change mind: go, return, go (0.4s each)", { t in t.moveBy(400, 0, duration: 0.4); t.moveBy(-400, 0, duration: 0.4); t.moveBy(400, 0, duration: 0.4) }),
    ("change mind fast: 300pt ×3 (0.25s each)", { t in t.moveBy(300, 0, duration: 0.25); t.moveBy(-300, 0, duration: 0.25); t.moveBy(300, 0, duration: 0.25) }),
    ("circle r=80 in 0.8s", { t in let c = t.point; for i in 1...24 { let a = Double(i) / 24 * 2 * .pi; t.move(to: CGPoint(x: c.x + 80 * (cos(a) - 1), y: c.y + 80 * sin(a)), duration: 0.8 / 24) } }),
    ("tremor while holding still (noise ±6pt)", { t in t.noise = 6; t.pause(1.5) }),
    ("slow scrub ±60pt ×4 at 0.5s/swing", { $0.shake(amplitude: 60, swing: 0.5, count: 4, variation: 0.1) }),
    ("aim: three corrections 30/20/15pt", { t in t.moveBy(500, 0, duration: 0.45); t.moveBy(-30, 0, duration: 0.16); t.moveBy(20, 0, duration: 0.14); t.moveBy(-15, 0, duration: 0.12); t.pause(0.2) }),
    ("dither between targets 100pt ×4 (0.35s)", { t in for i in 0..<4 { t.moveBy(i % 2 == 0 ? 100 : -100, 0, duration: 0.35) } }),
    ("scan folders: down 60pt + side ±40pt ×4", { t in for i in 0..<4 { t.moveBy(i % 2 == 0 ? 40 : -40, 60, duration: 0.3) } }),
    ("drag to screen edge, bounce back 30pt", { t in t.moveBy(800, 0, duration: 0.5); t.moveBy(-30, 10, duration: 0.15); t.moveBy(30, 0, duration: 0.2) }),
]
print("case".padding(toLength: 42, withPad: " ", startingAt: 0) + levels.map { $0.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0) }.joined())
for (name, build) in ordinary {
    print(name.padding(toLength: 42, withPad: " ", startingAt: 0) + levels.map { "\(Int(rate($0, build) * 100))%".padding(toLength: 9, withPad: " ", startingAt: 0) }.joined())
}
