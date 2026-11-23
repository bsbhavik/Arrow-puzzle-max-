import SwiftUI

/// Geometry for ribbon arrows, in cell units (a cell centre is at col + 0.5, row + 0.5).
///
/// A ribbon's "track" is its body from tail to head followed by its lane straight out past the
/// edge. At travel `t` the ribbon covers track positions `t ... t + length`, so animating `t`
/// makes the whole body follow the head around every bend and off the board.
enum RibbonGeometry {
    static func track(for a: Arrow, boardSize n: Int) -> [CGPoint] {
        var pts = a.cells.map { CGPoint(x: CGFloat($0.c) + 0.5, y: CGFloat($0.r) + 0.5) }
        let h = a.pos
        if a.cells.count == 1 {
            pts.insert(CGPoint(x: CGFloat(h.c) + 0.5 - CGFloat(a.dir.dc) * 0.45,
                               y: CGFloat(h.r) + 0.5 - CGFloat(a.dir.dr) * 0.45), at: 0)
        }
        for k in 1...(n + a.cells.count + 3) {
            pts.append(CGPoint(x: CGFloat(h.c + a.dir.dc * k) + 0.5, y: CGFloat(h.r + a.dir.dr * k) + 0.5))
        }
        return pts
    }

    /// Track length covered by the body (a one-cell stub uses its virtual tail).
    static func length(for a: Arrow) -> CGFloat { CGFloat(max(1, a.cells.count - 1)) }

    static func point(_ track: [CGPoint], at t: CGFloat) -> CGPoint {
        let tt = max(0, min(t, CGFloat(track.count - 1)))
        let i = min(Int(tt), track.count - 2)
        let f = tt - CGFloat(i)
        let a = track[i], b = track[i + 1]
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    static func segment(_ track: [CGPoint], from a: CGFloat, to b: CGFloat) -> [CGPoint] {
        var out = [point(track, at: a)]
        var k = Int(a.rounded(.down)) + 1
        while CGFloat(k) < b && k < track.count {
            out.append(track[k])
            k += 1
        }
        out.append(point(track, at: b))
        return out
    }
}

struct RibbonBody: Shape {
    let track: [CGPoint]
    var start: CGFloat
    let length: CGFloat
    let cell: CGFloat

    var animatableData: CGFloat {
        get { start }
        set { start = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let pts = RibbonGeometry.segment(track, from: start, to: start + length)
        var p = Path()
        p.move(to: CGPoint(x: pts[0].x * cell, y: pts[0].y * cell))
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.x * cell, y: q.y * cell)) }
        return p
    }
}

struct RibbonHead: Shape {
    let track: [CGPoint]
    var start: CGFloat
    let length: CGFloat
    let cell: CGFloat
    let dir: Direction
    var headScale: CGFloat = 1
    var style: ArrowSkin.Head = .dart

    var animatableData: CGFloat {
        get { start }
        set { start = newValue }
    }

    func path(in rect: CGRect) -> Path {
        SkinHead.path(style, at: RibbonGeometry.point(track, at: start + length), dir: dir, cell: cell, scale: headScale)
    }
}

/// A fat version of the ribbon used only for hit testing, so taps don't need to be pixel-perfect.
struct RibbonHit: Shape {
    let track: [CGPoint]
    var start: CGFloat
    let length: CGFloat
    let cell: CGFloat

    func path(in rect: CGRect) -> Path {
        RibbonBody(track: track, start: start, length: length + 0.35, cell: cell)
            .path(in: rect)
            .strokedPath(StrokeStyle(lineWidth: cell * 0.9, lineCap: .round, lineJoin: .round))
    }
}

struct RibbonPiece: View {
    let arrow: Arrow
    let theme: GameTheme
    let locked: Bool
    let isHint: Bool
    /// Blink mode: no arrowhead, so you can't tell which end is the head.
    var hidden = false
    let cell: CGFloat
    let boardSize: Int
    var thin = false
    var lineMode: LineColorMode = .direction
    let onTap: () -> Void
    let onPreview: (Bool) -> Void

    @State private var pulse = false

    private var baseColor: Color {
        switch lineMode {
        case .direction:
            return theme.arrows[arrow.dir.rawValue]
        case .ink:
            return theme.text.opacity(0.9)
        case .regions:
            let half = max(1, boardSize / 2)
            let region = min(1, arrow.pos.r / half) * 2 + min(1, arrow.pos.c / half)
            return theme.arrows[region]
        }
    }

    private var color: Color {
        if hidden && arrow.kind != .key { return theme.text.opacity(0.7) }
        switch arrow.kind {
        case .key: return Color(hex: 0xF4B400)
        case .locked: return locked ? Color(hex: 0x8A8FA3) : baseColor
        default: return baseColor
        }
    }

    private var badge: String? {
        switch arrow.kind {
        case .bomb: return "flame.fill"
        case .key: return "key.fill"
        case .locked: return locked ? "lock.fill" : "lock.open.fill"
        default: return nil
        }
    }

