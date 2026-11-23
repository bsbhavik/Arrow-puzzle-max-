import Foundation

/// Deterministic RNG (SplitMix64) so a level number or a date always builds the same board.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct LevelConfig {
    var size: Int
    var stones: Int
    var fill: Double
    /// 0...1 — how often an arrow is aimed across the longest open lane (more dependencies = harder).
    var trickiness: Double
    var features: Set<Feature>
    var seed: UInt64
    var style: GameStyle = .tiles
    /// Ribbon length range (in cells) and how often a ribbon keeps going straight instead of turning.
    var minLen = 2
    var maxLen = 5
    var straightness = 0.55
    var shape: BoardShape = .square
    /// Fill leftover gaps with one-cell stub arrows (Maze style).
    var allowStubs = false

    static func make(style: GameStyle, mode: GameMode, level: Int, round: Int, seed: UInt64) -> LevelConfig {
        if mode == .blink { return blink(style: style, round: round, seed: seed) }
        if mode == .journey && isBoss(level) { return boss(style: style, level: level) }
        switch (style, mode) {
        case (.tiles, .journey): return .journey(level)
        case (.tiles, .daily): return .daily()
        case (.tiles, _): return .endless(round: round, seed: seed)
        case (.ribbons, .journey): return .ribbonJourney(level)
        case (.ribbons, .daily): return .ribbonDaily()
        case (.ribbons, _): return .ribbonEndless(round: round, seed: seed)
        case (.maze, .journey): return .mazeJourney(level)
        case (.maze, .daily): return .mazeDaily()
        case (.maze, _): return .mazeEndless(round: round, seed: seed)
        }
    }

    /// Every 25th Journey level is a Boss: a bigger, trickier board that pays double coins.
    static func isBoss(_ level: Int) -> Bool { level > 0 && level % 25 == 0 }

    static func boss(style: GameStyle, level: Int) -> LevelConfig {
        var cfg: LevelConfig
        switch style {
        case .tiles:
            cfg = journey(level)
            cfg.size = min(11, cfg.size + 2)
            cfg.stones += 2
            cfg.fill = 0.95
        case .ribbons:
            cfg = ribbonJourney(level)
            cfg.size = min(17, cfg.size + 3)
            cfg.maxLen += 2
        case .maze:
            cfg = mazeJourney(level)
            cfg.size = min(28, cfg.size + 4)
            cfg.maxLen += 3
        }
        cfg.trickiness = 0.92
        cfg.seed = cfg.seed &+ 777_767
        return cfg
    }

    /// After the early levels, board sizes move around so it isn't the same size forever:
    /// a few smaller "breather" boards between the big ones.
    private static func varied(_ level: Int, base: Int, spread: Int) -> Int {
        base - Int((UInt64(level) &* 2_654_435_761 >> 7) % UInt64(spread))
    }

    /// Blink boards stay small enough to memorise, and grow a little each round.
    static func blink(style: GameStyle, round: Int, seed: UInt64) -> LevelConfig {
        var cfg = make(style: style, mode: .zen, level: 0, round: round, seed: seed)
        switch style {
        case .tiles:
            cfg.size = min(7, 4 + round / 2)
            cfg.stones = min(cfg.stones, cfg.size / 2)
        case .ribbons:
            cfg.size = min(9, 5 + round / 2)
            cfg.maxLen = min(cfg.maxLen, 5)
        case .maze:
            cfg.size = min(10, 6 + round / 2)
            cfg.maxLen = min(cfg.maxLen, 6)
            cfg.shape = .square
        }
        cfg.features.remove(.twin)   // a hidden twin would be pure guesswork
        return cfg
    }

    // MARK: Maze boards

    /// Maze levels cycle through these; creatures are mixed in between the geometric shapes.
    static let mazeShapes: [BoardShape] = [.square, .heart, .cat, .circle, .fish, .diamond, .bird,
                                           .flower, .turtle, .plus, .butterfly, .ring, .bunny,
                                           .mushroom, .star, .ghost, .house, .apple, .tree, .moon, .crown]

    static func mazeJourney(_ level: Int) -> LevelConfig {
        LevelConfig(
            size: level <= 60 ? min(24, 12 + level / 3) : varied(level, base: 24, spread: 7),
            stones: 0,
            fill: 1,
            trickiness: min(0.9, 0.55 + Double(level) * 0.01),
            features: level >= Feature.keyLock.unlockLevel ? [.keyLock] : [],
            seed: UInt64(level) &* 32_452_843 &+ 3,
            style: .maze,
            minLen: 2,
            maxLen: min(18, 6 + level / 3),
            straightness: 0.6,
            shape: mazeShapes[(level - 1) % mazeShapes.count],
            allowStubs: true)
    }

    static func mazeDaily(date: Date = Date()) -> LevelConfig {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var cfg = mazeJourney(30)
        cfg.size = 20
        cfg.maxLen = 12
        cfg.shape = mazeShapes[day % mazeShapes.count]
        cfg.seed = daily(date: date).seed &+ 424_243
        return cfg
    }

    static func mazeEndless(round: Int, seed: UInt64) -> LevelConfig {
        var cfg = mazeJourney(3 + round * 4)
        cfg.size = min(20, 12 + round * 2)
        cfg.shape = mazeShapes[Int(seed % UInt64(mazeShapes.count))]
        cfg.seed = seed
        return cfg
    }

    // MARK: Ribbon boards

    static func ribbonJourney(_ level: Int) -> LevelConfig {
        let size = level <= 60 ? min(14, 6 + level / 5) : varied(level, base: 14, spread: 4)
        return LevelConfig(
            size: size,
            stones: level < 10 ? 0 : min(size, (level - 6) / 4),
            fill: 1,
            trickiness: min(0.85, 0.4 + Double(level) * 0.012),
            features: Set(Feature.allCases.filter { $0 != .twin && level >= $0.unlockLevel }),
            seed: UInt64(level) &* 15_485_863 &+ 7,
            style: .ribbons,
            minLen: 2,
            maxLen: min(10, 3 + level / 6),
            straightness: 0.55)
    }

    static func ribbonDaily(date: Date = Date()) -> LevelConfig {
        var cfg = daily(date: date)
        cfg.size = 12
        cfg.stones = 5
        cfg.fill = 1
        cfg.features.remove(.twin)
        cfg.style = .ribbons
        cfg.maxLen = 8
        cfg.seed = cfg.seed &+ 99_991
        return cfg
    }

    static func ribbonEndless(round: Int, seed: UInt64) -> LevelConfig {
        let size = min(12, 6 + round)
        return LevelConfig(
            size: size,
            stones: round < 2 ? 0 : min(size, round + 1),
            fill: 1,
            trickiness: min(0.8, 0.45 + Double(round) * 0.05),
            features: Set(Feature.allCases.filter { $0 != .twin && $0.unlockLevel <= 4 + round * 3 }),
            seed: seed,
            style: .ribbons,
            minLen: 2,
            maxLen: min(9, 3 + round),
            straightness: 0.55)
    }

    // MARK: Tile boards

    static func journey(_ level: Int) -> LevelConfig {
        let size = level <= 60 ? min(9, 4 + (level + 4) / 8) : varied(level, base: 9, spread: 3)
        let stones = level < 6 ? 0 : min(size + 1, (level - 2) / 4)
        return LevelConfig(
            size: size,
            stones: stones,
            fill: min(0.95, 0.68 + Double(level) * 0.008),
            trickiness: min(0.85, 0.35 + Double(level) * 0.015),
            features: Set(Feature.allCases.filter { level >= $0.unlockLevel }),
            seed: UInt64(level) &* 7919 &+ 104_729
        )
    }

    static func daily(date: Date = Date()) -> LevelConfig {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let key = UInt64((c.year ?? 2026) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1))
        return LevelConfig(size: 8, stones: 6, fill: 0.92, trickiness: 0.8,
                           features: Set(Feature.allCases), seed: key &* 2_654_435_761)
    }

    /// Boards for Time Rush and Zen: they grow as you clear more.
    static func endless(round: Int, seed: UInt64) -> LevelConfig {
        let size = min(8, 4 + (round + 1) / 2)
        return LevelConfig(
            size: size,
            stones: round < 2 ? 0 : min(size, round),
            fill: 0.85,
            trickiness: min(0.8, 0.4 + Double(round) * 0.05),
            features: Set(Feature.allCases.filter { $0.unlockLevel <= 4 + round * 3 }),
            seed: seed
        )
    }
}

