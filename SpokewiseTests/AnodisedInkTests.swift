import SwiftUI
import UIKit
import XCTest
@testable import Spokewise

/// Guards the palette against drift: every hue is the prototype's hex.
final class AnodisedInkTests: XCTestCase {

    func test_givenPalette_whenResolved_thenMatchesThePrototypeHexes() {
        assert(AnodisedInk.graphite, is: 0x0E1418)
        assert(AnodisedInk.readable, is: 0xDCE6EA)
        assert(AnodisedInk.driveTeal, is: 0x4FD1C5)
        assert(AnodisedInk.nonDriveTeal, is: 0x2E7A74)
        assert(AnodisedInk.rimGold, is: 0xF2C14E)
        assert(AnodisedInk.rimHairline, is: 0x22323A)
        assert(AnodisedInk.innerHairline, is: 0x1B2A31)
        assert(AnodisedInk.hubRing, is: 0x2E4650)
        assert(AnodisedInk.chipInk, is: 0x08181A)
    }

    func test_givenChips_whenRadiusRead_thenFullyRounded() {
        XCTAssertEqual(RimRadius.chip, 999)
        XCTAssertGreaterThan(RimRadius.panel, RimRadius.tile)
    }

    func test_givenDimmedInk_whenBuilt_thenStillTheReadableHue() {
        assert(AnodisedInk.dimmed(1), is: 0xDCE6EA)
    }

    private func assert(_ colour: Color, is packed: UInt32, line: UInt = #line) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(colour).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(Int((red * 255).rounded()), Int((packed >> 16) & 0xFF), line: line)
        XCTAssertEqual(Int((green * 255).rounded()), Int((packed >> 8) & 0xFF), line: line)
        XCTAssertEqual(Int((blue * 255).rounded()), Int(packed & 0xFF), line: line)
    }
}
