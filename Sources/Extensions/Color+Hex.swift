import SwiftUI

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 8: // ARGB
            a = (int & 0xff000000) >> 24
            r = (int & 0x00ff0000) >> 16
            g = (int & 0x0000ff00) >> 8
            b = int & 0x000000ff
        case 6: // RGB
            a = 255
            r = (int & 0xff0000) >> 16
            g = (int & 0x00ff00) >> 8
            b = int & 0x0000ff
        default:
            a = 255; r = 0; g = 0; b = 0
        }

        let red = min(max(Double(r) / 255.0, 0.0), 1.0)
        let green = min(max(Double(g) / 255.0, 0.0), 1.0)
        let blue = min(max(Double(b) / 255.0, 0.0), 1.0)
        let alpha = min(max(Double(a) / 255.0, 0.0), 1.0)

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
