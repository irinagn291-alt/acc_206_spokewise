import Foundation

/// Eighteen classic lacing patterns with length effect notes.
public enum SpokeReferenceLibrary: Sendable {
    public static let entries: [LacingPattern] = [
        LacingPattern(id: "radial", name: "Radial", cross: 0, lengthEffect: "Shortest spokes", useCase: "Front disc, low torque"),
        LacingPattern(id: "1x", name: "1-cross", cross: 1, lengthEffect: "Slightly longer than radial", useCase: "Light road front"),
        LacingPattern(id: "2x", name: "2-cross", cross: 2, lengthEffect: "Moderate length", useCase: "General purpose"),
        LacingPattern(id: "3x", name: "3-cross", cross: 3, lengthEffect: "Standard road length", useCase: "Most 32/36h wheels"),
        LacingPattern(id: "4x", name: "4-cross", cross: 4, lengthEffect: "Longer spokes", useCase: "Touring and cargo"),
        LacingPattern(id: "half", name: "Half radial", cross: 0, lengthEffect: "Mixed lengths", useCase: "Drive radial / ND crossed"),
        LacingPattern(id: "crow", name: "Crow's foot", cross: 2, lengthEffect: "Grouped spoke pairs", useCase: "Aesthetic builds"),
        LacingPattern(id: "2lead", name: "2-lead", cross: 2, lengthEffect: "Asymmetric pairs", useCase: "Track fixed"),
        LacingPattern(id: "3lead", name: "3-lead", cross: 3, lengthEffect: "Classic 3x pairing", useCase: "Road rear"),
        LacingPattern(id: "straight", name: "Straight pull", cross: 0, lengthEffect: "Hub-specific length", useCase: "Straight-pull hubs"),
        LacingPattern(id: "center", name: "Center lock 3x", cross: 3, lengthEffect: "Symmetric flanges", useCase: "Disc centerlock"),
        LacingPattern(id: "offset", name: "Offset drilled 3x", cross: 3, lengthEffect: "Slight dish compensation", useCase: "Asymmetric rims"),
        LacingPattern(id: "fat", name: "Fat bike 3x", cross: 3, lengthEffect: "Longer ERD lengths", useCase: "Wide rims"),
        LacingPattern(id: "bmx", name: "BMX 3x", cross: 3, lengthEffect: "Short stout spokes", useCase: "20-inch freestyle"),
        LacingPattern(id: "tandem", name: "Tandem 4x", cross: 4, lengthEffect: "Maximum wrap", useCase: "High load"),
        LacingPattern(id: "singlespeed", name: "Singlespeed 3x", cross: 3, lengthEffect: "Even D/ND ratio", useCase: "Flip-flop hubs"),
        LacingPattern(id: "gravel", name: "Gravel 2x", cross: 2, lengthEffect: "Stiffer lateral", useCase: "Wide gravel rims"),
        LacingPattern(id: "aero", name: "Aero bladed 2x", cross: 2, lengthEffect: "Bladed spoke length", useCase: "Deep section")
    ]
}
