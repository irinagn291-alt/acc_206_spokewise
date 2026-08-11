import Foundation

/// The three figures pinned under the map.
public struct RimReadout: Sendable, Hashable {
    public let meanKgf: Double
    public let spreadPercent: Double
    public let dishMm: Double

    public init(meanKgf: Double, spreadPercent: Double, dishMm: Double) {
        self.meanKgf = meanKgf
        self.spreadPercent = spreadPercent
        self.dishMm = dishMm
    }
}

/// Mean / spread / dish, plus the nav-bar title. Nothing here touches storage.
public enum RimReadoutMath: Sendable {

    /// Mean working tension across the spokes that have actually been read.
    public static func meanTension(_ samples: [RimSample]) -> Double {
        let measured = samples.filter(\.isMeasured).map(\.tensionKgf)
        let pool = measured.isEmpty ? samples.map(\.tensionKgf) : measured
        guard !pool.isEmpty else { return 0 }
        return pool.reduce(0, +) / Double(pool.count)
    }

    /// Half the peak-to-peak tension as a percentage of the mean, which is the
    /// ± figure wheelbuilders quote for a build's evenness.
    public static func spreadPercent(_ samples: [RimSample]) -> Double {
        let measured = samples.filter(\.isMeasured).map(\.tensionKgf)
        let pool = measured.isEmpty ? samples.map(\.tensionKgf) : measured
        guard pool.count > 1 else { return 0 }
        let mean = pool.reduce(0, +) / Double(pool.count)
        guard mean > 0.0001, let low = pool.min(), let high = pool.max() else { return 0 }
        return round(((high - low) / 2 / mean) * 100 * 10) / 10
    }

    /// The plane the rim is actually sitting in: the mean lateral offset.
    /// Variation about this figure is runout, not dish.
    public static func dishMm(_ samples: [RimSample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let mean = samples.map(\.lateralMm).reduce(0, +) / Double(samples.count)
        return round(mean * 10) / 10
    }

    public static func readout(_ samples: [RimSample]) -> RimReadout {
        RimReadout(
            meanKgf: round(meanTension(samples) * 10) / 10,
            spreadPercent: spreadPercent(samples),
            dishMm: dishMm(samples)
        )
    }

    /// Reduces a workshop wheel name to the "Rear · 32h" form the nav bar uses.
    public static func rimTitle(name: String, spokeCount: Int) -> String {
        let words = name.split(separator: " ").map(String.init)
        let position = words.first { $0.caseInsensitiveCompare("rear") == .orderedSame
            || $0.caseInsensitiveCompare("front") == .orderedSame }
        let lead = position ?? words.first ?? "Wheel"
        return "\(lead.capitalized) · \(max(spokeCount, 0))h"
    }

    /// Formatted trio, so both the hero and the thumbnails read identically.
    public static func format(_ readout: RimReadout) -> (mean: String, spread: String, dish: String) {
        (
            mean: "\(Int(readout.meanKgf.rounded())) kgf",
            spread: "±\(Int(readout.spreadPercent.rounded()))%",
            dish: String(format: "%.1f mm", readout.dishMm)
        )
    }
}
