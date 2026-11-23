import SwiftUI

/// How a theme draws its arrows: tile shape, arrow symbol, ribbon line and arrowhead.
struct ArrowSkin {
    enum Tile { case rounded, circle, square, hexagon, octagon, diamond }
    enum Head { case dart, triangle, chevron, round, diamond }
    enum Line { case solid, dotted, dashed, tube, neon }

    var tile: Tile = .rounded
    /// SF Symbol pointing up.
    var glyph = "arrow.up"
    /// Hollow tiles with a coloured outline and glyph (instead of a filled tile with a white glyph).
    var outlined = false
    var head: Head = .dart
    var line: Line = .solid
    var squareCaps = false

    var twinGlyph: String { glyph.hasPrefix("chevron") ? "chevron.up.chevron.down" : "arrow.up.and.down" }

    var glyphScale: CGFloat { tile == .diamond ? 0.42 : (glyph.hasPrefix("chevron") ? 0.46 : 0.5) }

    var lineCap: CGLineCap { squareCaps ? .square : .round }

    var title: String {
        let t: String = switch tile {
        case .rounded: "Rounded"
        case .circle: "Bubble"
        case .square: "Block"
        case .hexagon: "Hex"
        case .octagon: "Gem"
        case .diamond: "Diamond"
        }
        let l: String = switch line {
        case .solid: "solid"
        case .dotted: "dotted"
        case .dashed: "dashed"
        case .tube: "tube"
        case .neon: "neon"
        }
        return "\(t) tiles · \(l) lines"
    }
}

// MARK: - Tile shape

struct SkinTileShape: Shape {
    let tile: ArrowSkin.Tile

    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        switch tile {
        case .rounded:
            return RoundedRectangle(cornerRadius: w * 0.28, style: .continuous).path(in: r)
        case .circle:
            return Ellipse().path(in: r)
        case .square:
            return RoundedRectangle(cornerRadius: w * 0.08, style: .continuous).path(in: r)
        case .hexagon:
            return polygon(r, corners: 6, rotation: -.pi / 2)
        case .octagon:
            let c = w * 0.29
            var p = Path()
            p.addLines([CGPoint(x: r.minX + c, y: r.minY), CGPoint(x: r.maxX - c, y: r.minY),
                        CGPoint(x: r.maxX, y: r.minY + c), CGPoint(x: r.maxX, y: r.maxY - c),
                        CGPoint(x: r.maxX - c, y: r.maxY), CGPoint(x: r.minX + c, y: r.maxY),
                        CGPoint(x: r.minX, y: r.maxY - c), CGPoint(x: r.minX, y: r.minY + c)])
            p.closeSubpath()
            return p
        case .diamond:
            var p = Path()
            p.addLines([CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.midY),
                        CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.minX, y: r.midY)])
            p.closeSubpath()
            _ = h
            return p
        }
    }

    private func polygon(_ r: CGRect, corners: Int, rotation: CGFloat) -> Path {
        let radius = min(r.width, r.height) / 2
        var p = Path()
        for i in 0..<corners {
            let a = rotation + CGFloat(i) * 2 * .pi / CGFloat(corners)
            let pt = CGPoint(x: r.midX + cos(a) * radius, y: r.midY + sin(a) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Arrowheads

enum SkinHead {
    /// Arrowhead centred on `h` (cell units), pointing along `dir`, drawn at `cell` points per unit.
    static func path(_ style: ArrowSkin.Head, at h: CGPoint, dir: Direction, cell: CGFloat, scale k: CGFloat) -> Path {
        let dx = CGFloat(dir.dc), dy = CGFloat(dir.dr)
        func pt(_ along: CGFloat, _ side: CGFloat) -> CGPoint {
            CGPoint(x: (h.x + dx * along * k - dy * side * k) * cell, y: (h.y + dy * along * k + dx * side * k) * cell)
        }
        var p = Path()
        switch style {
        case .dart:
            p.addLines([pt(0.42, 0), pt(-0.08, 0.3), pt(0.02, 0), pt(-0.08, -0.3)])
        case .triangle:
            p.addLines([pt(0.42, 0), pt(-0.1, 0.3), pt(-0.1, -0.3)])
        case .chevron:
            p.addLines([pt(0.42, 0), pt(-0.02, 0.34), pt(-0.14, 0.24), pt(0.22, 0), pt(-0.14, -0.24), pt(-0.02, -0.34)])
        case .round:
            let c = pt(0.12, 0), r = 0.24 * k * cell
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            return p
        case .diamond:
            p.addLines([pt(0.44, 0), pt(0.12, 0.24), pt(-0.2, 0), pt(0.12, -0.24)])
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Ribbon line styles

extension ArrowSkin {
    /// Draws a ribbon body in this skin's line style (used by live ribbons, which animate).
    @ViewBuilder
    func ribbonStroke<S: Shape>(_ shape: S, color: Color, width w: CGFloat, inner: Color,
                                ghost: Bool, thin: Bool) -> some View {
        let cap = lineCap
        if ghost {
            shape.stroke(color.opacity(0.75),
                         style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round, dash: [w * 0.5, w * 0.9]))
        } else {
            switch line {
            case .solid:
                shape.stroke(color, style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round))
                    .shadow(color: color.opacity(thin ? 0 : 0.5), radius: 3)
            case .dotted:
                shape.stroke(color, style: StrokeStyle(lineWidth: w * 1.15, lineCap: .round, lineJoin: .round,
                                                       dash: [0.001, w * 1.9]))
            case .dashed:
                shape.stroke(color, style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round,
                                                       dash: [w * 1.7, w * 1.1]))
            case .tube:
                ZStack {
                    shape.stroke(color, style: StrokeStyle(lineWidth: w * 1.5, lineCap: cap, lineJoin: .round))
                    shape.stroke(inner, style: StrokeStyle(lineWidth: w * 0.55, lineCap: cap, lineJoin: .round))
                }
            case .neon:
                ZStack {
                    shape.stroke(color, style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round))
                        .shadow(color: color, radius: thin ? 2 : w * 0.9)
                    shape.stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: max(1, w * 0.3),
                                                                          lineCap: cap, lineJoin: .round))
                }
            }
        }
    }

    /// Same styles for Canvas drawing (editor and thumbnails).
    func strokeRibbon(_ ctx: inout GraphicsContext, _ path: Path, color: Color, width w: CGFloat,
                      inner: Color, ghost: Bool) {
        let cap = lineCap
        if ghost {
            ctx.stroke(path, with: .color(color.opacity(0.75)),
                       style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round, dash: [w * 0.6, w]))
            return
        }
        switch line {
        case .solid:
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round))
        case .dotted:
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: w * 1.15, lineCap: .round, lineJoin: .round, dash: [0.001, w * 1.9]))
        case .dashed:
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round, dash: [w * 1.7, w * 1.1]))
        case .tube:
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w * 1.5, lineCap: cap, lineJoin: .round))
            ctx.stroke(path, with: .color(inner), style: StrokeStyle(lineWidth: w * 0.55, lineCap: cap, lineJoin: .round))
        case .neon:
            ctx.stroke(path, with: .color(color.opacity(0.35)),
                       style: StrokeStyle(lineWidth: w * 2.2, lineCap: cap, lineJoin: .round))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: .round))
            ctx.stroke(path, with: .color(.white.opacity(0.85)),
                       style: StrokeStyle(lineWidth: max(1, w * 0.3), lineCap: cap, lineJoin: .round))
        }
    }
}

