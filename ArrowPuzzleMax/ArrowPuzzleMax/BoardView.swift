import SwiftUI

struct BoardView: View {
    @ObservedObject var engine: GameEngine
    let theme: GameTheme
    var background: BoardBackground = .dots
    var lineMode: LineColorMode = .direction

    // Pinch-to-zoom and pan (Ribbons and Maze).
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private var zoomable: Bool { engine.style != .tiles }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let n = engine.size
            let cell = side / CGFloat(n)

            board(side: side, n: n, cell: cell)
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .contentShape(Rectangle())
                .simultaneousGesture(magnify(side: side), including: zoomable ? .all : .subviews)
                .simultaneousGesture(pan(side: side), including: zoomable ? .all : .subviews)
                .overlay(alignment: .topTrailing) {
                    if scale > 1.02 {
                        Button {
                            TouchGate.mark(for: 0.45)   // no accidental taps while the board shrinks back
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { resetZoom() }
                        } label: {
                            Label("\(String(format: "%.1f", scale))×", systemImage: "arrow.down.right.and.arrow.up.left")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.text)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }
                        .padding(8)
                        .transition(.opacity)
                    }
                }
                .modifier(ShakeEffect(animatableData: engine.shake))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChangeCompat(of: engine.boardID) { _, _ in resetZoom() }
    }

    // MARK: - Layers

    private func board(side: CGFloat, n: Int, cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.board)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.text.opacity(0.08), lineWidth: 1))

            if engine.style == .tiles {
                ForEach(Array(0..<(n * n)), id: \.self) { k in
                    RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                        .fill(theme.cell)
                        .frame(width: cell * 0.86, height: cell * 0.86)
                        .position(center(Pos(r: k / n, c: k % n), cell))
                }
            } else {
                backgroundCanvas(cell: cell)
                    .frame(width: side, height: side)
                    .allowsHitTesting(false)
            }

            if let p = engine.preview {
                previewLayer(p, cell: cell)
            }

            ForEach(Array(engine.stones), id: \.self) { s in
                StoneView(theme: theme, size: cell * 0.8)
                    .position(center(s, cell))
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }

            if engine.style != .tiles {
                ForEach(engine.arrows) { a in
                    RibbonPiece(
                        arrow: a,
                        theme: theme,
                        locked: engine.isLocked(a),
                        isHint: engine.hintID == a.id,
                        hidden: engine.hidden && !a.escaping,
                        cell: cell,
                        boardSize: n,
                        thin: engine.style == .maze,
                        lineMode: lineMode,
                        onTap: { engine.tap(a.id) },
                        onPreview: { on in engine.setPreview(on ? a.id : nil) }
                    )
                    .frame(width: side, height: side)
                    .zIndex(a.escaping || a.travel > 0 ? 2 : 1)
                    .transition(.opacity)
                }
            }

            ForEach(engine.style == .tiles ? engine.arrows : []) { a in
                ArrowPiece(
                    arrow: a,
                    theme: theme,
                    locked: engine.isLocked(a),
                    isHint: engine.hintID == a.id,
                    hidden: engine.hidden && !a.escaping,
                    cell: cell,
                    onTap: { engine.tap(a.id) },
                    onPreview: { on in engine.setPreview(on ? a.id : nil) }
                )
                .frame(width: cell, height: cell)
                .position(center(a.pos, cell))
                .offset(x: a.travel * cell * CGFloat(a.travelDir.dc),
                        y: a.travel * cell * CGFloat(a.travelDir.dr))
                .opacity(a.escaping ? 0 : 1)
                .zIndex(a.escaping || a.travel > 0 ? 2 : 1)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }

            ForEach(engine.blasts) { b in
                BlastView(size: cell * 3)
                    .position(center(b.pos, cell))
                    .allowsHitTesting(false)
                    .zIndex(3)
            }

            ForEach(engine.floats) { f in
                FloatTextView(text: f.text, color: f.color, size: max(14, cell * 0.3) / scale)
                    .position(center(f.pos, cell))
                    .allowsHitTesting(false)
                    .zIndex(4)
            }
        }
        .frame(width: side, height: side)
    }

    /// Dots or grid lines over the board's shape, drawn in one pass so huge mazes stay fast.
    private func backgroundCanvas(cell: CGFloat) -> some View {
        let cells = engine.playable
        let ink = theme.text
        let mode = background
        return Canvas { ctx, _ in
            switch mode {
            case .dots:
                let d = max(2, cell * 0.12)
                var path = Path()
                for p in cells {
                    path.addEllipse(in: CGRect(x: (CGFloat(p.c) + 0.5) * cell - d / 2,
                                               y: (CGFloat(p.r) + 0.5) * cell - d / 2, width: d, height: d))
                }
                ctx.fill(path, with: .color(ink.opacity(0.16)))
            case .grid:
                var path = Path()
                for p in cells {
                    path.addRect(CGRect(x: CGFloat(p.c) * cell, y: CGFloat(p.r) * cell, width: cell, height: cell))
                }
                ctx.fill(path, with: .color(ink.opacity(0.03)))
                ctx.stroke(path, with: .color(ink.opacity(0.1)), lineWidth: 0.6)
            case .plain:
                break
            }
        }
    }

    // MARK: - Zoom

    private func clampOffset(_ o: CGSize, side: CGFloat) -> CGSize {
        let limit = (scale - 1) * side / 2
        return CGSize(width: min(limit, max(-limit, o.width)), height: min(limit, max(-limit, o.height)))
    }

    private func magnify(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { v in
                TouchGate.mark()
                scale = min(4, max(1, baseScale * v))
                offset = clampOffset(offset, side: side)
            }
            .onEnded { _ in
                TouchGate.mark()
                baseScale = scale
                offset = clampOffset(offset, side: side)
                baseOffset = offset
            }
    }

    private func pan(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                guard scale > 1.02 else { return }
                TouchGate.mark()
                offset = clampOffset(CGSize(width: baseOffset.width + v.translation.width,
                                            height: baseOffset.height + v.translation.height), side: side)
            }
            .onEnded { _ in
                guard scale > 1.02 else { return }
                TouchGate.mark()
                baseOffset = offset
            }
    }

    private func resetZoom() {
        scale = 1
        baseScale = 1
        offset = .zero
        baseOffset = .zero
    }

    private func center(_ p: Pos, _ cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell)
    }

    @ViewBuilder
    private func previewLayer(_ p: RayPreview, cell: CGFloat) -> some View {
        let ok = p.blockedAt == nil && !p.locked
        let tint: Color = ok ? .green : .red
        ForEach(Array(p.cells.enumerated()), id: \.offset) { i, c in
            RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                .fill(tint.opacity(0.32 - Double(i) * 0.02))
                .frame(width: cell * 0.86, height: cell * 0.86)
                .position(center(c, cell))
        }
        if let b = p.blockedAt {
            RoundedRectangle(cornerRadius: cell * 0.26, style: .continuous)
                .stroke(Color.red, lineWidth: 3)
                .frame(width: cell * 0.9, height: cell * 0.9)
                .position(center(b, cell))
        }
        if p.locked {
            Circle()
                .stroke(Color.red, lineWidth: 3)
                .frame(width: cell * 0.95, height: cell * 0.95)
                .position(center(p.origin, cell))
        }
    }
}

