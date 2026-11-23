import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

struct GameTheme: Identifiable {
    let id: String
    let name: String
    let background: [Color]
    let board: Color
    let cell: Color
    let text: Color
    let subtext: Color
    let accent: Color
    let stone: Color
    /// Arrow colour per direction: up, right, down, left.
    let arrows: [Color]
    let dark: Bool
    /// Coins needed to unlock. 0 = free.
    var price = 0

    static let neon = GameTheme(
        id: "neon", name: "Neon Night",
        background: [Color(hex: 0x0F0C29), Color(hex: 0x302B63), Color(hex: 0x24243E)],
        board: .white.opacity(0.06), cell: .white.opacity(0.07),
        text: .white, subtext: .white.opacity(0.65), accent: Color(hex: 0x00F5D4),
        stone: Color(hex: 0x5C5F7A),
        arrows: [Color(hex: 0xFF4D6D), Color(hex: 0x00A6FB), Color(hex: 0xFF9F1C), Color(hex: 0x9B5DE5)],
        dark: true)

    static let sunset = GameTheme(
        id: "sunset", name: "Sunset Glow",
        background: [Color(hex: 0xFF7E5F), Color(hex: 0xE0457B), Color(hex: 0x6A3093)],
        board: .white.opacity(0.14), cell: .white.opacity(0.16),
        text: .white, subtext: .white.opacity(0.75), accent: Color(hex: 0xFFE66D),
        stone: Color(hex: 0x4A2545),
        arrows: [Color(hex: 0x3A0CA3), Color(hex: 0x0096C7), Color(hex: 0x2B9348), Color(hex: 0xD00000)],
        dark: true)

    static let ocean = GameTheme(
        id: "ocean", name: "Deep Ocean",
        background: [Color(hex: 0x021B2E), Color(hex: 0x05445E), Color(hex: 0x0A6C74)],
        board: .white.opacity(0.07), cell: .white.opacity(0.08),
        text: .white, subtext: .white.opacity(0.65), accent: Color(hex: 0x7CF5D8),
        stone: Color(hex: 0x37505C),
        arrows: [Color(hex: 0xFF6B6B), Color(hex: 0xF4A261), Color(hex: 0x2EC4B6), Color(hex: 0x5E60CE)],
        dark: true)

    static let mint = GameTheme(
        id: "mint", name: "Mint Paper",
        background: [Color(hex: 0xF6FFF8), Color(hex: 0xE3F4EA), Color(hex: 0xD3EEDD)],
        board: .black.opacity(0.04), cell: .black.opacity(0.05),
        text: Color(hex: 0x1D3557), subtext: Color(hex: 0x1D3557, opacity: 0.6), accent: Color(hex: 0xE63946),
        stone: Color(hex: 0x6C7A89),
        arrows: [Color(hex: 0xE63946), Color(hex: 0x1D3557), Color(hex: 0xF77F00), Color(hex: 0x2A9D8F)],
        dark: false)

    static let forest = GameTheme(
        id: "forest", name: "Forest Night",
        background: [Color(hex: 0x081C15), Color(hex: 0x1B4332), Color(hex: 0x0B2B1E)],
        board: .white.opacity(0.06), cell: .white.opacity(0.07),
        text: .white, subtext: .white.opacity(0.65), accent: Color(hex: 0xB7E4C7),
        stone: Color(hex: 0x40594A),
        arrows: [Color(hex: 0xE76F51), Color(hex: 0x219EBC), Color(hex: 0xE9A23B), Color(hex: 0x9D4EDD)],
        dark: true, price: 150)

