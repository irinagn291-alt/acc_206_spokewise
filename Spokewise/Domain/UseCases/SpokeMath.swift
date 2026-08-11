import Foundation

/// Pure wheel-building calculators for Spokewise.
public enum SpokeMath: Sendable {

    /// Spoke length geometry for both sides to tenths of a millimetre.
    public static func spokeLength(
        erdMm: Double,
        flangeDiameterMm: Double,
        leftOffsetMm: Double,
        rightOffsetMm: Double,
        spokeHoleMm: Double,
        spokeCount: Int,
        cross: Int
    ) -> SpokeLengthResult {
        let left = length(erd: erdMm, flange: flangeDiameterMm, offset: leftOffsetMm, hole: spokeHoleMm, count: spokeCount, cross: cross)
        let right = length(erd: erdMm, flange: flangeDiameterMm, offset: rightOffsetMm, hole: spokeHoleMm, count: spokeCount, cross: cross)
        return SpokeLengthResult(leftMm: roundTenth(left), rightMm: roundTenth(right))
    }

    private static func length(erd: Double, flange: Double, offset: Double, hole: Double, count: Int, cross: Int) -> Double {
        let r1 = erd / 2
        let r2 = flange / 2
        let angle = 2 * Double.pi * Double(cross) / Double(max(count, 1))
        let a = r1 * r1 + r2 * r2 + offset * offset - 2 * r1 * r2 * cos(angle)
        return sqrt(max(0, a)) - hole / 2
    }

    private static func roundTenth(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    /// Interpolate tensiometer deflection → kgf from a calibration table.
    public static func kgf(deflection: Double, table: [(Double, Double)]) -> Double {
        let sorted = table.sorted { $0.0 < $1.0 }
        guard let first = sorted.first else { return 0 }
        if deflection <= first.0 { return first.1 }
        if let last = sorted.last, deflection >= last.0 { return last.1 }
        for i in 1..<sorted.count {
            let a = sorted[i - 1], b = sorted[i]
            if deflection <= b.0 {
                let t = (deflection - a.0) / max(0.0001, b.0 - a.0)
                return a.1 + t * (b.1 - a.1)
            }
        }
        return sorted.last?.1 ?? 0
    }

    public static func tensionBalance(drive: [Double], nonDrive: [Double], dishImpliedRatio: Double = 1.15) -> SpokeTensionBalance {
        let all = drive + nonDrive
        let mean = all.isEmpty ? 0 : all.reduce(0, +) / Double(all.count)
        let sd: Double = {
            guard all.count > 1 else { return 0 }
            let var_ = all.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(all.count - 1)
            return sqrt(var_)
        }()
        let minV = all.min() ?? 0
        let maxV = all.max() ?? 0
        let spread = mean == 0 ? 0 : ((maxV - minV) / mean) * 100
        let dMean = drive.isEmpty ? 0 : drive.reduce(0, +) / Double(drive.count)
        let ndMean = nonDrive.isEmpty ? 0 : nonDrive.reduce(0, +) / Double(nonDrive.count)
        let ratio = ndMean == 0 ? 0 : dMean / ndMean
        _ = dishImpliedRatio
        return SpokeTensionBalance(mean: roundTenth(mean), sd: roundTenth(sd), spreadPercent: roundTenth(spread), driveToNonDrive: roundTenth(ratio))
    }

    /// Dish / centring error in mm from flange offsets and rim width assumption.
    public static func dishErrorMm(leftOffset: Double, rightOffset: Double, hubWidth: Double = 100) -> Double {
        let idealLeft = hubWidth / 2
        let centre = (leftOffset + (hubWidth - rightOffset)) / 2
        return roundTenth(centre - idealLeft)
    }

    /// First harmonic amplitude from equally spaced runout samples.
    public static func firstHarmonicAmplitude(samples: [Double]) -> Double {
        let n = samples.count
        guard n >= 4 else { return 0 }
        var re = 0.0, im = 0.0
        for (i, y) in samples.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(n)
            re += y * cos(angle)
            im += y * sin(angle)
        }
        return roundTenth(2 * sqrt(re * re + im * im) / Double(n))
    }

    public static func runoutAmplitude(samples: [Double]) -> Double {
        guard let minV = samples.min(), let maxV = samples.max() else { return 0 }
        return roundTenth(maxV - minV)
    }

    /// Fatigue exposure 0…100 from mileage and mean working tension.
    public static func fatigueExposure(km: Double, meanTensionKgf: Double, spokeCount: Int) -> Double {
        let tensionFactor = max(0.5, meanTensionKgf / 100)
        let raw = (km / 5000) * tensionFactor * (32.0 / Double(max(spokeCount, 1))) * 40
        return min(100, max(0, roundTenth(raw)))
    }
}
