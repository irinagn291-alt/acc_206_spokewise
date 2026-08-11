import XCTest
@testable import Spokewise

final class BenchDiagramMathTests: XCTestCase {

    func test_givenThreeCross_whenFlangeAngle_thenThreeHolesOfWrap() {
        XCTAssertEqual(
            SpokeTriangleMath.flangeAngle(spokeCount: 32, cross: 3),
            2 * Double.pi * 3 / 32,
            accuracy: 0.0001
        )
    }

    func test_givenRadialLacing_whenFlangeAngle_thenNoWrap() {
        XCTAssertEqual(SpokeTriangleMath.flangeAngle(spokeCount: 32, cross: 0), 0, accuracy: 0.0001)
    }

    func test_givenRoadGeometry_whenTriangle_thenSeatsSitOnTheirRadii() {
        let triangle = SpokeTriangleMath.triangle(
            erdMm: 565, flangeDiameterMm: 58, offsetMm: 34, holeMm: 2.6, spokeCount: 32, cross: 3
        )
        XCTAssertEqual(triangle.rimSeat.x, 282.5, accuracy: 0.0001)
        XCTAssertEqual(triangle.rimSeat.y, 0, accuracy: 0.0001)
        XCTAssertEqual(hypot(triangle.flangeHole.x, triangle.flangeHole.y), 29, accuracy: 0.0001)
        XCTAssertEqual(triangle.axle, RimPoint(x: 0, y: 0))
    }

    func test_givenRadialLacing_whenTriangle_thenChordIsTheRadiiDifference() {
        let triangle = SpokeTriangleMath.triangle(
            erdMm: 565, flangeDiameterMm: 58, offsetMm: 0, holeMm: 0, spokeCount: 32, cross: 0
        )
        XCTAssertEqual(triangle.chordMm, 253.5, accuracy: 0.05)
        XCTAssertEqual(triangle.lengthMm, 253.5, accuracy: 0.05)
    }

    func test_givenTheSameGeometry_whenTriangleAndCalculator_thenSameCutLength() {
        let triangle = SpokeTriangleMath.triangle(
            erdMm: 565, flangeDiameterMm: 58, offsetMm: 34, holeMm: 2.6, spokeCount: 32, cross: 3
        )
        let calculated = SpokeMath.spokeLength(
            erdMm: 565, flangeDiameterMm: 58, leftOffsetMm: 17, rightOffsetMm: 34,
            spokeHoleMm: 2.6, spokeCount: 32, cross: 3
        )
        XCTAssertEqual(triangle.lengthMm, calculated.rightMm, accuracy: 0.05)
    }

    func test_givenMoreOffset_whenTriangle_thenLongerSpokeSameChord() {
        let narrow = SpokeTriangleMath.triangle(
            erdMm: 565, flangeDiameterMm: 58, offsetMm: 17, holeMm: 2.6, spokeCount: 32, cross: 3
        )
        let wide = SpokeTriangleMath.triangle(
            erdMm: 565, flangeDiameterMm: 58, offsetMm: 40, holeMm: 2.6, spokeCount: 32, cross: 3
        )
        XCTAssertGreaterThan(wide.lengthMm, narrow.lengthMm)
        XCTAssertEqual(wide.chordMm, narrow.chordMm, accuracy: 0.0001)
    }

    func test_givenTable_whenPlotted_thenDeflectionRunsLeftToRightAndForceUp() {
        let plotted = CalibrationCurveMath.plotted([(5, 20), (40, 180)])
        XCTAssertEqual(plotted[0].x, 0, accuracy: 0.0001)
        XCTAssertEqual(plotted[0].y, 1, accuracy: 0.0001)
        XCTAssertEqual(plotted[1].x, 1, accuracy: 0.0001)
        XCTAssertEqual(plotted[1].y, 0, accuracy: 0.0001)
    }

    func test_givenTouchOnAKnot_whenNearestKnot_thenPicksIt() {
        let knots = CalibrationCurveMath.plotted([(15, 60), (20, 80), (25, 100)])
        let index = CalibrationCurveMath.nearestKnot(to: knots[1], among: knots)
        XCTAssertEqual(index, 1)
    }

    func test_givenTouchFarFromTheCurve_whenNearestKnot_thenNothingGrabbed() {
        let knots = CalibrationCurveMath.plotted([(15, 60), (20, 80)])
        XCTAssertNil(CalibrationCurveMath.nearestKnot(to: RimPoint(x: 0.95, y: 0.02), among: knots))
    }

    func test_givenNoKnots_whenNearestKnot_thenNothingGrabbed() {
        XCTAssertNil(CalibrationCurveMath.nearestKnot(to: RimPoint(x: 0.5, y: 0.5), among: []))
    }

    func test_givenDragBelowItsNeighbour_whenDraggedKgf_thenTableStaysMonotonic() {
        let pairs: [(deflection: Double, kgf: Double)] = [(15, 60), (20, 80), (25, 100)]
        let dragged = CalibrationCurveMath.draggedKgf(plotY: 1, index: 1, in: pairs)
        XCTAssertGreaterThanOrEqual(dragged, 61)
        XCTAssertLessThanOrEqual(dragged, 99)
    }

    func test_givenDragAboveItsNeighbour_whenDraggedKgf_thenTableStaysMonotonic() {
        let pairs: [(deflection: Double, kgf: Double)] = [(15, 60), (20, 80), (25, 100)]
        XCTAssertLessThanOrEqual(CalibrationCurveMath.draggedKgf(plotY: 0, index: 1, in: pairs), 99)
    }

    func test_givenEndKnot_whenDragged_thenOnlyBoundedByThePlot() {
        let pairs: [(deflection: Double, kgf: Double)] = [(15, 60), (20, 80)]
        XCTAssertEqual(CalibrationCurveMath.draggedKgf(plotY: 1, index: 0, in: pairs), 20, accuracy: 0.0001)
    }

    func test_givenKnots_whenColumns_thenTwoAlignedCSVs() {
        let columns = CalibrationCurveMath.columns([(15, 60), (20.5, 82)])
        XCTAssertEqual(columns.deflection, "15.0,20.5")
        XCTAssertEqual(columns.kgf, "60,82")
    }

    func test_givenSeries_whenProfiled_thenSpansThePlotWidth() {
        let points = RimProfileMath.profile([1, 2, 3], band: RimProfileMath.band([[1, 2, 3]]))
        XCTAssertEqual(points.first?.x, 0)
        XCTAssertEqual(points.last?.x, 1)
        XCTAssertGreaterThan(points[0].y, points[2].y)
    }

    func test_givenFlatSeries_whenBanded_thenStillHasHeight() {
        let band = RimProfileMath.band([[5, 5, 5]])
        XCTAssertGreaterThan(band.upperBound, band.lowerBound)
    }

    func test_givenNoSeries_whenBanded_thenUnitBand() {
        XCTAssertEqual(RimProfileMath.band([]), 0...1)
    }

    func test_givenEmptySeries_whenProfiled_thenNoPoints() {
        XCTAssertTrue(RimProfileMath.profile([], band: 0...1).isEmpty)
    }

    func test_givenSingleSample_whenProfiled_thenCentred() {
        let points = RimProfileMath.profile([2], band: 0...4)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points[0].y, 0.5, accuracy: 0.0001)
    }
}