    static let candy = GameTheme(
        id: "candy", name: "Candy Pop",
        background: [Color(hex: 0xFFF0F6), Color(hex: 0xFFDEEB), Color(hex: 0xE5DBFF)],
        board: .black.opacity(0.04), cell: .black.opacity(0.05),
        text: Color(hex: 0x5F3DC4), subtext: Color(hex: 0x5F3DC4, opacity: 0.6), accent: Color(hex: 0xF06595),
        stone: Color(hex: 0xB197FC),
        arrows: [Color(hex: 0xF03E3E), Color(hex: 0x1C7ED6), Color(hex: 0xF59F00), Color(hex: 0x7048E8)],
        dark: false, price: 300)

    static let lava = GameTheme(
        id: "lava", name: "Lava Core",
        background: [Color(hex: 0x1A0500), Color(hex: 0x5C1A00), Color(hex: 0x2B0A00)],
        board: .white.opacity(0.06), cell: .white.opacity(0.07),
        text: .white, subtext: .white.opacity(0.7), accent: Color(hex: 0xFFB703),
        stone: Color(hex: 0x4A2C2A),
        arrows: [Color(hex: 0xFF006E), Color(hex: 0x3A86FF), Color(hex: 0xFB5607), Color(hex: 0x8338EC)],
        dark: true, price: 500)

    static let arctic = GameTheme(
        id: "arctic", name: "Arctic Ice",
        background: [Color(hex: 0xF0F9FF), Color(hex: 0xDBEAFE), Color(hex: 0xE0F2FE)],
        board: .black.opacity(0.04), cell: .black.opacity(0.05),
        text: Color(hex: 0x0C4A6E), subtext: Color(hex: 0x0C4A6E, opacity: 0.6), accent: Color(hex: 0x0284C7),
        stone: Color(hex: 0x94A3B8),
        arrows: [Color(hex: 0xE11D48), Color(hex: 0x2563EB), Color(hex: 0x0D9488), Color(hex: 0x7C3AED)],
        dark: false, price: 750)

    static let sakura = GameTheme(
        id: "sakura", name: "Sakura",
        background: [Color(hex: 0xFFF5F7), Color(hex: 0xFFE4EC), Color(hex: 0xFCE7F3)],
        board: .black.opacity(0.04), cell: .black.opacity(0.05),
        text: Color(hex: 0x831843), subtext: Color(hex: 0x831843, opacity: 0.6), accent: Color(hex: 0xDB2777),
        stone: Color(hex: 0xC9A3B6),
        arrows: [Color(hex: 0xDB2777), Color(hex: 0x7C3AED), Color(hex: 0x0EA5E9), Color(hex: 0x059669)],
        dark: false, price: 1000)

    static let terminal = GameTheme(
        id: "terminal", name: "Retro Terminal",
        background: [Color(hex: 0x000000), Color(hex: 0x001A00), Color(hex: 0x000000)],
        board: Color(hex: 0x39FF14, opacity: 0.05), cell: Color(hex: 0x39FF14, opacity: 0.06),
        text: Color(hex: 0x39FF14), subtext: Color(hex: 0x39FF14, opacity: 0.6), accent: Color(hex: 0x39FF14),
        stone: Color(hex: 0x1F3A1F),
        arrows: [Color(hex: 0x16A34A), Color(hex: 0x0891B2), Color(hex: 0xCA8A04), Color(hex: 0xDB2777)],
        dark: true, price: 1500)

    static let royal = GameTheme(
        id: "royal", name: "Royal Gold",
        background: [Color(hex: 0x1C1917), Color(hex: 0x292524), Color(hex: 0x0C0A09)],
        board: Color(hex: 0xFACC15, opacity: 0.05), cell: Color(hex: 0xFACC15, opacity: 0.06),
        text: Color(hex: 0xFDE68A), subtext: Color(hex: 0xFDE68A, opacity: 0.6), accent: Color(hex: 0xFACC15),
        stone: Color(hex: 0x57534E),
        arrows: [Color(hex: 0xDC2626), Color(hex: 0xCA8A04), Color(hex: 0x16A34A), Color(hex: 0x2563EB)],
        dark: true, price: 3000)

