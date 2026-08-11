import Foundation

/// The three readings of one polar map. Choosing a lens re-reads the same
/// artefact in place; it never opens another screen.
public enum RimLens: String, CaseIterable, Identifiable, Sendable, Hashable {
    case tension
    case dish
    case trueness

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tension: return "Tension"
        case .dish: return "Dish"
        case .trueness: return "True"
        }
    }

    /// Unit the polygon's vertex radii are read in under this lens.
    public var unit: String {
        switch self {
        case .tension: return "kgf"
        case .dish, .trueness: return "mm"
        }
    }

    /// What one dial turn adjusts when a spoke is tapped under this lens.
    public var dialCaption: String {
        switch self {
        case .tension: return "Tensiometer deflection"
        case .dish: return "Lateral offset"
        case .trueness: return "Radial runout"
        }
    }

    public var dialRange: ClosedRange<Double> {
        switch self {
        case .tension: return 10...40
        case .dish: return -3...3
        case .trueness: return -1.5...1.5
        }
    }

    public var dialStep: Double {
        switch self {
        case .tension: return 0.1
        case .dish, .trueness: return 0.05
        }
    }
}
