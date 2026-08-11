import XCTest
@testable import Spokewise

/// Builds sample sets the geometry tests can reason about.
enum RimSampleFixture {
    static func make(
        tensions: [Double] = [],
        lateral: [Double] = [],
        radial: [Double] = [],
        measured: Bool = true,
        count: Int? = nil
    ) -> [RimSample] {
        let holes = count ?? max(tensions.count, max(lateral.count, radial.count))
        return (0..<holes).map { index in
            RimSample(
                index: index,
                side: RimPolarGeometry.lacedSide(index: index),
                tensionKgf: index < tensions.count ? tensions[index] : 0,
                deflection: 24,
                lateralMm: index < lateral.count ? lateral[index] : 0,
                radialMm: index < radial.count ? radial[index] : 0,
                isMeasured: measured
            )
        }
    }
}

final class RimPolarGeometryTests: XCTestCase {
    private let centre = RimPoint(x: 150, y: 150)

    func test_givenFirstHole_whenSpokeAngle_thenPointsAtTheValve() {
        XCTAssertEqual(RimPolarGeometry.spokeAngle(index: 0, count: 32), -Double.pi / 2, accuracy: 0.0001)
    }

    func test_givenQuarterOfTheHoles_whenSpokeAngle_thenClockwiseToThree() {
        XCTAssertEqual(RimPolarGeometry.spokeAngle(index: 8, count: 32), 0, accuracy: 0.0001)
    }

    func test_givenIndexPastTheCount_whenSpokeAngle_thenWrapsToTheValve() {
        XCTAssertEqual(
            RimPolarGeometry.spokeAngle(index: 32, count: 32),
            RimPolarGeometry.spokeAngle(index: 0, count: 32),
            accuracy: 0.0001
        )
    }

    func test_givenNegativeIndex_whenSpokeAngle_thenWrapsBackwards() {
        XCTAssertEqual(
            RimPolarGeometry.spokeAngle(index: -1, count: 32),
            RimPolarGeometry.spokeAngle(index: 31, count: 32),
            accuracy: 0.0001
        )
    }

    func test_givenAlternatingHoles_whenLacedSide_thenEvenHolesAreDrive() {
        XCTAssertEqual(RimPolarGeometry.lacedSide(index: 0), .drive)
        XCTAssertEqual(RimPolarGeometry.lacedSide(index: 1), .nonDrive)
        XCTAssertEqual(RimPolarGeometry.lacedSide(index: 30), .drive)
        XCTAssertEqual(RimPolarGeometry.lacedSide(index: -3), .nonDrive)
    }

    func test_givenThreeCross_whenLacingLead_thenFlangesWindOppositeWays() {
        let drive = RimPolarGeometry.lacingLead(count: 32, cross: 3, side: .drive)
        let nonDrive = RimPolarGeometry.lacingLead(count: 32, cross: 3, side: .nonDrive)
        XCTAssertEqual(drive, 2 * Double.pi * 3 / 16, accuracy: 0.0001)
        XCTAssertEqual(drive, -nonDrive, accuracy: 0.0001)
    }

    func test_givenRadialLacing_whenLacingLead_thenNoTangentialSwing() {
        XCTAssertEqual(RimPolarGeometry.lacingLead(count: 32, cross: 0, side: .drive), 0, accuracy: 0.0001)
    }

    func test_givenFirstHole_whenRimAnchor_thenSitsDirectlyAboveTheHub() {
        let anchor = RimPolarGeometry.rimAnchor(index: 0, count: 32, center: centre, rimRadius: 118)
        XCTAssertEqual(anchor.x, 150, accuracy: 0.0001)
        XCTAssertEqual(anchor.y, 32, accuracy: 0.0001)
    }

    func test_givenAnyHole_whenHubAnchor_thenLandsOnTheHubRing() {
        for index in 0..<32 {
            let anchor = RimPolarGeometry.hubAnchor(
                index: index, count: 32, cross: 3,
                side: RimPolarGeometry.lacedSide(index: index),
                center: centre, hubRadius: 26
            )
            XCTAssertEqual(hypot(anchor.x - centre.x, anchor.y - centre.y), 26, accuracy: 0.0001)
        }
    }

    func test_givenDeviations_whenPolygon_thenOneVertexPerSpokeWithinTheSwing() {
        let normalized = (0..<32).map { sin(Double($0) / 32 * 2 * .pi) }
        let polygon = RimPolarGeometry.deviationPolygon(
            normalized: normalized, center: centre, referenceRadius: 104, span: 11
        )
        XCTAssertEqual(polygon.count, 32)
        for vertex in polygon {
            let radius = hypot(vertex.x - centre.x, vertex.y - centre.y)
            XCTAssertGreaterThanOrEqual(radius, 104 - 11 - 0.0001)
            XCTAssertLessThanOrEqual(radius, 104 + 11 + 0.0001)
        }
    }

