import SwiftUI

enum StudioTheme {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.99)
    static let ink = Color(red: 0.15, green: 0.17, blue: 0.27)
    static let accent = Color(red: 0.36, green: 0.3, blue: 0.69)
    static let lavender = Color(red: 0.91, green: 0.89, blue: 0.98)
}

extension CostumeColor {
    var uiColor: UIColor {
        switch self {
        case .lilac: UIColor(red: 0.58, green: 0.4, blue: 0.83, alpha: 1)
        case .seafoam: UIColor(red: 0.18, green: 0.65, blue: 0.57, alpha: 1)
        case .sunset: UIColor(red: 0.92, green: 0.42, blue: 0.4, alpha: 1)
        }
    }
}
