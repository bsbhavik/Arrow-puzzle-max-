import SwiftUI

/// Saved player progress (UserDefaults). Journey progress is kept separately for each game style.
final class ProgressStore: ObservableObject {
    private static let d = UserDefaults.standard

    @Published var styleID: String { didSet { Self.d.set(styleID, forKey: "style") } }
    @Published private var unlockedMap: [String: Int] { didSet { Self.d.set(unlockedMap, forKey: "unlockedMap") } }
    @Published private var starsMap: [String: [String: Int]] { didSet { Self.d.set(starsMap, forKey: "starsMap") } }
    @Published var hints: Int { didSet { Self.d.set(hints, forKey: "hints") } }
    @Published var bestRush: Int { didSet { Self.d.set(bestRush, forKey: "bestRush") } }
    @Published var bestZen: Int { didSet { Self.d.set(bestZen, forKey: "bestZen") } }
    @Published var bestBlink: Int { didSet { Self.d.set(bestBlink, forKey: "bestBlink") } }
    /// Daily Quests: which day the progress belongs to, progress per quest kind, and what was claimed.
    @Published var questDay: String { didSet { Self.d.set(questDay, forKey: "questDay") } }
    @Published var questProgress: [String: Int] { didSet { Self.d.set(questProgress, forKey: "questProgress") } }
    @Published var questClaimed: Set<String> { didSet { Self.d.set(Array(questClaimed), forKey: "questClaimed") } }
    /// Day of the last free Lucky Spin.
    @Published var lastSpin: String { didSet { Self.d.set(lastSpin, forKey: "lastSpin") } }
    @Published var themeID: String { didSet { Self.d.set(themeID, forKey: "theme") } }
    @Published var haptics: Bool {
        didSet {
            Self.d.set(haptics, forKey: "haptics")
            Haptics.enabled = haptics
        }
    }
    @Published var seenFeatures: Set<String> { didSet { Self.d.set(Array(seenFeatures), forKey: "seenFeatures") } }
    @Published var lastDaily: String { didSet { Self.d.set(lastDaily, forKey: "lastDaily") } }
    @Published var dailyStreak: Int { didSet { Self.d.set(dailyStreak, forKey: "dailyStreak") } }
    @Published var customLevels: [CustomLevel] {
        didSet {
            if let data = try? JSONEncoder().encode(customLevels) { Self.d.set(data, forKey: "customLevels") }
        }
    }
    /// Test mode: buying never costs coins. Only works in Debug builds (see `hasUnlimitedCoins`).
    @Published var unlimitedCoins: Bool { didSet { Self.d.set(unlimitedCoins, forKey: "unlimitedCoins") } }
    @Published var coins: Int { didSet { Self.d.set(coins, forKey: "coins") } }
    @Published var ownedThemes: Set<String> { didSet { Self.d.set(Array(ownedThemes), forKey: "ownedThemes") } }
    @Published var backgroundID: String { didSet { Self.d.set(backgroundID, forKey: "bg") } }
    @Published var lineModeID: String { didSet { Self.d.set(lineModeID, forKey: "lineMode") } }
    @Published var animSpeedID: String { didSet { Self.d.set(animSpeedID, forKey: "anim") } }

    init() {
        let d = Self.d
        styleID = d.string(forKey: "style") ?? GameStyle.tiles.rawValue
        var unlocked = d.dictionary(forKey: "unlockedMap") as? [String: Int] ?? [:]
        var stars = d.dictionary(forKey: "starsMap") as? [String: [String: Int]] ?? [:]
        // Carry over progress saved before styles existed.
        if unlocked.isEmpty, d.integer(forKey: "unlocked") > 0 {
            unlocked[GameStyle.tiles.rawValue] = d.integer(forKey: "unlocked")
            stars[GameStyle.tiles.rawValue] = d.dictionary(forKey: "stars") as? [String: Int] ?? [:]
        }
        unlockedMap = unlocked
        starsMap = stars
        hints = d.object(forKey: "hints") as? Int ?? 5
        bestRush = d.integer(forKey: "bestRush")
        bestZen = d.integer(forKey: "bestZen")
        bestBlink = d.integer(forKey: "bestBlink")
        questDay = d.string(forKey: "questDay") ?? ""
        questProgress = d.dictionary(forKey: "questProgress") as? [String: Int] ?? [:]
        questClaimed = Set(d.stringArray(forKey: "questClaimed") ?? [])
        lastSpin = d.string(forKey: "lastSpin") ?? ""
        themeID = d.string(forKey: "theme") ?? GameTheme.neon.id
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        seenFeatures = Set(d.stringArray(forKey: "seenFeatures") ?? [])
        lastDaily = d.string(forKey: "lastDaily") ?? ""
        dailyStreak = d.integer(forKey: "dailyStreak")
        coins = d.integer(forKey: "coins")
        unlimitedCoins = d.bool(forKey: "unlimitedCoins")
        customLevels = d.data(forKey: "customLevels")
            .flatMap { try? JSONDecoder().decode([CustomLevel].self, from: $0) } ?? []
        let savedTheme = d.string(forKey: "theme") ?? GameTheme.neon.id
        // Free themes, plus whatever theme was already in use before themes cost coins.
        ownedThemes = Set(d.stringArray(forKey: "ownedThemes") ?? [])
            .union(GameTheme.all.filter { $0.price == 0 }.map(\.id))
            .union([savedTheme])
        backgroundID = d.string(forKey: "bg") ?? BoardBackground.dots.rawValue
        lineModeID = d.string(forKey: "lineMode") ?? LineColorMode.direction.rawValue
        animSpeedID = d.string(forKey: "anim") ?? AnimSpeed.normal.rawValue
        Haptics.enabled = haptics
    }

