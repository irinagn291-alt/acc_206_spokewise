import XCTest
@testable import Spokewise

final class SpokeDialMathTests: XCTestCase {
    private let centre = RimPoint(x: 0, y: 0)

    func test_givenTravelEnds_whenAngle_thenSweepsThreeQuarters() {
        XCTAssertEqual(SpokeDialMath.angle(forFraction: 0), SpokeDialMath.startAngle, accuracy: 0.0001)
        XCTAssertEqual(
            SpokeDialMath.angle(forFraction: 1),
            SpokeDialMath.startAngle + SpokeDialMath.sweep,
            accuracy: 0.0001
        )
    }

    func test_givenFractionsAcrossTheTravel_whenRoundTripped_thenPreserved() {
        for fraction in [0.0, 0.2, 0.5, 0.75, 1.0] {
            let recovered = SpokeDialMath.fraction(forAngle: SpokeDialMath.angle(forFraction: fraction))
            XCTAssertEqual(recovered, fraction, accuracy: 0.0001)
        }
    }

    func test_givenFractionBeyondTheTravel_whenAngle_thenClampedToTheEnd() {
        XCTAssertEqual(
            SpokeDialMath.angle(forFraction: 4),
            SpokeDialMath.angle(forFraction: 1),
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SpokeDialMath.angle(forFraction: -4),
            SpokeDialMath.angle(forFraction: 0),
            accuracy: 0.0001
        )
    }

    func test_givenDragJustBeforeTheStart_whenFraction_thenStaysAtTheLowEnd() {
        XCTAssertEqual(SpokeDialMath.fraction(forAngle: SpokeDialMath.startAngle - 0.2), 0, accuracy: 0.0001)
    }

    func test_givenDragJustPastTheEnd_whenFraction_thenStaysAtTheHighEnd() {
        let past = SpokeDialMath.startAngle + SpokeDialMath.sweep + 0.2
        XCTAssertEqual(SpokeDialMath.fraction(forAngle: past), 1, accuracy: 0.0001)
    }

    func test_givenTouchStraightAboveTheKnob_whenFraction_thenHalfway() {
        let touch = RimPoint(x: 0, y: -50)
        XCTAssertEqual(SpokeDialMath.fraction(at: touch, center: centre), 0.5, accuracy: 0.0001)
    }

    func test_givenTouchToTheRight_whenFraction_thenNearTheTop() {
        let touch = RimPoint(x: 50, y: 0)
        XCTAssertEqual(SpokeDialMath.fraction(at: touch, center: centre), 5.0 / 6.0, accuracy: 0.0001)
    }

    func test_givenMidTravel_whenValue_thenCentreOfTheRange() {
        XCTAssertEqual(
            SpokeDialMath.value(forFraction: 0.5, range: 10...40, step: 0.1), 25, accuracy: 0.0001
        )
    }

    func test_givenValue_whenSnapped_thenLandsOnTheLensStep() {
        let value = SpokeDialMath.value(forFraction: 0.3141, range: -3...3, step: 0.05)
        XCTAssertEqual((value / 0.05).rounded(), value / 0.05, accuracy: 0.0001)
    }

    func test_givenFractionOutsideTheTravel_whenValue_thenClampedToTheRange() {
        XCTAssertEqual(SpokeDialMath.value(forFraction: 3, range: 10...40, step: 0.1), 40, accuracy: 0.0001)
        XCTAssertEqual(SpokeDialMath.value(forFraction: -3, range: 10...40, step: 0.1), 10, accuracy: 0.0001)
    }

    func test_givenValue_whenFraction_thenInvertsTheTravel() {
        XCTAssertEqual(SpokeDialMath.fraction(forValue: 25, range: 10...40), 0.5, accuracy: 0.0001)
        XCTAssertEqual(SpokeDialMath.fraction(forValue: 0, range: -3...3), 0.5, accuracy: 0.0001)
    }

    func test_givenEmptyRange_whenFraction_thenStartOfTravel() {
        XCTAssertEqual(SpokeDialMath.fraction(forValue: 5, range: 5...5), 0, accuracy: 0.0001)
    }

    func test_givenFineButtons_whenStepped_thenMovesOneStepAndStops() {
        XCTAssertEqual(SpokeDialMath.stepped(24, by: 1, range: 10...40, step: 0.1), 24.1, accuracy: 0.0001)
        XCTAssertEqual(SpokeDialMath.stepped(10, by: -1, range: 10...40, step: 0.1), 10, accuracy: 0.0001)
        XCTAssertEqual(SpokeDialMath.stepped(40, by: 1, range: 10...40, step: 0.1), 40, accuracy: 0.0001)
    }
}