struct GeneratedBoard {
    let size: Int
    let arrows: [Arrow]
    let stones: Set<Pos>
    /// Cells that belong to the board's shape.
    let cells: Set<Pos>
}

/// Builds boards that are always solvable.
///
/// Arrows are placed one at a time, and each new arrow is only allowed to point down a lane that is
/// still empty. Removing arrows in reverse placement order is therefore always a valid solution, and
/// since clearing an arrow never blocks another one, the player can never get stuck — only make mistakes.
enum LevelGenerator {
    static func generate(_ cfg: LevelConfig) -> GeneratedBoard {
        cfg.style == .tiles ? generateTiles(cfg) : generateRibbons(cfg)
    }

    /// Ribbons use the same "only aim down an empty lane" rule as tiles, applied to the head.
    /// Each ribbon's body is grown backwards from its head as a random walk that never enters its
    /// own lane, so when the lane is clear the whole ribbon can follow its head out.
    static func generateRibbons(_ cfg: LevelConfig) -> GeneratedBoard {
        var rng = SeededRNG(seed: cfg.seed)
        let n = cfg.size
        func inside(_ p: Pos) -> Bool { p.r >= 0 && p.r < n && p.c >= 0 && p.c < n }
        let playable = cfg.shape.mask(n)

        var cells: [Pos] = []
        for r in 0..<n { for c in 0..<n { cells.append(Pos(r: r, c: c)) } }
        cells.shuffle(using: &rng)
        cells = cells.filter { playable.contains($0) }
        if cfg.allowStubs {
            // Dense mazes: start heads in the middle (they need long empty lanes) and work outwards,
            // with a little jitter so it doesn't look like rings.
            let depth = Dictionary(uniqueKeysWithValues: cells.map { p in
                (p, Double(min(p.r, p.c, n - 1 - p.r, n - 1 - p.c)) + Double.random(in: 0..<2.5, using: &rng))
            })
            cells.sort { depth[$0]! > depth[$1]! }
        }

        let stones = Set(cells.prefix(cfg.stones))
        var occupied = Set<Pos>()
        var ribbons: [(cells: [Pos], dir: Direction)] = []

        for head in cells where !stones.contains(head) && !occupied.contains(head) {
            var options: [(dir: Direction, lane: [Pos])] = []
            for d in Direction.allCases {
                let neck = head.moved(d.opposite)
                guard inside(neck), playable.contains(neck), !stones.contains(neck), !occupied.contains(neck) else { continue }
                if let lane = lane(from: head, dir: d, n: n, blocked: { stones.contains($0) || occupied.contains($0) }) {
                    options.append((d, lane))
                }
            }
            if options.isEmpty && cfg.allowStubs {
                // No room for a body: a one-cell stub arrow still fills the gap.
                let stubDirs = Direction.allCases.filter { d in
                    lane(from: head, dir: d, n: n, blocked: { stones.contains($0) || occupied.contains($0) }) != nil
                }
                if let d = stubDirs.randomElement(using: &rng) {
                    occupied.insert(head)
                    ribbons.append(([head], d))
                }
                continue
            }
            guard !options.isEmpty else { continue }
            options.shuffle(using: &rng)
            let pick = Double.random(in: 0..<1, using: &rng) < cfg.trickiness
                ? options.max(by: { $0.lane.count < $1.lane.count })!
                : options.randomElement(using: &rng)!

            let laneSet = Set(pick.lane)
            var body = [head, head.moved(pick.dir.opposite)]   // head first while growing
            var heading = pick.dir.opposite
            let target = Int.random(in: cfg.minLen...max(cfg.minLen, cfg.maxLen), using: &rng)

            while body.count < target {
                var choices: [Direction] = []
                for g in Direction.allCases where g != heading.opposite {
                    let q = body[body.count - 1].moved(g)
                    if inside(q), playable.contains(q), !stones.contains(q), !occupied.contains(q), !laneSet.contains(q), !body.contains(q) {
                        choices.append(g)
                    }
                }
                guard !choices.isEmpty else { break }
                let g = choices.contains(heading) && Double.random(in: 0..<1, using: &rng) < cfg.straightness
                    ? heading
                    : choices.randomElement(using: &rng)!
                body.append(body[body.count - 1].moved(g))
                heading = g
            }

            for q in body { occupied.insert(q) }
            ribbons.append((Array(body.reversed()), pick.dir))
        }

        let kinds = assignKinds(count: ribbons.count, heads: ribbons.map { $0.cells[$0.cells.count - 1] },
                                stones: stones, cfg: cfg, rng: &rng)
        let arrows = ribbons.enumerated().map { i, r in
            Arrow(id: i, cells: r.cells, dir: r.dir, kind: kinds[i])
        }
        return GeneratedBoard(size: n, arrows: arrows, stones: stones, cells: playable)
    }

