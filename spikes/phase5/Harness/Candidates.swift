// Stands in for Shelf/Drag/ShakeSensitivity.swift so candidate thresholds can be compared without
// touching the product. Values come from the command line:
//   --set name=reversals,segment,window[,angle] ...
import CoreGraphics
import Foundation

struct ShakeSensitivity: Equatable {
    var rawValue: String
    var requiredReversals: Int
    var minimumSegmentLength: CGFloat
    var timeWindow: TimeInterval
    var reversalAngle: Double

    static var standard: ShakeSensitivity { allCases[0] }
    nonisolated(unsafe) static var allCases: [ShakeSensitivity] = parse()

    static func parse() -> [ShakeSensitivity] {
        let args = CommandLine.arguments
        var sets: [String] = []
        if let index = args.firstIndex(of: "--set") { sets = Array(args[(index + 1)...]) }
        if sets.isEmpty { sets = ["standard=4,24,0.6", "high=3,16,0.7", "highest=2,10,0.8"] }
        return sets.map { item in
            let parts = item.split(separator: "=")
            let v = parts[1].split(separator: ",").map { Double($0)! }
            return ShakeSensitivity(rawValue: String(parts[0]), requiredReversals: Int(v[0]), minimumSegmentLength: CGFloat(v[1]),
                                    timeWindow: v[2], reversalAngle: v.count > 3 ? v[3] : 120)
        }
    }
}