extension GameTheme {
    /// Colour inside "tube" lines.
    var tubeInner: Color { dark ? background[0] : .white }
}

// MARK: - Small decorative pieces

/// A single arrow tile in a theme's skin (logo, shop, previews).
struct SkinTileView: View {
    let dir: Direction
    let theme: GameTheme
    var size: CGFloat = 40
    var color: Color? = nil

    var body: some View {
        let skin = theme.skin
        let c = color ?? theme.arrows[dir.rawValue]
        ZStack {
            if skin.outlined {
                SkinTileShape(tile: skin.tile).fill(c.opacity(0.14))
                SkinTileShape(tile: skin.tile).stroke(c, lineWidth: max(1.5, size * 0.06))
            } else {
                SkinTileShape(tile: skin.tile)
                    .fill(LinearGradient(colors: [c.opacity(0.85), c], startPoint: .top, endPoint: .bottom))
            }
            Image(systemName: skin.glyph)
                .font(.system(size: size * skin.glyphScale, weight: .black))
                .foregroundStyle(skin.outlined ? c : .white)
                .rotationEffect(.degrees(dir.degrees))
        }
        .frame(width: size, height: size)
    }
}

/// A tiny bent ribbon in a theme's skin, for the shop.
struct SkinRibbonSample: View {
    let theme: GameTheme
    var cell: CGFloat = 12

    var body: some View {
        let a = Arrow(id: 0, cells: [Pos(r: 1, c: 0), Pos(r: 1, c: 1), Pos(r: 1, c: 2), Pos(r: 0, c: 2), Pos(r: 0, c: 3)],
                      dir: .right, kind: .normal)
        let track = RibbonGeometry.track(for: a, boardSize: 5)
        let len = RibbonGeometry.length(for: a)
        let color = theme.arrows[1]
        ZStack(alignment: .topLeading) {
            theme.skin.ribbonStroke(RibbonBody(track: track, start: 0, length: len, cell: cell),
                                    color: color, width: cell * 0.3, inner: theme.tubeInner, ghost: false, thin: false)
            RibbonHead(track: track, start: 0, length: len, cell: cell, dir: a.dir, style: theme.skin.head)
                .fill(color)
        }
        .frame(width: cell * 4.6, height: cell * 2)
    }
}
