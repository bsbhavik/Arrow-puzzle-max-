import SwiftUI

// MARK: - Direction

enum Direction: Int, CaseIterable, Hashable, Codable {
    case up = 0, right, down, left

    var dr: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        default: return 0
        }
    }

    var dc: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        default: return 0
        }
    }

    var opposite: Direction { Direction(rawValue: (rawValue + 2) % 4)! }

    /// Rotation for a symbol that is drawn pointing up.
    var degrees: Double { Double(rawValue) * 90 }
}

// MARK: - Board position

struct Pos: Hashable, Codable {
    let r: Int
    let c: Int

    func moved(_ d: Direction) -> Pos { Pos(r: r + d.dr, c: c + d.dc) }
}

// MARK: - Arrow pieces

enum ArrowKind: String, Codable, CaseIterable {
    /// Plain arrow: slides out in its direction if the path is clear.
    case normal
    /// Double-headed: escapes through whichever side is clear.
    case twin
    /// Phases through other arrows. Only stone blocks stop it.
    case ghost
    /// Blows up stone blocks around its starting cell when it escapes.
    case bomb
    /// Gold arrow. Every lock on the board opens once all keys are out.
    case key
    /// Cannot move while any key arrow is still on the board.
    case locked
}

struct Arrow: Identifiable, Equatable {
    let id: Int
    /// Body cells from tail to head. Tile arrows have exactly one cell.
    var cells: [Pos]
    var dir: Direction
    var kind: ArrowKind

    // Animation state
    var travel: CGFloat = 0
    var travelDir: Direction = .up
    var escaping = false

    init(id: Int, cells: [Pos], dir: Direction, kind: ArrowKind) {
        self.id = id
        self.cells = cells
        self.dir = dir
        self.kind = kind
    }

    init(id: Int, pos: Pos, dir: Direction, kind: ArrowKind) {
        self.init(id: id, cells: [pos], dir: dir, kind: kind)
    }

    /// The head cell (where the arrowhead is).
    var pos: Pos { cells[cells.count - 1] }
}

// MARK: - Game style

enum GameStyle: String, CaseIterable, Identifiable, Hashable, Codable {
    /// One arrow per square tile.
    case tiles
    /// Long bending ribbon arrows that slide out along their own path.
    case ribbons
    /// Huge, dense, shaped boards of thin line arrows with pinch-to-zoom.
    case maze

    var id: String { rawValue }

    /// Journey length for every style.
    static let maxLevel = 10_000

    var title: String {
        switch self {
        case .tiles: return "Tiles"
        case .ribbons: return "Ribbons"
        case .maze: return "Maze"
        }
    }

    var icon: String {
        switch self {
        case .tiles: return "square.grid.3x3.fill"
        case .ribbons: return "scribble.variable"
        case .maze: return "squareshape.split.3x3"
        }
    }

    var blurb: String {
        switch self {
        case .tiles: return "Arrow tiles + specials"
        case .ribbons: return "Bold bending arrows"
        case .maze: return "Huge shaped mazes, zoom"
        }
    }

    func supports(_ f: Feature) -> Bool {
        switch self {
        case .tiles: return true
        case .ribbons: return f != .twin           // twins only make sense as single tiles
        case .maze: return f == .keyLock           // keep giant mazes clean
        }
    }
}

// MARK: - Board shapes (Maze style)

enum BoardShape: String, CaseIterable, Codable {
    case square, heart, circle, diamond, flower, plus, ring
    // Creatures
    case cat, fish, bird, turtle, butterfly, bunny
    // Objects
    case mushroom, star, house, tree, apple, crown, moon, ghost

    var title: String {
        switch self {
        case .square: return "Square"
        case .heart: return "Heart"
        case .circle: return "Circle"
        case .diamond: return "Diamond"
        case .flower: return "Flower"
        case .plus: return "Plus"
        case .ring: return "Ring"
        case .cat: return "Cat"
        case .fish: return "Fish"
        case .bird: return "Bird"
        case .turtle: return "Turtle"
        case .butterfly: return "Butterfly"
        case .bunny: return "Bunny"
        case .mushroom: return "Mushroom"
        case .star: return "Star"
        case .house: return "House"
        case .tree: return "Tree"
        case .apple: return "Apple"
        case .crown: return "Crown"
        case .moon: return "Moon"
        case .ghost: return "Ghost"
        }
    }

    var emoji: String {
        switch self {
        case .cat: return "🐱"
        case .fish: return "🐟"
        case .bird: return "🐦"
        case .turtle: return "🐢"
        case .butterfly: return "🦋"
        case .bunny: return "🐰"
        case .heart: return "❤️"
        case .flower: return "🌸"
        case .mushroom: return "🍄"
        case .star: return "⭐"
        case .house: return "🏠"
        case .tree: return "🌲"
        case .apple: return "🍎"
        case .crown: return "👑"
        case .moon: return "🌙"
        case .ghost: return "👻"
        default: return ""
        }
    }