    /// Cells from just past `p` to the edge, or nil if something is in the way.
    private static func lane(from p: Pos, dir: Direction, n: Int, blocked: (Pos) -> Bool) -> [Pos]? {
        var out: [Pos] = []
        var q = p.moved(dir)
        while q.r >= 0 && q.r < n && q.c >= 0 && q.c < n {
            if blocked(q) { return nil }
            out.append(q)
            q = q.moved(dir)
        }
        return out
    }

    /// Special kinds for pieces listed in placement order (removal order is the reverse).
    private static func assignKinds(count: Int, heads: [Pos], stones: Set<Pos>, cfg: LevelConfig,
                                    rng: inout SeededRNG) -> [ArrowKind] {
        var kinds = Array(repeating: ArrowKind.normal, count: count)

        if cfg.features.contains(.keyLock) && count >= 8 {
            let third = count / 3
            let keyCount = count >= 20 ? 2 : 1
            let lockCount = count >= 20 ? 3 : 2
            for i in Array((count - third)..<count).shuffled(using: &rng).prefix(keyCount) { kinds[i] = .key }
            for i in Array(0..<third).shuffled(using: &rng).prefix(lockCount) { kinds[i] = .locked }
        }

        if cfg.features.contains(.bomb) && !stones.isEmpty {
            var bombs = 0
            for i in (0..<count).shuffled(using: &rng) where kinds[i] == .normal && bombs < 3 {
                let p = heads[i]
                let nearStone = stones.contains { abs($0.r - p.r) <= 1 && abs($0.c - p.c) <= 1 }
                if nearStone && Double.random(in: 0..<1, using: &rng) < 0.6 {
                    kinds[i] = .bomb
                    bombs += 1
                }
            }
        }

        for i in 0..<count where kinds[i] == .normal {
            let roll = Double.random(in: 0..<1, using: &rng)
            if cfg.features.contains(.twin) && roll < 0.11 {
                kinds[i] = .twin
            } else if cfg.features.contains(.ghost) && roll > 0.94 {
                kinds[i] = .ghost
            }
        }
        return kinds
    }