    var theme: GameTheme { GameTheme.all.first { $0.id == themeID } ?? .neon }

    var style: GameStyle {
        get { GameStyle(rawValue: styleID) ?? .tiles }
        set { styleID = newValue.rawValue }
    }

    // MARK: View settings

    var boardBackground: BoardBackground {
        get { BoardBackground(rawValue: backgroundID) ?? .dots }
        set { backgroundID = newValue.rawValue }
    }

    var lineColorMode: LineColorMode {
        get { LineColorMode(rawValue: lineModeID) ?? .direction }
        set { lineModeID = newValue.rawValue }
    }

    var animSpeed: AnimSpeed {
        get { AnimSpeed(rawValue: animSpeedID) ?? .normal }
        set { animSpeedID = newValue.rawValue }
    }

    // MARK: Journey

    func unlocked(_ s: GameStyle) -> Int { max(1, unlockedMap[s.rawValue] ?? 1) }

    func stars(_ s: GameStyle, level: Int) -> Int { starsMap[s.rawValue]?[String(level)] ?? 0 }

    func totalStars(_ s: GameStyle) -> Int { (starsMap[s.rawValue] ?? [:]).values.reduce(0, +) }

    var totalStars: Int { GameStyle.allCases.reduce(0) { $0 + totalStars($1) } }

    /// Saves a Journey win and pays coins. Returns the coins earned.
    @discardableResult
    func complete(style s: GameStyle, level: Int, stars new: Int) -> Int {
        let old = stars(s, level: level)
        if new == 3 && old < 3 { hints += 1 }
        var table = starsMap[s.rawValue] ?? [:]
        table[String(level)] = max(old, new)
        starsMap[s.rawValue] = table
        if level >= unlocked(s) { unlockedMap[s.rawValue] = min(GameStyle.maxLevel, level + 1) }

        // First clear pays full; replays only pay for extra stars (plus a small tip).
        var reward = old == 0
            ? 10 + 5 * new + min(level / 50, 20) + (s == .maze ? 5 : 0)
            : max(2, 5 * (new - old))
        if LevelConfig.isBoss(level) { reward *= 2 }
        coins += reward
        return reward
    }

    /// Coins for a Time Rush / Zen run: per board cleared.
    @discardableResult
    func rewardRun(boards: Int, perBoard: Int) -> Int {
        let r = boards * perBoard
        coins += r
        return r
    }

    // MARK: Level Creator

    func saveCustom(_ level: CustomLevel) {
        var l = level
        l.updated = Date()
        if let i = customLevels.firstIndex(where: { $0.id == l.id }) {
            customLevels[i] = l
        } else {
            customLevels.insert(l, at: 0)
        }
    }

    func deleteCustom(_ id: UUID) { customLevels.removeAll { $0.id == id } }

    // MARK: Themes

    /// Always false in Release builds, so the test switch can never ship by accident.
    var hasUnlimitedCoins: Bool {
        #if DEBUG
        return unlimitedCoins
        #else
        return false
        #endif
    }

    /// What to show wherever the coin balance appears.
    var coinText: String { hasUnlimitedCoins ? "∞" : "\(coins)" }

    func owns(_ t: GameTheme) -> Bool { t.price == 0 || ownedThemes.contains(t.id) }

    @discardableResult
    func buy(_ t: GameTheme) -> Bool {
        guard !owns(t) else { return false }
        if !hasUnlimitedCoins {
            guard coins >= t.price else { return false }
            coins -= t.price
        }
        ownedThemes.insert(t.id)
        themeID = t.id
        return true
    }

    // MARK: Daily

    static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var dailyDone: Bool { lastDaily == Self.key(for: Date()) }

    @discardableResult
    func recordDaily() -> Int {
        let today = Self.key(for: Date())
        guard lastDaily != today else { return 0 }
        let yesterday = Self.key(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        dailyStreak = lastDaily == yesterday ? dailyStreak + 1 : 1
        lastDaily = today
        hints += 2
        coins += 50
        return 50
    }
}
