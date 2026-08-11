import Foundation

/// Everything reachable from the map. The map itself is never a destination:
/// it is the root, and the lens chips re-read it without pushing anything.
public enum SpokeRoute: Hashable, Sendable, Identifiable {
    case bench
    case components
    case calibration
    case truing(UUID)
    case builds
    case stats
    case compare
    case reference
    case maintenance
    case settings

    public var id: String {
        switch self {
        case .bench: return "bench"
        case .components: return "components"
        case .calibration: return "calibration"
        case .truing(let id): return "truing-\(id.uuidString)"
        case .builds: return "builds"
        case .stats: return "stats"
        case .compare: return "compare"
        case .reference: return "reference"
        case .maintenance: return "maintenance"
        case .settings: return "settings"
        }
    }

    public var label: String {
        switch self {
        case .bench: return "Spoke length"
        case .components: return "Component bench"
        case .calibration: return "Tensiometer curve"
        case .truing: return "Runout trace"
        case .builds: return "Build ledger"
        case .stats: return "Wheel statistics"
        case .compare: return "Overlay two wheels"
        case .reference: return "Lacing patterns"
        case .maintenance: return "Service log"
        case .settings: return "Settings"
        }
    }

    /// Compact monospaced label for the hero destination chrome.
    public var chipLabel: String {
        switch self {
        case .bench: return "Length"
        case .components: return "Parts"
        case .calibration: return "Curve"
        case .truing: return "Trace"
        case .builds: return "Builds"
        case .stats: return "Stats"
        case .compare: return "Overlay"
        case .reference: return "Lace"
        case .maintenance: return "Service"
        case .settings: return "Settings"
        }
    }

    public var symbol: String {
        switch self {
        case .bench: return "ruler"
        case .components: return "shippingbox"
        case .calibration: return "point.topleft.down.curvedto.point.bottomright.up"
        case .truing: return "scope"
        case .builds: return "square.grid.2x2"
        case .stats: return "chart.bar"
        case .compare: return "arrow.left.arrow.right"
        case .reference: return "book"
        case .maintenance: return "wrench.adjustable"
        case .settings: return "gearshape"
        }
    }
}
