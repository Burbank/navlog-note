import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case bright, dim, system
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

struct Palette {
    let bg: Color
    let panel: Color
    let line: Color
    let text: Color
    let muted: Color
    let accent: Color
    let btn: Color
    let btnPress: Color
    let btnText: Color
    let ok: Color
    let field: Color
    let fieldBorder: Color
    let warn: Color
    let placeholder: Color
    let softWarn: Color

    static let dim = Palette(
        bg: Color(hex: 0x1A2332),
        panel: Color(hex: 0x243044),
        line: Color(hex: 0x3D4F66),
        text: Color(hex: 0xE8EEF6),
        muted: Color(hex: 0x9AADC2),
        accent: Color(hex: 0x00A1E4),
        btn: Color(hex: 0x0080B5),
        btnPress: Color(hex: 0x003D5C),
        btnText: .white,
        ok: Color(hex: 0x3DB88A),
        field: Color(hex: 0x15202E),
        fieldBorder: Color(hex: 0x4A607A),
        warn: Color(hex: 0xC45C5C),
        placeholder: Color(hex: 0x6B7F96),
        softWarn: Color(hex: 0xB44646).opacity(0.28)
    )

    static let bright = Palette(
        bg: .white,
        panel: .white,
        line: .black,
        text: .black,
        muted: Color(hex: 0x333333),
        accent: Color(hex: 0x003D7A),
        btn: Color(hex: 0x003D7A),
        btnPress: Color(hex: 0x001A33),
        btnText: .white,
        ok: Color(hex: 0x005C32),
        field: .white,
        fieldBorder: .black,
        warn: Color(hex: 0x8B0000),
        placeholder: Color(hex: 0x8A8A8A),
        softWarn: Color(hex: 0xFFB8B8)
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum AppTheme {
    static func palette(mode: ThemeMode, systemBright: Bool) -> Palette {
        switch mode {
        case .bright: return .bright
        case .dim: return .dim
        case .system: return systemBright ? .bright : .dim
        }
    }
}
