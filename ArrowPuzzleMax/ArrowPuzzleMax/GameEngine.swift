import SwiftUI

final class GameEngine: ObservableObject {
    let mode: GameMode
    let style: GameStyle

    @Published private(set) var level: Int
    @Published private(set) var size = 5
    @Published private(set) var arrows: [Arrow] = []
    @Published private(set) var stones: Set<Pos> = []
    @Published private(set) var playable: Set<Pos> = []
    @Published private(set) var boardID = 0
    @Published private(set) var shape: BoardShape = .square
    @Published private(set) var hearts = 3
    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var bestCombo = 0
    @Published private(set) var mistakes = 0
    @Published private(set) var timeLeft: Double = 60
    @Published private(set) var round = 0
    @Published private(set) var state: PlayState = .playing
    @Published private(set) var hintID: Int?
    @Published private(set) var preview: RayPreview?
    @Published private(set) var shake: CGFloat = 0
    @Published private(set) var blasts: [Blast] = []
    @Published private(set) var floats: [FloatText] = []
    @Published private(set) var undosLeft = 3
    @Published private(set) var totalArrows = 0
    /// Arrows cleared since this screen opened (for Daily Quests).
    @Published private(set) var cleared = 0
    /// Blink mode: directions are hidden.
    @Published private(set) var hidden = false
    /// Blink mode: seconds left to memorise the board.
    @Published private(set) var memorizeLeft: Double = 0
    @Published private(set) var peeksLeft = 2
    /// Every tap on this board, for the share card: the direction that escaped, or a bump.
    @Published private(set) var moves: [String] = []

    let maxHearts = 3
    /// Animation duration multiplier from the View settings.
    var speed: Double = 1

    private struct Snapshot {
        let arrows: [Arrow]
        let stones: Set<Pos>
        let score: Int
    }

    private var history: [Snapshot] = []
    private var lastClear: Date?
    private var timer: Timer?
    private var inputLocked = false
    private var sessionSeed = UInt64.random(in: 1...UInt64.max)

    /// Fixed board for Level Creator levels (nil = generated).
    private let customBoard: GeneratedBoard?
    let customName: String?

    init(mode: GameMode, level: Int, style: GameStyle = .tiles,
         customBoard: GeneratedBoard? = nil, customName: String? = nil) {
        self.mode = mode
        self.style = style
        self.level = level
        self.customBoard = customBoard
        self.customName = customName
        startBoard(newRun: true)
    }

    deinit { timer?.invalidate() }

    // MARK: - Derived

    var remaining: Int { arrows.filter { !$0.escaping }.count }

    var progress: Double {
        totalArrows == 0 ? 0 : 1 - Double(remaining) / Double(totalArrows)
    }

    var difficulty: String? {
        switch mode {
        case .journey where LevelConfig.isBoss(level): return "👑 BOSS"
        case .journey: return level < 8 ? "Easy" : level < 20 ? "Medium" : level < 40 ? "Hard" : "Expert"
        case .daily: return "Hard"
        case .rush, .zen: return nil
        case .blink: return hidden ? "Hidden" : "Memorise"
        case .custom: return "Custom"
        }
    }

    var keysLeft: Bool { arrows.contains { $0.kind == .key && !$0.escaping } }

    func isLocked(_ a: Arrow) -> Bool { a.kind == .locked && keysLeft }

    // MARK: - Setup

    func restart() { startBoard(newRun: true) }

    func goTo(level n: Int) {
        level = n
        startBoard(newRun: true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func config() -> LevelConfig {
        .make(style: style, mode: mode, level: level, round: round,
              seed: sessionSeed &+ UInt64(round) &* 1_000_003)
    }

    private func startBoard(newRun: Bool) {
        if newRun {
            score = 0
            round = 0
            bestCombo = 0
            timeLeft = 60
            hearts = maxHearts
            sessionSeed = UInt64.random(in: 1...UInt64.max)
            state = .playing
            stop()
            if mode == .rush || mode == .blink { startTimer() }
        }
        let cfg = config()
        let board = customBoard ?? LevelGenerator.generate(cfg)
        shape = customBoard == nil ? cfg.shape : .square
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            size = board.size
            arrows = board.arrows
            stones = board.stones
            playable = board.cells
        }
        boardID += 1
        totalArrows = board.arrows.count
        mistakes = 0
        combo = 0
        undosLeft = mode == .blink ? 0 : 3
        moves = []
        if mode == .blink {
            hidden = false
            peeksLeft = 2
            memorizeLeft = min(9, 2.5 + 0.3 * Double(board.arrows.count))
        }
        history = []
        hintID = nil
        preview = nil
        lastClear = nil
        blasts = []
        floats = []
        inputLocked = false
    }

    private func startTimer() {
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard state == .playing, !inputLocked else { return }
        if mode == .blink {
            if memorizeLeft > 0 {
                let next = memorizeLeft - 0.1
                if next <= 0.001 { hide() } else { memorizeLeft = next }
            }
            return
        }
        timeLeft = max(0, timeLeft - 0.1)
        if timeLeft <= 0 { endRun() }
    }

    private func endRun() {
        stop()
        inputLocked = true
        Haptics.error()
        state = .lost
    }

    // MARK: - Blink

    private func hide() {
        if !hidden {
            withAnimation(.easeInOut(duration: 0.35)) { hidden = true }
            Haptics.heavy()
        }
        memorizeLeft = 0
    }

    /// Blink: show the directions again for a moment.
    @discardableResult
    func peek() -> Bool {
        guard mode == .blink, state == .playing, hidden, peeksLeft > 0 else { return false }
        peeksLeft -= 1
        withAnimation(.easeInOut(duration: 0.2)) { hidden = false }
        let board = boardID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            guard let self, self.boardID == board, self.state == .playing else { return }
            withAnimation(.easeInOut(duration: 0.3)) { self.hidden = true }
        }
        Haptics.light()
        return true
    }