// MARK: - Arrow tile

struct ArrowPiece: View {
    let arrow: Arrow
    let theme: GameTheme
    let locked: Bool
    let isHint: Bool
    /// Blink mode: hide which way the arrow points.
    var hidden = false
    let cell: CGFloat
    let onTap: () -> Void
    let onPreview: (Bool) -> Void

    @State private var pressTask: Task<Void, Never>?
    @State private var previewing = false
    @State private var pressed = false
    @State private var pulse = false

    private var baseColor: Color {
        let dirColor = hidden ? theme.text.opacity(0.55) : theme.arrows[arrow.dir.rawValue]
        switch arrow.kind {
        case .key: return Color(hex: 0xF4B400)
        case .ghost: return dirColor.opacity(0.35)
        case .locked: return locked ? Color(hex: 0x6B7280) : dirColor
        default: return dirColor
        }
    }

    private var badge: String? {
        switch arrow.kind {
        case .bomb: return "flame.fill"
        case .key: return "key.fill"
        case .locked: return locked ? "lock.fill" : "lock.open.fill"
        case .ghost: return "sparkles"
        default: return nil
        }
    }

    var body: some View {
        let s = cell * 0.8
        let skin = theme.skin
        let tileShape = SkinTileShape(tile: skin.tile)
        ZStack {
            if skin.outlined {
                tileShape.fill(baseColor.opacity(0.14))
                tileShape.stroke(baseColor, style: StrokeStyle(lineWidth: max(1.5, s * 0.06),
                                                               dash: arrow.kind == .ghost ? [5, 4] : []))
            } else {
                tileShape
                    .fill(LinearGradient(colors: [baseColor.opacity(0.85), baseColor],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        tileShape.stroke(.white.opacity(arrow.kind == .ghost ? 0.8 : 0.25),
                                         style: StrokeStyle(lineWidth: arrow.kind == .ghost ? 2 : 1,
                                                            dash: arrow.kind == .ghost ? [5, 4] : []))
                    )
                    .shadow(color: baseColor.opacity(skin.line == .neon ? 0.8 : 0.45),
                            radius: skin.line == .neon ? 7 : 4, y: 3)
            }

            Image(systemName: hidden ? "questionmark" : (arrow.kind == .twin ? skin.twinGlyph : skin.glyph))
                .font(.system(size: s * skin.glyphScale, weight: .black))
                .foregroundStyle(skin.outlined ? baseColor : .white)
                .shadow(color: .black.opacity(skin.outlined ? 0 : 0.25), radius: 1, y: 1)
                .rotationEffect(.degrees(hidden ? 0 : arrow.dir.degrees))
                .replaceSymbolTransition()

            if let badge {
                Image(systemName: badge)
                    .font(.system(size: s * 0.2, weight: .bold))
                    .foregroundStyle(arrow.kind == .bomb ? Color.orange : Color(hex: 0x3D2C00))
                    .padding(s * 0.06)
                    .background(Circle().fill(.white))
                    .offset(x: s * 0.36, y: -s * 0.36)
            }
        }
        .frame(width: s, height: s)
        .overlay {
            if isHint {
                SkinTileShape(tile: theme.skin.tile)
                    .stroke(theme.accent, lineWidth: 3)
                    .frame(width: s * 1.12, height: s * 1.12)
                    .opacity(pulse ? 1 : 0.3)
            }
        }
        .scaleEffect(pressed ? 0.88 : (isHint && pulse ? 1.1 : 1))
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
        .contentShape(Rectangle())
        .gesture(pressGesture)
        .onChangeCompat(of: isHint) { _, hint in
            if hint {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { pulse = false }
            }
        }
        .onChangeCompat(of: locked) { _, isLocked in
            if !isLocked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { pressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pressed = false }
            }
        }
    }

