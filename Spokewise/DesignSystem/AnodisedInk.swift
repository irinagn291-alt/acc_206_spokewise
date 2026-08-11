import SwiftUI

/// Cold anodised teal on graphite. Every value is the packed hex the Spokewise
/// prototype specifies, so the palette can be audited against it literally.
public enum AnodisedInk {
    public static let graphite = anodise(0x0E1418)
    public static let readable = anodise(0xDCE6EA)
    public static let driveTeal = anodise(0x4FD1C5)
    public static let nonDriveTeal = anodise(0x2E7A74)
    public static let rimGold = anodise(0xF2C14E)
    public static let rimHairline = anodise(0x22323A)
    public static let innerHairline = anodise(0x1B2A31)
    public static let hubRing = anodise(0x2E4650)
    public static let chipInk = anodise(0x08181A)

    /// Dimmed body copy: the readout labels and every secondary caption.
    public static func dimmed(_ amount: Double = 0.5) -> Color { readable.opacity(amount) }

    static func anodise(_ packed: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((packed >> 16) & 0xFF) / 255,
            green: Double((packed >> 8) & 0xFF) / 255,
            blue: Double(packed & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Spokewise runs one radius scale: chips are fully rounded, panels 14, tiles 8.
public enum RimRadius {
    public static let chip: CGFloat = 999
    public static let panel: CGFloat = 14
    public static let tile: CGFloat = 8
}

/// Type roles. Numeric readouts are monospaced because the wheel is measured.
public enum RimFace {
    public static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    public static func chip(_ size: CGFloat, active: Bool) -> Font {
        .system(size: size, weight: active ? .bold : .regular)
    }
    public static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    public static func gauge(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

extension View {
    /// Graphite ground shared by every Spokewise surface.
    func rimBackdrop() -> some View {
        background(AnodisedInk.graphite.ignoresSafeArea())
    }

    /// Uppercase letterspaced caption used above every monospaced value.
    func rimCaption() -> some View {
        font(RimFace.label(10))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(AnodisedInk.dimmed())
    }
}