    func test_givenTooFewSpokes_whenPolygon_thenNoOutline() {
        XCTAssertTrue(
            RimPolarGeometry.deviationPolygon(
                normalized: [0.2, -0.2], center: centre, referenceRadius: 104, span: 11
            ).isEmpty
        )
    }

    func test_givenWildDeviation_whenVertexRadius_thenClampedToTheSwing() {
        XCTAssertEqual(
            RimPolarGeometry.vertexRadius(normalized: 8, referenceRadius: 104, span: 11), 115, accuracy: 0.0001
        )
        XCTAssertEqual(
            RimPolarGeometry.vertexRadius(normalized: -8, referenceRadius: 104, span: 11), 93, accuracy: 0.0001
        )
    }

    func test_givenSwingWiderThanTheRim_whenVertexRadius_thenNeverNegative() {
        XCTAssertEqual(
            RimPolarGeometry.vertexRadius(normalized: -1, referenceRadius: 10, span: 40), 0, accuracy: 0.0001
        )
    }

    func test_givenTapAboveTheHub_whenNearestSpoke_thenFindsTheValveHole() {
        let tap = RimPoint(x: 150, y: 40)
        XCTAssertEqual(RimPolarGeometry.nearestSpoke(to: tap, center: centre, count: 32), 0)
    }

    func test_givenTapAtThreeOClock_whenNearestSpoke_thenFindsTheQuarterHole() {
        let tap = RimPoint(x: 260, y: 150)
        XCTAssertEqual(RimPolarGeometry.nearestSpoke(to: tap, center: centre, count: 32), 8)
    }

    func test_givenTapNearTheHub_whenNearestSpoke_thenStillResolvesAHole() {
        let tap = RimPoint(x: 150, y: 130)
        XCTAssertEqual(RimPolarGeometry.nearestSpoke(to: tap, center: centre, count: 16), 0)
    }

    func test_givenMatchingLength_whenResample_thenUnchanged() {
        XCTAssertEqual(RimPolarGeometry.resample([0, 1, 2, 3], to: 4), [0, 1, 2, 3])
    }

    func test_givenTwoSamples_whenResampledUp_thenInterpolatesAndWraps() {
        let out = RimPolarGeometry.resample([0, 1], to: 4)
        XCTAssertEqual(out.count, 4)
        XCTAssertEqual(out[0], 0, accuracy: 0.0001)
        XCTAssertEqual(out[1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(out[2], 1, accuracy: 0.0001)
        XCTAssertEqual(out[3], 0.5, accuracy: 0.0001)
    }

    func test_givenEmptyTrace_whenResample_thenFlatZeroes() {
        XCTAssertEqual(RimPolarGeometry.resample([], to: 5), [0, 0, 0, 0, 0])
    }

    func test_givenOneSample_whenResample_thenHeldConstant() {
        XCTAssertEqual(RimPolarGeometry.resample([0.4], to: 3), [0.4, 0.4, 0.4])
    }

    func test_givenZeroTarget_whenResample_thenEmpty() {
        XCTAssertTrue(RimPolarGeometry.resample([1, 2, 3], to: 0).isEmpty)
    }

    func test_givenDragOnTheNominalRim_whenRunout_thenReadsTrue() {
        XCTAssertEqual(
            RimPolarGeometry.runout(reach: 100, base: 100, gain: 50, fullScale: 1.5, step: 0.05),
            0,
            accuracy: 0.0001
        )
    }

    func test_givenDragHalfwayOut_whenRunout_thenHalfFullScale() {
        XCTAssertEqual(
            RimPolarGeometry.runout(reach: 125, base: 100, gain: 50, fullScale: 1.5, step: 0.05),
            0.75,
            accuracy: 0.0001
        )
    }

    func test_givenDragInsideTheRim_whenRunout_thenNegative() {
        XCTAssertLessThan(
            RimPolarGeometry.runout(reach: 80, base: 100, gain: 50, fullScale: 1.5, step: 0.05),
            0
        )
    }

    func test_givenDragBeyondTheStand_whenRunout_thenClampedToFullScale() {
        XCTAssertEqual(
            RimPolarGeometry.runout(reach: 400, base: 100, gain: 50, fullScale: 1.5, step: 0.05),
            1.5,
            accuracy: 0.0001
        )
    }

    func test_givenNoGain_whenRunout_thenNothingRecorded() {
        XCTAssertEqual(
            RimPolarGeometry.runout(reach: 400, base: 100, gain: 0, fullScale: 1.5, step: 0.05),
            0
        )
    }

    func test_givenDrag_whenRunout_thenSnappedToTheStandStep() {
        let value = RimPolarGeometry.runout(reach: 117, base: 100, gain: 50, fullScale: 1.5, step: 0.05)
        XCTAssertEqual((value / 0.05).rounded(), value / 0.05, accuracy: 0.0001)
    }

    func test_givenTrace_whenSerialised_thenTwoDecimalCSV() {
        XCTAssertEqual(RimPolarGeometry.csv([0.126, -1, 2]), "0.13,-1.00,2.00")
    }
}
