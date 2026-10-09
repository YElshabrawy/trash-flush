import SwiftUI
import TrashFlushCore

/// Colors for each theme, from the bottom of the bowl to the foam on top.
struct ThemePalette {
    var deep: Color
    var water: Color
    var shallow: Color
    var foam: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [shallow, water, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension FlushTheme {
    var palette: ThemePalette {
        switch self {
        case .classic:
            ThemePalette(deep: Color(red: 0.02, green: 0.10, blue: 0.32),
                         water: Color(red: 0.08, green: 0.44, blue: 0.86),
                         shallow: Color(red: 0.55, green: 0.86, blue: 1.00),
                         foam: .white)
        case .royal:
            ThemePalette(deep: Color(red: 0.24, green: 0.11, blue: 0.00),
                         water: Color(red: 0.86, green: 0.58, blue: 0.10),
                         shallow: Color(red: 1.00, green: 0.90, blue: 0.55),
                         foam: Color(red: 1.00, green: 0.97, blue: 0.86))
        case .toxic:
            ThemePalette(deep: Color(red: 0.02, green: 0.18, blue: 0.05),
                         water: Color(red: 0.28, green: 0.82, blue: 0.20),
                         shallow: Color(red: 0.78, green: 1.00, blue: 0.40),
                         foam: Color(red: 0.92, green: 1.00, blue: 0.82))
        case .blackHole:
            ThemePalette(deep: .black,
                         water: Color(red: 0.32, green: 0.10, blue: 0.58),
                         shallow: Color(red: 0.88, green: 0.52, blue: 1.00),
                         foam: Color(red: 0.96, green: 0.88, blue: 1.00))
        }
    }
}
