import XCTest
@testable import Spokewise

final class SpokeMathTests: XCTestCase {
    func test_givenTypicalRoadGeometry_whenSpokeLength_thenTenthsPositive() {
        let r = SpokeMath.spokeLength(erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 17, rightOffsetMm: 34, spokeHoleMm: 2.6, spokeCount: 32, cross: 3)
        XCTAssertGreaterThan(r.leftMm, 250)
        XCTAssertGreaterThan(r.rightMm, 250)
        XCTAssertEqual(r.leftMm, (r.leftMm * 10).rounded() / 10, accuracy: 0.001)
    }

    func test_givenMoreCross_whenLength_thenLonger() {
        let c2 = SpokeMath.spokeLength(erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 20, rightOffsetMm: 20, spokeHoleMm: 2.6, spokeCount: 32, cross: 2)
        let c3 = SpokeMath.spokeLength(erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 20, rightOffsetMm: 20, spokeHoleMm: 2.6, spokeCount: 32, cross: 3)
        XCTAssertGreaterThan(c3.leftMm, c2.leftMm)
    }

    func test_givenAsymmetricOffsets_whenSides_thenDiffer() {
        let r = SpokeMath.spokeLength(erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 10, rightOffsetMm: 40, spokeHoleMm: 2.6, spokeCount: 32, cross: 3)
        XCTAssertNotEqual(r.leftMm, r.rightMm)
    }

    func test_givenCalibrationTable_whenInterpolate_thenBetween() {
        let table = [(20.0, 80.0), (30.0, 120.0)]
        let v = SpokeMath.kgf(deflection: 25, table: table)
        XCTAssertEqual(v, 100, accuracy: 0.1)
    }

    func test_givenBelowTable_whenKgf_thenClampsLow() {
        let table = [(20.0, 80.0), (30.0, 120.0)]
        XCTAssertEqual(SpokeMath.kgf(deflection: 10, table: table), 80, accuracy: 0.01)
    }

    func test_givenAboveTable_whenKgf_thenClampsHigh() {
        let table = [(20.0, 80.0), (30.0, 120.0)]
        XCTAssertEqual(SpokeMath.kgf(deflection: 40, table: table), 120, accuracy: 0.01)
    }

    func test_givenTensions_whenBalance_thenSDNonNegative() {
        let bal = SpokeMath.tensionBalance(drive: [110, 112, 108], nonDrive: [95, 97, 94])
        XCTAssertGreaterThan(bal.mean, 0)
        XCTAssertGreaterThanOrEqual(bal.sd, 0)
        XCTAssertGreaterThan(bal.driveToNonDrive, 1)
    }

    func test_givenSpread_whenWide_thenPercentHigh() {
        let tight = SpokeMath.tensionBalance(drive: [100, 101], nonDrive: [100, 101])
        let wide = SpokeMath.tensionBalance(drive: [80, 120], nonDrive: [80, 120])
        XCTAssertGreaterThan(wide.spreadPercent, tight.spreadPercent)
    }

    func test_givenOffsets_whenDishError_thenComputed() {
        let e = SpokeMath.dishErrorMm(leftOffset: 30, rightOffset: 40, hubWidth: 100)
        XCTAssertTrue(e.isFinite)
        XCTAssertNotEqual(e, 0)
    }

    func test_givenSineWave_whenFirstHarmonic_thenDetects() {
        let samples = (0..<16).map { sin(Double($0) / 16 * 2 * .pi) }
        let amp = SpokeMath.firstHarmonicAmplitude(samples: samples)
        XCTAssertGreaterThan(amp, 0.5)
    }

    func test_givenFlat_whenFirstHarmonic_thenNearZero() {
        XCTAssertEqual(SpokeMath.firstHarmonicAmplitude(samples: Array(repeating: 0.1, count: 16)), 0, accuracy: 0.05)
    }

    func test_givenRunout_whenAmplitude_thenPeakToPeak() {
        XCTAssertEqual(SpokeMath.runoutAmplitude(samples: [-0.5, 0.5, 0]), 1.0, accuracy: 0.01)
    }

    func test_givenMileage_whenFatigue_thenBounded() {
        let f = SpokeMath.fatigueExposure(km: 8000, meanTensionKgf: 110, spokeCount: 32)
        XCTAssertGreaterThan(f, 0)
        XCTAssertLessThanOrEqual(f, 100)
    }

    func test_givenEmptyTable_whenKgf_thenZero() {
        XCTAssertEqual(SpokeMath.kgf(deflection: 25, table: []), 0)
    }

    func test_givenRadial_whenCrossZero_thenShortest() {
        let radial = SpokeMath.spokeLength(erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 20, rightOffsetMm: 20, spokeHoleMm: 2.6, spokeCount: 32, cross: 0)
        let crossed = SpokeMath.spokeLength(erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 20, rightOffsetMm: 20, spokeHoleMm: 2.6, spokeCount: 32, cross: 3)
        XCTAssertLessThan(radial.leftMm, crossed.leftMm)
    }
}
