import Foundation

/// A look + sound combination. Colors live in the app target (they need SwiftUI);
/// the sound recipe lives here so it can be tested.
public enum FlushTheme: String, CaseIterable, Codable, Sendable, Identifiable {
    case classic
    case royal
    case toxic
    case blackHole

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: "Classic"
        case .royal: "Royal"
        case .toxic: "Toxic"
        case .blackHole: "Black Hole"
        }
    }

    public var sound: SoundRecipe {
        switch self {
        case .classic:
            SoundRecipe(duration: 3.0, startCutoff: 2600, endCutoff: 380, rumble: 0.5,
                        swirlRate: 3...9, bubbles: 26, bubblePitch: 380...900, seed: 1)
        case .royal:
            SoundRecipe(duration: 3.3, startCutoff: 1800, endCutoff: 260, rumble: 0.8,
                        swirlRate: 2...6, bubbles: 14, bubblePitch: 260...560, seed: 2)
        case .toxic:
            SoundRecipe(duration: 3.0, startCutoff: 1400, endCutoff: 300, rumble: 0.6,
                        swirlRate: 4...11, bubbles: 60, bubblePitch: 180...480, seed: 3)
        case .blackHole:
            SoundRecipe(duration: 3.3, startCutoff: 900, endCutoff: 70, rumble: 1.0,
                        swirlRate: 1...14, bubbles: 0, bubblePitch: 100...200, seed: 4)
        }
    }
}
