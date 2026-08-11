import XCTest
@testable import Spokewise

final class RimDeviationScaleTests: XCTestCase {

    func test_givenTightSpoke_whenTensionLens_thenPullsTheRimInwards() {
        let samples = RimSampleFixture.make(tensions: [100, 120, 80])
        let raw = RimDeviationScale.raw(samples: samples, lens: .tension)
        XCTAssertEqual(raw[0], 0, accuracy: 0.0001)
        XCTAssertEqual(raw[1], -20, accuracy: 0.0001)
        XCTAssertEqual(raw[2], 20, accuracy: 0.0001)
    }

    func test_givenOffCentreRim_whenDishLens_thenReadsWanderNotOffset() {
        let samples = RimSampleFixture.make(lateral: [2.0, 2.2, 1.8])
        let raw = RimDeviationScale.raw(samples: samples, lens: .dish)
        XCTAssertEqual(raw[0], 0, accuracy: 0.0001)
        XCTAssertEqual(raw[1], 0.2, accuracy: 0.0001)
        XCTAssertEqual(raw[2], -0.2, accuracy: 0.0001)
    }

    func test_givenLateralWorseThanRadial_whenTrueLens_thenTakesTheWorseSigned() {
        let samples = RimSampleFixture.make(lateral: [-0.5, 0.1], radial: [0.1, 0.4])
        let raw = RimDeviationScale.raw(samples: samples, lens: .trueness)
        XCTAssertEqual(raw[0], -0.5, accuracy: 0.0001)
        XCTAssertEqual(raw[1], 0.4, accuracy: 0.0001)
    }

    func test_givenDeviations_whenNormalised_thenPeakReachesOne() {
        let normalized = RimDeviationScale.normalized([-4, 2, 0, 1])
        XCTAssertEqual(normalized[0], -1, accuracy: 0.0001)
        XCTAssertEqual(normalized[1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(normalized[2], 0, accuracy: 0.0001)
    }

    func test_givenPerfectWheel_whenNormalised_thenOutlineIsACircle() {
        XCTAssertEqual(RimDeviationScale.normalized([0, 0, 0]), [0, 0, 0])
    }

    func test_givenEvenTension_whenTensionLens_thenNoSwing() {
        let samples = RimSampleFixture.make(tensions: [110, 110, 110, 110])
        XCTAssertTrue(RimDeviationScale.normalized(samples: samples, lens: .tension).allSatisfy { $0 == 0 })
    }

    func test_givenTensions_whenPeak_thenReportedInKilogramsForce() {
        let samples = RimSampleFixture.make(tensions: [100, 120, 80])
        XCTAssertEqual(RimDeviationScale.peak(samples: samples, lens: .tension), 20, accuracy: 0.001)
    }

    func test_givenRunout_whenPeak_thenReportedInMillimetres() {
        let samples = RimSampleFixture.make(radial: [0.1, -0.42, 0.05])
        XCTAssertEqual(RimDeviationScale.peak(samples: samples, lens: .trueness), 0.42, accuracy: 0.001)
    }

    func test_givenOneSoftSpoke_whenOutliers_thenOnlyThatHoleIsFlagged() {
        let samples = RimSampleFixture.make(tensions: [104, 100, 62, 102, 100])
        XCTAssertEqual(RimDeviationScale.outliers(samples: samples, lens: .tension), [2])
    }

    func test_givenNoSamples_whenNormalised_thenEmpty() {
        XCTAssertTrue(RimDeviationScale.normalized(samples: [], lens: .dish).isEmpty)
    }

    func test_givenEachLens_whenUnitRead_thenMatchesItsQuantity() {
        XCTAssertEqual(RimLens.tension.unit, "kgf")
        XCTAssertEqual(RimLens.dish.unit, "mm")
        XCTAssertEqual(RimLens.trueness.unit, "mm")
        XCTAssertEqual(RimLens.allCases.map(\.title), ["Tension", "Dish", "True"])
    }

    func test_givenEachLens_whenDialled_thenRangeStraddlesItsUnit() {
        XCTAssertEqual(RimLens.tension.dialRange, 10...40)
        XCTAssertTrue(RimLens.dish.dialRange.contains(0))
        XCTAssertTrue(RimLens.trueness.dialRange.contains(0))
        XCTAssertGreaterThan(RimLens.tension.dialStep, 0)
    }
}