    private static func ellipse(_ x: Double, _ y: Double, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Bool {
        let dx = (x - cx) / rx, dy = (y - cy) / ry
        return dx * dx + dy * dy <= 1
    }

    private static func triangle(_ x: Double, _ y: Double,
                                 _ a: (Double, Double), _ b: (Double, Double), _ c: (Double, Double)) -> Bool {
        func side(_ p: (Double, Double), _ q: (Double, Double)) -> Double {
            (x - q.0) * (p.1 - q.1) - (p.0 - q.0) * (y - q.1)
        }
        let d1 = side(a, b), d2 = side(b, c), d3 = side(c, a)
        let neg = d1 < 0 || d2 < 0 || d3 < 0
        let pos = d1 > 0 || d2 > 0 || d3 > 0
        return !(neg && pos)
    }

    /// x, y in -1...1 with y pointing down.
    func contains(x: Double, y: Double) -> Bool {
        let r = (x * x + y * y).squareRoot()
        let E = Self.ellipse, T = Self.triangle
        switch self {
        case .cat:
            return E(x, y, 0, 0.18, 0.8, 0.72)
                || T(x, y, (-0.8, -0.05), (-0.62, -0.98), (-0.12, -0.45))
                || T(x, y, (0.8, -0.05), (0.62, -0.98), (0.12, -0.45))
        case .fish:
            return E(x, y, -0.18, 0, 0.72, 0.5)
                || T(x, y, (0.38, 0), (1.0, -0.62), (1.0, 0.62))
                || T(x, y, (-0.35, -0.38), (0.05, -0.75), (0.15, -0.3))
        case .bird:
            return E(x, y, 0.08, 0.22, 0.62, 0.48)
                || E(x, y, -0.45, -0.38, 0.34, 0.32)
                || T(x, y, (-0.7, -0.48), (-1.0, -0.3), (-0.7, -0.22))
                || T(x, y, (0.55, 0.05), (1.0, -0.35), (1.0, 0.3))
                || T(x, y, (-0.1, 0.62), (0.05, 1.0), (0.2, 0.62))
        case .turtle:
            return E(x, y, -0.05, 0, 0.62, 0.48)
                || E(x, y, 0.78, -0.05, 0.22, 0.2)
                || E(x, y, -0.48, -0.5, 0.18, 0.17) || E(x, y, 0.38, -0.5, 0.18, 0.17)
                || E(x, y, -0.48, 0.5, 0.18, 0.17) || E(x, y, 0.38, 0.5, 0.18, 0.17)
                || T(x, y, (-0.62, -0.08), (-0.95, 0), (-0.62, 0.08))
        case .butterfly:
            return E(x, y, -0.5, -0.3, 0.46, 0.52) || E(x, y, 0.5, -0.3, 0.46, 0.52)
                || E(x, y, -0.4, 0.48, 0.34, 0.36) || E(x, y, 0.4, 0.48, 0.34, 0.36)
                || E(x, y, 0, 0.05, 0.12, 0.8)
        case .bunny:
            return E(x, y, 0, 0.4, 0.58, 0.52)
                || E(x, y, -0.25, -0.42, 0.15, 0.5) || E(x, y, 0.25, -0.42, 0.15, 0.5)
        case .mushroom:
            return (E(x, y, 0, -0.12, 0.98, 0.68) && y <= 0.12)
                || (abs(x) < 0.32 && y > 0 && y < 0.98)
        case .star:
            // Five-pointed star: fold the angle into one point, then test against its edge.
            let k = 2 * Double.pi / 5
            var t = (atan2(y, x) + .pi / 2 + 4 * .pi).truncatingRemainder(dividingBy: k)
            if t > k / 2 { t = k - t }
            let p1 = (1.08, 0.0), p2 = (0.52 * cos(k / 2), 0.52 * sin(k / 2))
            let q = (r * cos(t), r * sin(t))
            let ex = p2.0 - p1.0, ey = p2.1 - p1.1
            let sq = ex * (q.1 - p1.1) - ey * (q.0 - p1.0)
            let so = ex * (0 - p1.1) - ey * (0 - p1.0)
            return sq * so >= 0
        case .house:
            return T(x, y, (-1.0, -0.05), (0, -1.0), (1.0, -0.05))
                || (abs(x) < 0.75 && y > -0.12 && y < 0.98)
                || (x > 0.35 && x < 0.62 && y > -0.85 && y < -0.3)
        case .tree:
            return T(x, y, (-0.55, -0.35), (0, -1.0), (0.55, -0.35))
                || T(x, y, (-0.78, 0.15), (0, -0.62), (0.78, 0.15))
                || T(x, y, (-0.98, 0.66), (0, -0.18), (0.98, 0.66))
                || (abs(x) < 0.2 && y > 0.55 && y < 1)
        case .apple:
            return E(x, y, -0.3, 0.15, 0.6, 0.78) || E(x, y, 0.3, 0.15, 0.6, 0.78)
                || (abs(x + 0.02) < 0.08 && y > -0.92 && y < -0.5)
                || E(x, y, 0.3, -0.72, 0.26, 0.13)
        case .crown:
            return (abs(x) < 0.92 && y > 0.1 && y < 0.72)
                || T(x, y, (-0.92, 0.15), (-0.78, -0.82), (-0.34, 0.15))
                || T(x, y, (-0.4, 0.15), (0, -0.98), (0.4, 0.15))
                || T(x, y, (0.34, 0.15), (0.78, -0.82), (0.92, 0.15))
        case .moon:
            return E(x, y, 0, 0, 0.98, 0.98) && !E(x, y, 0.4, -0.12, 0.82, 0.82)
        case .ghost:
            return (E(x, y, 0, -0.18, 0.78, 0.78) && y <= -0.18)
                || (abs(x) < 0.78 && y > -0.2 && y < 0.72 + 0.22 * cos(x * .pi * 2.6))
        default:
            break
        }
        switch self {
        case .square:
            return true
        case .heart:
            let hx = x * 1.2, hy = -y * 1.15 + 0.13
            let a = hx * hx + hy * hy - 1
            return a * a * a - hx * hx * hy * hy * hy <= 0
        case .circle:
            return r <= 1.02
        case .diamond:
            return abs(x) + abs(y) <= 1.08
        case .flower:
            let a = atan2(y, x)
            return r <= 0.72 + 0.28 * cos(5 * (a + .pi / 2))
        case .plus:
            return abs(x) < 0.4 || abs(y) < 0.4
        case .ring:
            return r <= 1.02 && r >= 0.4
        default:
            return false
        }
    }

    func mask(_ n: Int) -> Set<Pos> {
        var out = Set<Pos>()
        for r in 0..<n {
            for c in 0..<n {
                let x = (Double(c) + 0.5) / Double(n) * 2 - 1
                let y = (Double(r) + 0.5) / Double(n) * 2 - 1
                if contains(x: x, y: y) { out.insert(Pos(r: r, c: c)) }
            }
        }
        return out
    }
}

// MARK: - View settings

enum BoardBackground: String, CaseIterable, Identifiable {
    case dots, grid, plain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dots: return "Dots"
        case .grid: return "Grid"
        case .plain: return "Plain"
        }
    }
}