    /// Tap = move. Hold ~0.3s = preview the lane without moving.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard pressTask == nil, !previewing else { return }
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
                if previewing {
                    previewing = false
                    onPreview(false)
                } else {
                    onTap()
                }
            }
    }
}

// MARK: - Small pieces

struct StoneView: View {
    let theme: GameTheme
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(LinearGradient(colors: [theme.stone.opacity(0.9), theme.stone],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(.black.opacity(0.18))
            )
            .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1))
            .frame(width: size, height: size)
    }
}

struct BlastView: View {
    let size: CGFloat
    @State private var go = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.yellow, .orange, .red.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size / 2))
                .scaleEffect(go ? 1 : 0.1)
                .opacity(go ? 0 : 1)
            Circle()
                .stroke(Color.orange, lineWidth: 4)
                .scaleEffect(go ? 1.1 : 0.2)
                .opacity(go ? 0 : 1)
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                    .offset(x: go ? size * 0.5 : 0)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .opacity(go ? 0 : 1)
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { go = true } }
    }
}

struct FloatTextView: View {
    let text: String
    let color: Color
    let size: CGFloat
    @State private var go = false

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            .fixedSize()
            .offset(y: go ? -50 : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 1.15 : 0.8)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { go = true } }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 6), y: 0))
    }
}