    // MARK: - Rules

    private func inside(_ p: Pos) -> Bool { p.r >= 0 && p.r < size && p.c >= 0 && p.c < size }

    private func arrowAt(_ p: Pos, excluding id: Int) -> Bool {
        arrows.contains { !$0.escaping && $0.id != id && $0.cells.contains(p) }
    }

    /// Walks the lane in front of an arrow. `blockedAt == nil` means it reaches the edge.
    func trace(_ a: Arrow, dir: Direction) -> (cells: [Pos], blockedAt: Pos?) {
        var cells: [Pos] = []
        var p = a.pos.moved(dir)
        while inside(p) {
            if stones.contains(p) || (a.kind != .ghost && arrowAt(p, excluding: a.id)) {
                return (cells, p)
            }
            cells.append(p)
            p = p.moved(dir)
        }
        return (cells, nil)
    }

    func exitDirection(_ a: Arrow) -> Direction? {
        if isLocked(a) { return nil }
        if trace(a, dir: a.dir).blockedAt == nil { return a.dir }
        if a.kind == .twin, trace(a, dir: a.dir.opposite).blockedAt == nil { return a.dir.opposite }
        return nil
    }

    // MARK: - Player actions

    func tap(_ id: Int) {
        guard state == .playing, !inputLocked,
              let i = arrows.firstIndex(where: { $0.id == id }),
              !arrows[i].escaping else { return }
        preview = nil
        // In Blink the first tap means "I'm ready": the board hides straight away.
        if mode == .blink && memorizeLeft > 0 { hide() }
        if let d = exitDirection(arrows[i]) {
            escape(index: i, dir: d)
        } else {
            bump(index: i)
        }
    }

    private func escape(index i: Int, dir d: Direction) {
        let a = arrows[i]
        history.append(Snapshot(arrows: arrows.filter { !$0.escaping }, stones: stones, score: score))
        if hintID == a.id { hintID = nil }

        arrows[i].travelDir = d
        cleared += 1
        moves.append(["⬆️", "➡️", "⬇️", "⬅️"][d.rawValue])
        // Tiles fly off and fade. Ribbons slide their whole body along their path and out past the edge.
        let distance: CGFloat
        let duration: Double
        if style != .tiles {
            distance = CGFloat(a.cells.count + trace(a, dir: d).cells.count + 1)
            duration = min(1.0, 0.15 + 0.035 * Double(distance)) * speed
        } else {
            distance = CGFloat(size + 1)
            duration = 0.3 * speed
        }
        withAnimation(.easeIn(duration: duration)) {
            arrows[i].travel = distance
            arrows[i].escaping = true
        }

        let now = Date()
        if let last = lastClear, now.timeIntervalSince(last) < 1.5 { combo += 1 } else { combo = 1 }
        lastClear = now
        bestCombo = max(bestCombo, combo)

        let multiplier = min(combo, 8)
        let gained = 10 * multiplier + (a.kind == .normal ? 0 : 15) + 2 * (a.cells.count - 1)
        score += gained
        spawnFloat(multiplier > 1 ? "+\(gained) ×\(multiplier)" : "+\(gained)", at: a.pos, color: .white)

        if a.kind == .bomb { explode(around: a.pos) }

        if a.kind == .key && !keysLeft && arrows.contains(where: { $0.kind == .locked && !$0.escaping }) {
            spawnFloat("UNLOCKED!", at: a.pos, color: .yellow)
            Haptics.success()
        } else {
            Haptics.light()
        }

        let id = a.id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.02) { [weak self] in
            self?.arrows.removeAll { $0.id == id && $0.escaping }
        }