enum LineColorMode: String, CaseIterable, Identifiable {
    case direction, regions, ink
    var id: String { rawValue }
    var title: String {
        switch self {
        case .direction: return "By direction"
        case .regions: return "By area"
        case .ink: return "One colour"
        }
    }
}

enum AnimSpeed: String, CaseIterable, Identifiable {
    case slow, normal, fast
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var factor: Double {
        switch self {
        case .slow: return 1.7
        case .normal: return 1
        case .fast: return 0.6
        }
    }
}

// MARK: - Special features (unlocked through Journey)

enum Feature: String, CaseIterable, Identifiable {
    case twin, ghost, bomb, keyLock

    var id: String { rawValue }

    var unlockLevel: Int {
        switch self {
        case .twin: return 4
        case .ghost: return 8
        case .bomb: return 12
        case .keyLock: return 16
        }
    }

    var title: String {
        switch self {
        case .twin: return "Twin Arrow"
        case .ghost: return "Ghost Arrow"
        case .bomb: return "Bomb Arrow"
        case .keyLock: return "Key & Lock"
        }
    }

    var icon: String {
        switch self {
        case .twin: return "arrow.up.and.down"
        case .ghost: return "sparkles"
        case .bomb: return "flame.fill"
        case .keyLock: return "key.fill"
        }
    }

    var detail: String {
        switch self {
        case .twin:
            return "Points both ways. It escapes through whichever side is clear."
        case .ghost:
            return "Dashed arrows phase straight through other arrows. Only stone blocks stop them."
        case .bomb:
            return "When a bomb arrow escapes it blasts every stone block around where it was standing."
        case .keyLock:
            return "Locked arrows can't move until every gold key arrow has left the board."
        }
    }
}

// MARK: - Modes

enum GameMode: String, Hashable, CaseIterable, Identifiable {
    case journey, daily, rush, zen
    /// Memory mode: arrows show for a few seconds, then their directions hide.
    case blink
    /// A level made in the Level Creator.
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journey: return "Journey"
        case .daily: return "Daily Challenge"
        case .rush: return "Time Rush"
        case .zen: return "Zen"
        case .blink: return "Blink"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .journey: return "map.fill"
        case .daily: return "calendar"
        case .rush: return "bolt.fill"
        case .zen: return "leaf.fill"
        case .blink: return "eye.slash.fill"
        case .custom: return "hammer.fill"
        }
    }

    var usesHearts: Bool { self == .journey || self == .daily || self == .custom || self == .blink }

    /// Modes that deal a new board each time one is cleared.
    var isEndless: Bool { self == .rush || self == .zen || self == .blink }
}

enum PlayState: Equatable {
    case playing
    case won(stars: Int)
    case lost
}

// MARK: - Effects

struct Blast: Identifiable {
    let id = UUID()
    let pos: Pos
}

struct FloatText: Identifiable {
    let id = UUID()
    let text: String
    let pos: Pos
    let color: Color
}

struct RayPreview: Equatable {
    let origin: Pos
    let cells: [Pos]
    let blockedAt: Pos?
    let locked: Bool
}