    static func generateTiles(_ cfg: LevelConfig) -> GeneratedBoard {
        var rng = SeededRNG(seed: cfg.seed)
        let n = cfg.size

        var cells: [Pos] = []
        for r in 0..<n { for c in 0..<n { cells.append(Pos(r: r, c: c)) } }
        cells.shuffle(using: &rng)

        let stones = Set(cells.prefix(cfg.stones))
        let free = cells.filter { !stones.contains($0) }
        let target = max(3, Int(Double(free.count) * cfg.fill))

        var occupied = Set<Pos>()
        var placed: [(pos: Pos, dir: Direction)] = []

        for p in free where placed.count < target {
            var options: [(dir: Direction, len: Int)] = []
            for d in Direction.allCases {
                if let len = laneLength(from: p, dir: d, n: n, blocked: { stones.contains($0) || occupied.contains($0) }) {
                    options.append((d, len))
                }
            }
            guard !options.isEmpty else { continue }
            options.shuffle(using: &rng)
            let pick: Direction
            if Double.random(in: 0..<1, using: &rng) < cfg.trickiness {
                pick = options.max(by: { $0.len < $1.len })!.dir
            } else {
                pick = options.randomElement(using: &rng)!.dir
            }
            occupied.insert(p)
            placed.append((p, pick))
        }

        let kinds = assignKinds(count: placed.count, heads: placed.map { $0.pos }, stones: stones, cfg: cfg, rng: &rng)

        let arrows = placed.enumerated().map { i, item in
            Arrow(id: i, pos: item.pos, dir: item.dir, kind: kinds[i])
        }
        return GeneratedBoard(size: n, arrows: arrows, stones: stones, cells: Set(cells))
    }

    /// Number of empty cells to the edge, or nil if something is in the way.
    private static func laneLength(from p: Pos, dir: Direction, n: Int, blocked: (Pos) -> Bool) -> Int? {
        var q = p.moved(dir)
        var len = 0
        while q.r >= 0 && q.r < n && q.c >= 0 && q.c < n {
            if blocked(q) { return nil }
            len += 1
            q = q.moved(dir)
        }
        return len
    }
}
