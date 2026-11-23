import SwiftUI

// MARK: - My Levels

struct MyLevelsView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @Binding var path: [Route]

    @State private var importing = false
    @State private var importText = ""
    @State private var importFailed = false
    @State private var pendingDelete: CustomLevel?

    var body: some View {
        let t = store.theme
        ZStack {
            ThemeBackground(theme: t, animated: false)
            VStack(spacing: 14) {
                HStack {
                    CircleButton(icon: "chevron.left", theme: t) { dismiss() }
                    Spacer()
                    Text("Level Creator")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(t.text)
                    Spacer()
                    CircleButton(icon: "square.and.arrow.down", theme: t) {
                        importText = UIPasteboard.general.string ?? ""
                        importing = true
                    }
                }
                .padding(.horizontal)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        BigButton(title: "New Level", icon: "plus", color: t.accent, ink: .black) {
                            let level = CustomLevel(name: "Level \(store.customLevels.count + 1)",
                                                    style: store.style,
                                                    size: store.style == .tiles ? 6 : 10)
                            path.append(.editor(level))
                        }

                        if store.customLevels.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "hammer.fill").font(.largeTitle)
                                Text("Make your own puzzle").font(.headline)
                                Text("Draw arrows, add stones and special arrows, pick a size and shape (even a cat!), then test it and share the code with friends.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .opacity(0.75)
                            }
                            .foregroundStyle(t.text)
                            .padding(24)
                        }

                        ForEach(store.customLevels) { level in
                            levelCard(level, t)
                        }
                    }
                    .padding()
                    .readableWidth(680)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Import level", isPresented: $importing) {
            TextField("Paste a level code", text: $importText)
            Button("Import") {
                if let level = CustomLevel.from(code: importText) {
                    store.saveCustom(level)
                    Haptics.success()
                } else {
                    importFailed = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Paste a code that starts with APM1:")
        }
        .alert("That code didn't work", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Make sure you copied the whole code.")
        }
        .confirmationDialog("Delete \"\(pendingDelete?.name ?? "")\"?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let l = pendingDelete { withAnimation { store.deleteCustom(l.id) } }
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func levelCard(_ level: CustomLevel, _ t: GameTheme) -> some View {
        let playable = level.isPlayable
        return HStack(spacing: 14) {
            LevelCanvas(level: level, theme: t, showCells: false)
                .frame(width: 76, height: 76)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(t.board))

            VStack(alignment: .leading, spacing: 4) {
                Text(level.name)
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .lineLimit(1)
                Text("\(level.style.title) · \(level.size)×\(level.size) · \(level.arrows.count) arrows")
                    .font(.caption.weight(.semibold))
                    .opacity(0.7)
                Label(playable ? "Ready to play" : (level.arrows.isEmpty ? "Empty" : "Needs fixing"),
                      systemImage: playable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(playable ? Color.green : Color.orange)
                HStack(spacing: 8) {
                    smallButton("play.fill", t, enabled: playable) { path.append(.playCustom(level)) }
                    smallButton("pencil", t) { path.append(.editor(level)) }
                    ShareLink(item: level.shareCode, preview: SharePreview(level.name)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 34, height: 30)
                            .background(Capsule().fill(t.text.opacity(0.12)))
                    }
                    smallButton("trash", t) { pendingDelete = level }
                }
                .padding(.top, 2)
            }
            .foregroundStyle(t.text)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(t.text.opacity(0.08)))
    }

    private func smallButton(_ icon: String, _ t: GameTheme, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .frame(width: 34, height: 30)
                .background(Capsule().fill(t.text.opacity(0.12)))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

// MARK: - Editor

enum EditorTool: String, CaseIterable, Identifiable {
    case draw, stone, erase
    var id: String { rawValue }
    var title: String {
        switch self {
        case .draw: return "Draw"
        case .stone: return "Stone"
        case .erase: return "Erase"
        }
    }
    var icon: String {
        switch self {
        case .draw: return "pencil.tip"
        case .stone: return "square.grid.2x2.fill"
        case .erase: return "eraser.fill"
        }
    }
}

struct LevelEditorView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @Binding var path: [Route]

    @State private var level: CustomLevel
    @State private var tool: EditorTool = .draw
    @State private var kind: ArrowKind = .normal
    @State private var dir: Direction = .up
    @State private var drawing: [Pos] = []
    @State private var stonePaint: Bool?
    @State private var toast: String?
    @State private var renaming = false
    @State private var nameDraft = ""
    @State private var history: [CustomLevel] = []

    init(level: CustomLevel, path: Binding<[Route]>) {
        _level = State(initialValue: level)
        _path = path
    }

    private var stuck: Set<Int> { level.stuck }
    private var thin: Bool { level.style == .maze }

    var body: some View {
        let t = store.theme
        let stuckNow = stuck
        ZStack {
            ThemeBackground(theme: t, animated: false)
            VStack(spacing: 10) {
                topBar(t)
                settingsRow(t)
                statusLine(t, stuck: stuckNow)
                board(t, stuck: stuckNow)
                    .padding(.horizontal, 12)
                toolRow(t)
                if tool == .draw { drawOptions(t) }
                Spacer(minLength: 0)
                actionRow(t)
            }
            .padding(.vertical, 8)
            .readableWidth(860)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChangeCompat(of: level) { _, new in
            if !new.arrows.isEmpty || store.customLevels.contains(where: { $0.id == new.id }) {
                store.saveCustom(new)
            }
        }
        .alert("Level name", isPresented: $renaming) {
            TextField("Name", text: $nameDraft)
            Button("Save") {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { level.name = String(trimmed.prefix(40)) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header & settings

    private func topBar(_ t: GameTheme) -> some View {
        HStack {
            CircleButton(icon: "chevron.left", theme: t) { dismiss() }
            Spacer()
            Button {
                nameDraft = level.name
                renaming = true
            } label: {
                HStack(spacing: 6) {
                    Text(level.name).lineLimit(1)
                    Image(systemName: "pencil").font(.caption.weight(.bold))
                }
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(t.text)
            }
            Spacer()
            Button {
                if level.isPlayable {
                    store.saveCustom(level)
                    path.append(.playCustom(level))
                } else {
                    flash(level.arrows.isEmpty ? "Draw some arrows first" : "Fix the red arrows first")
                }
            } label: {
                Label("Test", systemImage: "play.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(level.isPlayable ? .black : t.subtext)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(level.isPlayable ? t.accent : t.text.opacity(0.1)))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal)
    }

    private func settingsRow(_ t: GameTheme) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(GameStyle.allCases) { s in
                    Button { change { setStyle(s) } } label: { Label(s.title, systemImage: s.icon) }
                }
            } label: {
                chip(level.style.icon, level.style.title, t)
            }

            HStack(spacing: 0) {
                Button { change { resize(level.size - 1) } } label: {
                    Image(systemName: "minus").frame(width: 30, height: 32)
                }
                Text("\(level.size)×\(level.size)")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .frame(minWidth: 52)
                Button { change { resize(level.size + 1) } } label: {
                    Image(systemName: "plus").frame(width: 30, height: 32)
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(t.text)
            .background(Capsule().fill(t.text.opacity(0.1)))

            Menu {
                ForEach(BoardShape.allCases, id: \.self) { s in
                    Button { change { setShape(s) } } label: {
                        Text("\(s.emoji.isEmpty ? "" : s.emoji + " ")\(s.title)")
                    }
                }
            } label: {
                chip("seal.fill", level.shape.title, t)
            }
        }
        .padding(.horizontal)
    }

    private func chip(_ icon: String, _ title: String, _ t: GameTheme) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
        }
        .font(.system(.subheadline, design: .rounded).weight(.heavy))
        .foregroundStyle(t.text)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Capsule().fill(t.text.opacity(0.1)))
    }

    private func statusLine(_ t: GameTheme, stuck: Set<Int>) -> some View {
        let text: String
        let icon: String
        let color: Color
        if level.arrows.isEmpty {
            (text, icon, color) = ("Draw arrows on the board", "hand.draw.fill", t.subtext)
        } else if stuck.isEmpty {
            (text, icon, color) = ("Solvable · \(level.arrows.count) arrows", "checkmark.seal.fill", .green)
        } else {
            (text, icon, color) = ("\(stuck.count) red arrow\(stuck.count == 1 ? "" : "s") can never escape", "exclamationmark.triangle.fill", .orange)
        }
        return Label(text, systemImage: icon)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .animation(.default, value: text)
    }

    // MARK: Board

    private func board(_ t: GameTheme, stuck: Set<Int>) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(level.size)
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(t.board)
                LevelCanvas(level: level, theme: t, stuck: stuck, drawing: drawing, showCells: true)
                    .padding(0)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in strokeMoved(to: cellAt(v.location, cell: cell)) }
                            .onEnded { _ in strokeEnded() }
                    )
                if let toast {
                    Text(toast)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.75)))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 10)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellAt(_ p: CGPoint, cell: CGFloat) -> Pos? {
        let r = Int(floor(p.y / cell)), c = Int(floor(p.x / cell))
        guard r >= 0, r < level.size, c >= 0, c < level.size else { return nil }
        return Pos(r: r, c: c)
    }

    // MARK: Tools

    private func toolRow(_ t: GameTheme) -> some View {
        HStack(spacing: 8) {
            ForEach(EditorTool.allCases) { tl in
                Button {
                    tool = tl
                    Haptics.light()
                } label: {
                    Label(tl.title, systemImage: tl.icon)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(tool == tl ? .black : t.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tool == tl ? t.accent : t.text.opacity(0.09)))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal)
    }

    private var kinds: [ArrowKind] {
        level.style == .tiles ? [.normal, .twin, .ghost, .bomb, .key, .locked] : [.normal, .ghost, .bomb, .key, .locked]
    }

    private func kindTitle(_ k: ArrowKind) -> String {
        switch k {
        case .normal: return "Normal"
        case .twin: return "Twin"
        case .ghost: return "Ghost"
        case .bomb: return "Bomb"
        case .key: return "Key"
        case .locked: return "Lock"
        }
    }

    private func drawOptions(_ t: GameTheme) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("Tap:")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(t.subtext)
                ForEach(Direction.allCases, id: \.self) { d in
                    Button { dir = d } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .black))
                            .rotationEffect(.degrees(d.degrees))
                            .foregroundStyle(dir == d ? .white : t.text)
                            .frame(width: 34, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(dir == d ? t.arrows[d.rawValue] : t.text.opacity(0.08)))
                    }
                }
                Spacer(minLength: 4)
                Menu {
                    ForEach(kinds, id: \.self) { k in
                        Button(kindTitle(k)) { kind = k }
                    }
                } label: {
                    chip("sparkles", kindTitle(kind), t)
                }
            }
            Text(level.style == .tiles
                 ? "Tap a cell to place · tap an arrow to turn it · swipe from a cell to aim"
                 : "Drag a path to draw (the arrowhead goes where you stop) · tap for a 1-cell arrow")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(t.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private func actionRow(_ t: GameTheme) -> some View {
        HStack(spacing: 10) {
            ToolButton(icon: "arrow.uturn.backward", label: "Undo", count: nil, theme: t) {
                if let last = history.popLast() { level = last }
            }
            ToolButton(icon: "wand.and.stars", label: "Auto-fill", count: nil, theme: t) {
                change {
                    level = CustomLevel.autoFill(style: level.style, size: level.size, shape: level.shape,
                                                 name: level.name, id: level.id)
                }
                flash("New random level · edit it however you like")
            }
            ToolButton(icon: "trash", label: "Clear", count: nil, theme: t) {
                change {
                    level.arrows = []
                    level.stones = []
                }
            }
            ShareLink(item: level.shareCode, preview: SharePreview(level.name)) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 22, weight: .bold))
                    Text("Share").font(.caption.weight(.bold))
                }
                .foregroundStyle(t.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.text.opacity(0.09)))
            }
        }
        .padding(.horizontal)
    }

    // MARK: Editing

    private func change(_ edit: () -> Void) {
        history.append(level)
        if history.count > 50 { history.removeFirst() }
        edit()
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toast == text { withAnimation { toast = nil } }
        }
    }

    private func arrowIndex(at p: Pos) -> Int? { level.arrows.firstIndex { $0.cells.contains(p) } }

    private func isFree(_ p: Pos) -> Bool {
        level.mask.contains(p) && arrowIndex(at: p) == nil && !level.stones.contains(p)
    }

    private func direction(from a: Pos, to b: Pos) -> Direction? {
        Direction.allCases.first { a.moved($0) == b }
    }

    private func setStyle(_ s: GameStyle) {
        guard s != level.style else { return }
        level.style = s
        var removed = 0
        if s == .tiles {
            removed = level.arrows.filter { $0.cells.count > 1 }.count
            level.arrows.removeAll { $0.cells.count > 1 }
        } else {
            for i in level.arrows.indices where level.arrows[i].kind == .twin { level.arrows[i].kind = .normal }
            if kind == .twin { kind = .normal }
        }
        if removed > 0 { flash("Removed \(removed) ribbon\(removed == 1 ? "" : "s") (Tiles uses 1-cell arrows)") }
    }

    private func resize(_ n: Int) {
        guard CustomLevel.sizeRange.contains(n) else { return }
        level.size = n
        let removed = level.prune()
        if removed > 0 { flash("Removed \(removed) piece\(removed == 1 ? "" : "s") outside the board") }
    }

    private func setShape(_ s: BoardShape) {
        level.shape = s
        let removed = level.prune()
        if removed > 0 { flash("Removed \(removed) piece\(removed == 1 ? "" : "s") outside the shape") }
    }

    private func strokeMoved(to p: Pos?) {
        guard let p else { return }
        switch tool {
        case .draw:
            guard let last = drawing.last else {
                drawing = [p]
                return
            }
            guard p != last else { return }
            if drawing.count >= 2 && p == drawing[drawing.count - 2] {
                drawing.removeLast()              // finger went back: undo the last step
                return
            }
            guard direction(from: last, to: p) != nil, !drawing.contains(p) else { return }
            if level.style == .tiles {
                drawing = [drawing[0], p]         // a swipe only aims the arrow
            } else if isFree(drawing[0]) && isFree(p) {
                drawing.append(p)
            }
        case .stone:
            if stonePaint == nil {
                history.append(level)
                stonePaint = !level.stones.contains(p)
            }
            if stonePaint == true, isFree(p) {
                level.stones.append(p)
            } else if stonePaint == false {
                level.stones.removeAll { $0 == p }
            }
        case .erase:
            if stonePaint == nil {
                history.append(level)
                stonePaint = false
            }
            level.stones.removeAll { $0 == p }
            if let i = arrowIndex(at: p) { level.arrows.remove(at: i) }
        }
    }

    private func strokeEnded() {
        defer {
            drawing = []
            stonePaint = nil
        }
        guard tool == .draw, let first = drawing.first else { return }
        let k: ArrowKind = (kind == .twin && level.style != .tiles) ? .normal : kind

        if drawing.count == 1 {
            if let i = arrowIndex(at: first) {
                if level.arrows[i].cells.count == 1 {
                    change { level.arrows[i].dir = Direction(rawValue: (level.arrows[i].dir.rawValue + 1) % 4)! }
                    Haptics.light()
                } else {
                    flash("Use Erase to remove a ribbon")
                }
            } else if isFree(first) {
                change { level.arrows.append(CustomArrow(cells: [first], dir: dir, kind: k)) }
                Haptics.light()
            }
            return
        }

        if level.style == .tiles {
            guard let d = direction(from: first, to: drawing[1]) else { return }
            if let i = arrowIndex(at: first) {
                change { level.arrows[i].dir = d }
            } else if isFree(first) {
                change { level.arrows.append(CustomArrow(cells: [first], dir: d, kind: k)) }
            }
            dir = d
            Haptics.light()
            return
        }

        // Ribbon: the head is where the finger stopped, pointing along the last step.
        let head = drawing[drawing.count - 1]
        guard let d = direction(from: drawing[drawing.count - 2], to: head) else { return }
        var q = head.moved(d)
        while q.r >= 0 && q.r < level.size && q.c >= 0 && q.c < level.size {
            if drawing.contains(q) {
                flash("A ribbon can't point back into itself")
                Haptics.error()
                return
            }
            q = q.moved(d)
        }
        let cells = drawing
        change { level.arrows.append(CustomArrow(cells: cells, dir: d, kind: k)) }
        Haptics.light()
    }
}

