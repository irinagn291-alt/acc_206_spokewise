import Foundation

/// Turns measured spoke state into the rim-deviation figures the yellow
/// polygon plots. The lens decides what "deviation" means; the scaling that
/// fits it onto the map is shared.
public enum RimDeviationScale: Sendable {

    /// Deviation per spoke in the lens' own unit.
    ///
    /// Tension reads as how far the rim is drawn towards the hub, so a spoke
    /// tighter than the mean produces a negative figure. Dish reads lateral
    /// wander about the plane the wheel is actually dished to, not about zero.
    /// True reads whichever of radial or lateral runout is further out at that
    /// spoke, keeping that reading's sign.
    public static func raw(samples: [RimSample], lens: RimLens) -> [Double] {
        switch lens {
        case .tension:
            let mean = RimReadoutMath.meanTension(samples)
            return samples.map { mean - $0.tensionKgf }
        case .dish:
            let plane = RimReadoutMath.dishMm(samples)
            return samples.map { $0.lateralMm - plane }
        case .trueness:
            return samples.map { abs($0.radialMm) >= abs($0.lateralMm) ? $0.radialMm : $0.lateralMm }
        }
    }

    /// Scale deviations onto −1…1 by their own peak, so a well-built wheel
    /// still shows its shape instead of collapsing onto the circle.
    public static func normalized(_ raw: [Double]) -> [Double] {
        let peak = raw.map { abs($0) }.max() ?? 0
        guard peak > 0.0001 else { return raw.map { _ in 0 } }
        return raw.map { $0 / peak }
    }

    public static func normalized(samples: [RimSample], lens: RimLens) -> [Double] {
        normalized(raw(samples: samples, lens: lens))
    }

    /// Peak deviation in the lens' unit, shown beside the map so the reader
    /// knows what one ring of the polygon's swing is worth.
    public static func peak(samples: [RimSample], lens: RimLens) -> Double {
        let peak = raw(samples: samples, lens: lens).map { abs($0) }.max() ?? 0
        return (peak * 100).rounded() / 100
    }

    /// Spokes far enough off the mean to want the wrench next.
    public static func outliers(samples: [RimSample], lens: RimLens, threshold: Double = 0.75) -> [Int] {
        let scaled = normalized(samples: samples, lens: lens)
        return zip(samples, scaled).filter { abs($0.1) >= threshold }.map { $0.0.index }
    }
}