        if remaining == 0 { boardCleared() }
    }

    private func bump(index i: Int) {
        let a = arrows[i]
        let locked = isLocked(a)
        let gap = locked ? 0 : trace(a, dir: a.dir).cells.count
        let id = a.id

        arrows[i].travelDir = a.dir
        withAnimation(.easeOut(duration: 0.12)) { arrows[i].travel = CGFloat(gap) + 0.22 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, let j = self.arrows.firstIndex(where: { $0.id == id }), !self.arrows[j].escaping else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { self.arrows[j].travel = 0 }
        }
        withAnimation(.linear(duration: 0.35)) { shake += 1 }

        mistakes += 1
        moves.append("💥")
        combo = 0
        Haptics.error()
        spawnFloat(locked ? "LOCKED" : "BLOCKED", at: a.pos, color: .red)

        switch mode {
        case .zen:
            break
        case .rush:
            timeLeft = max(0, timeLeft - 5)
            spawnFloat("-5s", at: Pos(r: size / 2, c: size / 2), color: .red)
            if timeLeft <= 0 { endRun() }
        case .journey, .daily, .custom, .blink:
            hearts -= 1
            if hearts <= 0 {
                inputLocked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.state = .lost }
            }
        }
    }

    private func boardCleared() {
        inputLocked = true
        Haptics.success()
        let center = Pos(r: size / 2, c: size / 2)
        let settle = style != .tiles ? 0.45 * speed : 0.0   // let the last ribbon finish sliding out
        switch mode {
        case .journey, .daily, .custom:
            let stars = mistakes == 0 ? 3 : (mistakes == 1 ? 2 : 1)
            score += hearts * 50
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + settle) { [weak self] in
                self?.state = .won(stars: stars)
            }
        case .rush, .zen, .blink:
            round += 1
            score += 100
            if mode == .blink {
                score += hidden ? 50 : 0
                if mistakes == 0 && hearts < maxHearts {
                    hearts += 1
                    spawnFloat("+1 ♥", at: Pos(r: max(0, size / 2 - 1), c: size / 2), color: Color(hex: 0xFF4D6D))
                }
            }
            if mode == .rush {
                let bonus = Double(8 + size * 2)
                timeLeft += bonus
                spawnFloat("CLEAR! +\(Int(bonus))s", at: center, color: .green)
            } else {
                spawnFloat("CLEAR!", at: center, color: .green)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75 + settle) { [weak self] in
                guard let self, self.state == .playing else { return }
                self.startBoard(newRun: false)
            }
        }
    }

    @discardableResult
    func undo() -> Bool {
        guard state == .playing, !inputLocked, undosLeft > 0, let snap = history.popLast() else { return false }
        undosLeft -= 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            arrows = snap.arrows.map { a in
                var a = a
                a.travel = 0
                a.escaping = false
                return a
            }
            stones = snap.stones
        }
        score = snap.score
        combo = 0
        hintID = nil
        Haptics.light()
        return true
    }

    /// Highlights an arrow that can escape right now. Keys first, since they open locks.
    @discardableResult
    func hint() -> Bool {
        guard state == .playing, !inputLocked else { return false }
        let free = arrows.filter { !$0.escaping && exitDirection($0) != nil }
        guard let pick = free.first(where: { $0.kind == .key }) ?? free.first else { return false }
        hintID = pick.id
        Haptics.light()
        return true
    }

    /// Long-press preview of the lane in front of an arrow.
    func setPreview(_ id: Int?) {
        guard let id, state == .playing, !hidden,
              let a = arrows.first(where: { $0.id == id && !$0.escaping }) else {
            preview = nil
            return
        }
        var t = trace(a, dir: a.dir)
        if a.kind == .twin, t.blockedAt != nil {
            let other = trace(a, dir: a.dir.opposite)
            if other.blockedAt == nil { t = other }
        }
        preview = RayPreview(origin: a.pos, cells: t.cells, blockedAt: t.blockedAt, locked: isLocked(a))
        Haptics.light()
    }

    // MARK: - Effects

    private func explode(around p: Pos) {
        var hit: [Pos] = []
        for dr in -1...1 {
            for dc in -1...1 {
                let q = Pos(r: p.r + dr, c: p.c + dc)
                if stones.contains(q) { hit.append(q) }
            }
        }
        let blast = Blast(pos: p)
        blasts.append(blast)
        withAnimation(.easeOut(duration: 0.3)) {
            for q in hit { stones.remove(q) }
        }
        if !hit.isEmpty { score += 25 * hit.count }
        Haptics.heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.blasts.removeAll { $0.id == blast.id }
        }
    }

    private func spawnFloat(_ text: String, at p: Pos, color: Color) {
        let f = FloatText(text: text, pos: p, color: color)
        floats.append(f)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.floats.removeAll { $0.id == f.id }
        }
    }
}
