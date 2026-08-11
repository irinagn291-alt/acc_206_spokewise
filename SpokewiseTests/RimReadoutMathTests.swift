import XCTest
@testable import Spokewise

final class RimReadoutMathTests: XCTestCase {

    func test_givenReadSpokes_whenMeanTension_thenAveragesThem() {
        let samples = RimSampleFixture.make(tensions: [90, 100, 110])
        XCTAssertEqual(RimReadoutMath.meanTension(samples), 100, accuracy: 0.0001)
    }

    func test_givenUnreadSpokes_whenMeanTension_thenIgnoresTheirFiller() {
        let read = RimSample(index: 0, side: .drive, tensionKgf: 110, deflection: 27, lateralMm: 0, radialMm: 0, isMeasured: true)
        let unread = RimSample(index: 1, side: .nonDrive, tensionKgf: 0, deflection: 0, lateralMm: 0, radialMm: 0, isMeasured: false)
        XCTAssertEqual(RimReadoutMath.meanTension([read, unread]), 110, accuracy: 0.0001)
    }

    func test_givenNoSpokes_whenMeanTension_thenZero() {
        XCTAssertEqual(RimReadoutMath.meanTension([]), 0)
    }

    func test_givenTwentyKilogramRange_whenSpread_thenReportsHalfOfItAsPercent() {
        let samples = RimSampleFixture.make(tensions: [90, 100, 110])
        XCTAssertEqual(RimReadoutMath.spreadPercent(samples), 10, accuracy: 0.0001)
    }

    func test_givenPerfectlyEvenWheel_whenSpread_thenZero() {
        XCTAssertEqual(RimReadoutMath.spreadPercent(RimSampleFixture.make(tensions: [100, 100, 100])), 0)
    }

    func test_givenOneSpoke_whenSpread_thenZero() {
        XCTAssertEqual(RimReadoutMath.spreadPercent(RimSampleFixture.make(tensions: [100])), 0)
    }

    func test_givenLateralOffsets_whenDish_thenReportsThePlaneTheRimSitsIn() {
        let samples = RimSampleFixture.make(lateral: [2.0, 2.2, 2.1, 2.1])
        XCTAssertEqual(RimReadoutMath.dishMm(samples), 2.1, accuracy: 0.0001)
    }

    func test_givenCentredRim_whenDish_thenZero() {
        XCTAssertEqual(RimReadoutMath.dishMm(RimSampleFixture.make(lateral: [0.3, -0.3, 0.2, -0.2])), 0)
    }

    func test_givenNoSamples_whenDish_thenZero() {
        XCTAssertEqual(RimReadoutMath.dishMm([]), 0)
    }

    func test_givenMeasuredWheel_whenReadout_thenAllThreeFiguresAgree() {
        let samples = RimSampleFixture.make(tensions: [90, 100, 110], lateral: [2.1, 2.1, 2.1])
        let readout = RimReadoutMath.readout(samples)
        XCTAssertEqual(readout.meanKgf, 100, accuracy: 0.0001)
        XCTAssertEqual(readout.spreadPercent, 10, accuracy: 0.0001)
        XCTAssertEqual(readout.dishMm, 2.1, accuracy: 0.0001)
    }

    func test_givenReadout_whenFormatted_thenMatchesThePinnedStrip() {
        let figures = RimReadoutMath.format(RimReadout(meanKgf: 108.2, spreadPercent: 9.4, dishMm: 2.1))
        XCTAssertEqual(figures.mean, "108 kgf")
        XCTAssertEqual(figures.spread, "±9%")
        XCTAssertEqual(figures.dish, "2.1 mm")
    }

    func test_givenRearWheelName_whenRimTitle_thenNavBarForm() {
        XCTAssertEqual(RimReadoutMath.rimTitle(name: "Road Rear 32h", spokeCount: 32), "Rear · 32h")
    }

    func test_givenFrontWheelName_whenRimTitle_thenNamesTheEnd() {
        XCTAssertEqual(RimReadoutMath.rimTitle(name: "Gravel Front", spokeCount: 32), "Front · 32h")
    }

    func test_givenUnplaceableName_whenRimTitle_thenUsesItsFirstWord() {
        XCTAssertEqual(RimReadoutMath.rimTitle(name: "commuter build", spokeCount: 36), "Commuter · 36h")
    }

    func test_givenNoName_whenRimTitle_thenStillReadsAsAWheel() {
        XCTAssertEqual(RimReadoutMath.rimTitle(name: "", spokeCount: 24), "Wheel · 24h")
    }
}