    static let galaxy = GameTheme(
        id: "galaxy", name: "Galaxy",
        background: [Color(hex: 0x03071E), Color(hex: 0x3C096C), Color(hex: 0x10002B)],
        board: .white.opacity(0.06), cell: .white.opacity(0.07),
        text: .white, subtext: .white.opacity(0.7), accent: Color(hex: 0xF72585),
        stone: Color(hex: 0x3C096C),
        arrows: [Color(hex: 0x4CC9F0), Color(hex: 0xF72585), Color(hex: 0x4361EE), Color(hex: 0xB5179E)],
        dark: true, price: 5000)

    static let all: [GameTheme] = [
        .neon, .mint, .forest, .sunset.priced(200), .ocean.priced(250), .candy, .lava,
        .arctic, .sakura, .terminal, .royal, .galaxy,
    ]

    /// Every theme draws its arrows differently, not just in different colours.
    var skin: ArrowSkin { Self.skins[id] ?? ArrowSkin() }

    private static let skins: [String: ArrowSkin] = [
        "neon":     ArrowSkin(tile: .rounded, glyph: "arrow.up", head: .dart, line: .neon),
        "mint":     ArrowSkin(tile: .square, glyph: "arrowshape.up.fill", head: .triangle, line: .solid, squareCaps: true),
        "forest":   ArrowSkin(tile: .circle, glyph: "chevron.up", head: .chevron, line: .solid),
        "sunset":   ArrowSkin(tile: .circle, glyph: "arrowtriangle.up.fill", head: .round, line: .tube),
        "ocean":    ArrowSkin(tile: .rounded, glyph: "location.north.fill", head: .triangle, line: .dashed),
        "candy":    ArrowSkin(tile: .circle, glyph: "arrowshape.up.fill", head: .round, line: .dotted),
        "lava":     ArrowSkin(tile: .diamond, glyph: "arrowtriangle.up.fill", head: .triangle, line: .neon),
        "arctic":   ArrowSkin(tile: .hexagon, glyph: "chevron.up", head: .chevron, line: .tube),
        "sakura":   ArrowSkin(tile: .circle, glyph: "arrow.up", head: .diamond, line: .dashed),
        "terminal": ArrowSkin(tile: .square, glyph: "chevron.up", outlined: true, head: .chevron, line: .dashed, squareCaps: true),
        "royal":    ArrowSkin(tile: .octagon, glyph: "arrowtriangle.up.fill", head: .diamond, line: .tube),
        "galaxy":   ArrowSkin(tile: .circle, glyph: "location.north.fill", head: .dart, line: .neon),
    ]

    private func priced(_ p: Int) -> GameTheme {
        var t = self
        t.price = p
        return t
    }
}

/// Gradient background with slowly drifting arrow silhouettes.
struct ThemeBackground: View {
    let theme: GameTheme
    var animated = true

    private let drifters: [(x: CGFloat, y: CGFloat, size: CGFloat, dir: Direction, speed: Double)] = [
        (0.12, 0.15, 60, .up, 0.6), (0.85, 0.22, 90, .left, 0.4), (0.25, 0.55, 70, .right, 0.5),
        (0.78, 0.62, 110, .down, 0.3), (0.5, 0.88, 80, .up, 0.45), (0.1, 0.85, 50, .right, 0.7),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            if animated {
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    GeometryReader { geo in
                        ForEach(drifters.indices, id: \.self) { i in
                            let d = drifters[i]
                            Image(systemName: "arrow.up")
                                .font(.system(size: d.size, weight: .black))
                                .rotationEffect(.degrees(d.dir.degrees))
                                .foregroundStyle(theme.text.opacity(0.05))
                                .position(x: geo.size.width * d.x + CGFloat(sin(t * d.speed + Double(i))) * 18,
                                          y: geo.size.height * d.y + CGFloat(cos(t * d.speed * 0.8 + Double(i))) * 22)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

enum Haptics {
    static var enabled = true

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func heavy() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