    var body: some View {
        let track = RibbonGeometry.track(for: arrow, boardSize: boardSize)
        let len = RibbonGeometry.length(for: arrow)
        let w = thin ? max(1.6, cell * 0.13) : max(4, cell * 0.3)
        let ghost = arrow.kind == .ghost
        let glow = thin ? 0 : 3.0

        ZStack(alignment: .topLeading) {
            if isHint {
                RibbonBody(track: track, start: arrow.travel, length: len, cell: cell)
                    .stroke(theme.accent.opacity(pulse ? 0.85 : 0.25),
                            style: StrokeStyle(lineWidth: thin ? max(6, cell * 0.5) : w * 2.6,
                                               lineCap: .round, lineJoin: .round))
            }
            if hidden {
                // Same round dot on both ends. A one-cell stub is just a dot (its short tail would give it away).
                if arrow.cells.count > 1 {
                    theme.skin.ribbonStroke(RibbonBody(track: track, start: arrow.travel, length: len, cell: cell),
                                            color: color, width: w, inner: theme.tubeInner, ghost: ghost, thin: thin)
                }
                let d = max(w * 2.2, cell * (thin ? 0.32 : 0.42))
                ForEach([arrow.cells[0], arrow.pos], id: \.self) { p in
                    Circle().fill(color)
                        .frame(width: d, height: d)
                        .position(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell)
                }
            } else {
                theme.skin.ribbonStroke(RibbonBody(track: track, start: arrow.travel, length: len, cell: cell),
                                        color: color, width: w, inner: theme.tubeInner, ghost: ghost, thin: thin)
                RibbonHead(track: track, start: arrow.travel, length: len, cell: cell, dir: arrow.dir,
                           headScale: thin ? 0.8 : 1, style: theme.skin.head)
                    .fill(color)
                    .shadow(color: color.opacity(theme.skin.line == .neon ? 0.9 : 0.55), radius: glow)
            }

            if let badge {
                // Sits on the last straight segment, which always moves in a straight line.
                // When hidden it sits mid-body instead, so it doesn't mark which end is the head.
                let neck = hidden
                    ? RibbonGeometry.point(track, at: arrow.cells.count == 1 ? 1 : len / 2)
                    : CGPoint(x: CGFloat(arrow.pos.c) + 0.5 - CGFloat(arrow.dir.dc) * 0.55,
                              y: CGFloat(arrow.pos.r) + 0.5 - CGFloat(arrow.dir.dr) * 0.55)
                let s = max(13, w * 1.7)
                Image(systemName: badge)
                    .font(.system(size: s * 0.6, weight: .bold))
                    .foregroundStyle(arrow.kind == .bomb ? Color.orange : Color(hex: 0x3D2C00))
                    .frame(width: s, height: s)
                    .background(Circle().fill(.white))
                    .position(x: neck.x * cell, y: neck.y * cell)
                    .offset(x: arrow.travel * cell * CGFloat(arrow.travelDir.dc),
                            y: arrow.travel * cell * CGFloat(arrow.travelDir.dr))
            }
        }
        .contentShape(RibbonHit(track: track, start: arrow.travel, length: len, cell: cell))
        .modifier(PressToPlay(onTap: onTap, onPreview: onPreview))
        .onChangeCompat(of: isHint) { _, hint in
            if hint {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { pulse = false }
            }
        }
    }
}

/// Remembers when the board was last panned or pinched so those touches never count as taps.
enum TouchGate {
    static var blockedUntil = Date.distantPast
    static func mark(for seconds: Double = 0.25) {
        blockedUntil = max(blockedUntil, Date().addingTimeInterval(seconds))
    }
    static var recentlyMoved: Bool { Date() < blockedUntil }
}

/// Tap = move. Hold ~0.3s = preview the lane without moving. Dragging cancels both.
struct PressToPlay: ViewModifier {
    let onTap: () -> Void
    let onPreview: (Bool) -> Void

    @State private var pressTask: Task<Void, Never>?
    @State private var previewing = false
    @State private var pressed = false
    @State private var moved = false

    func body(content: Content) -> some View {
        content
            .brightness(pressed ? 0.12 : 0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if hypot(v.translation.width, v.translation.height) > 10 || TouchGate.recentlyMoved {
                            moved = true
                            pressed = false
                            pressTask?.cancel()
                        }
                        guard !moved, pressTask == nil, !previewing else { return }
                        pressed = true
                        pressTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            previewing = true
                            onPreview(true)
                        }
                    }
                    .onEnded { _ in
                        pressTask?.cancel()
                        pressTask = nil
                        pressed = false
                        let wasMoved = moved || TouchGate.recentlyMoved
                        moved = false
                        if previewing {
                            previewing = false
                            onPreview(false)
                        } else if !wasMoved {
                            onTap()
                        }
                    }
            )
    }
}