// MARK: - Drawing

/// Draws a custom level (used by the editor and the level list thumbnails).
struct LevelCanvas: View {
    let level: CustomLevel
    let theme: GameTheme
    var stuck: Set<Int> = []
    var drawing: [Pos] = []
    var showCells = true

    var body: some View {
        Canvas { ctx, size in
            let n = level.size
            let cell = min(size.width, size.height) / CGFloat(n)
            let mask = level.mask
            let thin = level.style == .maze
            let skin = theme.skin

            func rect(_ p: Pos, _ inset: CGFloat) -> CGRect {
                CGRect(x: CGFloat(p.c) * cell + inset, y: CGFloat(p.r) * cell + inset,
                       width: cell - 2 * inset, height: cell - 2 * inset)
            }
            func center(_ p: Pos) -> CGPoint {
                CGPoint(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell)
            }

            // Board cells (shape)
            var cells = Path()
            for p in mask {
                if showCells {
                    cells.addRoundedRect(in: rect(p, cell * 0.06), cornerSize: CGSize(width: cell * 0.2, height: cell * 0.2))
                } else {
                    cells.addRect(rect(p, 0))
                }
            }
            ctx.fill(cells, with: .color(theme.text.opacity(showCells ? 0.07 : 0.04)))

            for s in level.stones {
                ctx.fill(Path(roundedRect: rect(s, cell * 0.1), cornerRadius: cell * 0.2), with: .color(theme.stone))
            }

            for (i, a) in level.arrows.enumerated() {
                let color: Color = a.kind == .key ? Color(hex: 0xF4B400)
                    : a.kind == .locked ? Color(hex: 0x8A8FA3)
                    : theme.arrows[a.dir.rawValue]
                let bad = stuck.contains(i)

                if level.style == .tiles {
                    let r = rect(a.cells[a.cells.count - 1], cell * 0.1)
                    let tile = SkinTileShape(tile: skin.tile).path(in: r)
                    if bad {
                        ctx.stroke(SkinTileShape(tile: skin.tile).path(in: r.insetBy(dx: -2, dy: -2)),
                                   with: .color(.red), lineWidth: 3)
                    }
                    if skin.outlined {
                        ctx.fill(tile, with: .color(color.opacity(0.14)))
                        ctx.stroke(tile, with: .color(color), lineWidth: max(1.5, cell * 0.05))
                    } else {
                        ctx.fill(tile, with: .color(color.opacity(a.kind == .ghost ? 0.45 : 1)))
                    }
                    var c = ctx
                    let mid = center(a.pos)
                    c.translateBy(x: mid.x, y: mid.y)
                    c.rotate(by: .degrees(a.dir.degrees))
                    c.draw(Text(Image(systemName: a.kind == .twin ? skin.twinGlyph : skin.glyph))
                        .font(.system(size: cell * 0.8 * skin.glyphScale, weight: .black))
                        .foregroundColor(skin.outlined ? color : .white), at: .zero)
                } else {
                    let arrow = Arrow(id: i, cells: a.cells, dir: a.dir, kind: a.kind)
                    let track = RibbonGeometry.track(for: arrow, boardSize: n)
                    let len = RibbonGeometry.length(for: arrow)
                    let body = RibbonBody(track: track, start: 0, length: len, cell: cell).path(in: .zero)
                    let head = RibbonHead(track: track, start: 0, length: len, cell: cell, dir: a.dir,
                                          headScale: thin ? 0.85 : 1, style: skin.head).path(in: .zero)
                    let w = thin ? max(1.5, cell * 0.14) : max(3, cell * 0.3)
                    if bad {
                        ctx.stroke(body, with: .color(.red.opacity(0.5)),
                                   style: StrokeStyle(lineWidth: w * 3.2, lineCap: .round, lineJoin: .round))
                        ctx.fill(head, with: .color(.red))
                    }
                    skin.strokeRibbon(&ctx, body, color: color, width: w, inner: theme.tubeInner,
                                      ghost: a.kind == .ghost)
                    ctx.fill(head, with: .color(color))
                }

                let badge: String? = switch a.kind {
                case .key: "key.fill"
                case .locked: "lock.fill"
                case .bomb: "flame.fill"
                default: nil
                }
                if let badge, cell >= 10 {
                    let p = center(a.pos)
                    let s = max(10, cell * 0.38)
                    let spot = CGRect(x: p.x + cell * 0.12, y: p.y - cell * 0.12 - s, width: s, height: s)
                    ctx.fill(Path(ellipseIn: spot), with: .color(.white))
                    ctx.draw(Text(Image(systemName: badge)).font(.system(size: s * 0.6, weight: .bold))
                        .foregroundColor(a.kind == .bomb ? .orange : Color(hex: 0x3D2C00)),
                             at: CGPoint(x: spot.midX, y: spot.midY))
                }
            }

            // Stroke being drawn
            if !drawing.isEmpty {
                var p = Path()
                p.move(to: center(drawing[0]))
                for q in drawing.dropFirst() { p.addLine(to: center(q)) }
                ctx.stroke(p, with: .color(theme.accent.opacity(0.85)),
                           style: StrokeStyle(lineWidth: max(4, cell * 0.32), lineCap: .round, lineJoin: .round))
                ctx.fill(Path(ellipseIn: rect(drawing[0], cell * 0.3)), with: .color(theme.accent))
            }
        }
    }
}
