import SwiftUI

// MARK: - Level Creator model

struct CustomArrow: Codable, Hashable {
    /// Tail to head.
    var cells: [Pos]
    var dir: Direction
    var kind: ArrowKind

    var pos: Pos { cells[cells.count - 1] }
}

struct CustomLevel: Codable, Hashable, Identifiable {
    var id = UUID()
    var name = "My Level"
    var style: GameStyle = .tiles
    var size = 6
    var shape: BoardShape = .square
    var arrows: [CustomArrow] = []
    var stones: [Pos] = []
    var updated = Date()

    static let sizeRange = 4...20

    var mask: Set<Pos> { shape.mask(size) }

    func board() -> GeneratedBoard {
        GeneratedBoard(
            size: size,
            arrows: arrows.enumerated().map { i, a in Arrow(id: i, cells: a.cells, dir: a.dir, kind: a.kind) },
            stones: Set(stones),
            cells: mask)
    }

    /// Indices of arrows that can never leave the board. Empty = the level can be finished.
    var stuck: Set<Int> { LevelValidator.stuck(board()) }

    var isPlayable: Bool { !arrows.isEmpty && stuck.isEmpty }

    /// Drops pieces that no longer fit after the size or shape changes. Returns how many were removed.
    @discardableResult
    mutating func prune() -> Int {
        let m = mask
        let before = arrows.count + stones.count
        arrows.removeAll { !$0.cells.allSatisfy(m.contains) }
        stones.removeAll { !m.contains($0) }
        return before - arrows.count - stones.count
    }

    // MARK: Share codes

    private static let codePrefix = "APM1:"

    var shareCode: String {
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        let data = (try? enc.encode(self)) ?? Data()
        return Self.codePrefix + data.base64EncodedString()
    }

    /// Parses a pasted share code. Codes come from other people, so everything is range-checked.
    static func from(code: String) -> CustomLevel? {
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix(codePrefix), text.count < 200_000,
              let data = Data(base64Encoded: String(text.dropFirst(codePrefix.count))),
              var level = try? JSONDecoder().decode(CustomLevel.self, from: data),
              sizeRange.contains(level.size),
              level.arrows.count <= level.size * level.size,
              level.stones.count <= level.size * level.size
        else { return nil }
        let n = level.size
        func inside(_ p: Pos) -> Bool { p.r >= 0 && p.r < n && p.c >= 0 && p.c < n }
        guard level.arrows.allSatisfy({ !$0.cells.isEmpty && $0.cells.allSatisfy(inside) }),
              level.stones.allSatisfy(inside) else { return nil }
        level.id = UUID()
        level.name = String(level.name.prefix(40))
        level.updated = Date()
        return level
    }

    /// A random, always-solvable starting point using the game's own generator.
    static func autoFill(style: GameStyle, size: Int, shape: BoardShape, name: String, id: UUID) -> CustomLevel {
        let cfg = LevelConfig(
            size: size,
            stones: style == .maze ? 0 : size / 3,
            fill: 0.9,
            trickiness: 0.7,
            features: [],
            seed: UInt64.random(in: 1...UInt64.max),
            style: style,
            minLen: 2,
            maxLen: style == .maze ? 10 : 6,
            straightness: 0.55,
            shape: shape,
            allowStubs: style == .maze)
        let b = LevelGenerator.generate(cfg)
        let m = shape.mask(size)
        // Tile boards ignore the shape, so trim to it. Removing pieces never makes a level harder to solve.
        var level = CustomLevel(id: id, name: name, style: style, size: size, shape: shape)
        level.arrows = b.arrows
            .filter { $0.cells.allSatisfy(m.contains) }
            .map { CustomArrow(cells: $0.cells, dir: $0.dir, kind: .normal) }
        level.stones = b.stones.filter(m.contains).sorted { ($0.r, $0.c) < ($1.r, $1.c) }
        return level
    }
}

// MARK: - Validator

enum LevelValidator {
    /// Clears every arrow that can leave, over and over (bombs break stones, keys open locks).
    /// Clearing an arrow never blocks another one, so whatever is left at the end can never escape.
    static func stuck(_ b: GeneratedBoard) -> Set<Int> {
        var left = b.arrows
        var stones = b.stones
        let n = b.size
        var progress = true
        while progress && !left.isEmpty {
            progress = false
            let keys = left.contains { $0.kind == .key }
            var occupied: [Pos: Int] = [:]
            for a in left { for c in a.cells { occupied[c] = a.id } }
            for (i, a) in left.enumerated() {
                if a.kind == .locked && keys { continue }
                func clear(_ d: Direction) -> Bool {
                    var p = a.pos.moved(d)
                    while p.r >= 0 && p.r < n && p.c >= 0 && p.c < n {
                        if stones.contains(p) { return false }
                        if a.kind != .ghost, let o = occupied[p], o != a.id { return false }
                        p = p.moved(d)
                    }
                    return true
                }
                if clear(a.dir) || (a.kind == .twin && clear(a.dir.opposite)) {
                    if a.kind == .bomb {
                        for dr in -1...1 { for dc in -1...1 { stones.remove(Pos(r: a.pos.r + dr, c: a.pos.c + dc)) } }
                    }
                    left.remove(at: i)
                    progress = true
                    break
                }
            }
        }
        return Set(left.map(\.id))
    }
}
