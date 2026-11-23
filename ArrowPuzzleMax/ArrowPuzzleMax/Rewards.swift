import SwiftUI

// MARK: - Daily Quests

enum QuestKind: String, CaseIterable {
    case arrows, wins, perfect, combo, blink, rush, daily

    /// Combo and Rush count your best single result; the rest add up over the day.
    var isBest: Bool { self == .combo || self == .rush }

    var icon: String {
        switch self {
        case .arrows: return "arrow.up.right"
        case .wins: return "flag.checkered"
        case .perfect: return "star.fill"
        case .combo: return "flame.fill"
        case .blink: return "eye.slash.fill"
        case .rush: return "bolt.fill"
        case .daily: return "calendar"
        }
    }

    fileprivate var goals: [Int] {
        switch self {
        case .arrows: return [40, 60, 90]
        case .wins: return [2, 3, 4]
        case .perfect: return [1, 2]
        case .combo: return [4, 5, 6]
        case .blink: return [2, 3]
        case .rush: return [3, 4, 5]
        case .daily: return [1]
        }
    }
}

struct Quest: Identifiable {
    let kind: QuestKind
    let goal: Int
    let reward: Int

    var id: String { kind.rawValue }

    var title: String {
        switch kind {
        case .arrows: return "Clear \(goal) arrows"
        case .wins: return "Win \(goal) Journey or Daily levels"
        case .perfect: return goal == 1 ? "Get 3 stars on a level" : "Get 3 stars on \(goal) levels"
        case .combo: return "Reach a ×\(goal) combo"
        case .blink: return "Clear \(goal) boards in Blink"
        case .rush: return "Clear \(goal) boards in one Time Rush"
        case .daily: return "Finish today's Daily Challenge"
        }
    }

    static let allDoneBonus = 100
    static let bonusID = "bonus"

    /// The same three quests for everyone on a given day.
    static func today(_ date: Date = Date()) -> [Quest] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var rng = SeededRNG(seed: UInt64(day) &* 2_654_435_761 &+ 97)
        let kinds = Array(QuestKind.allCases.shuffled(using: &rng).prefix(3))
        return kinds.map { k in
            let i = Int(rng.next() % UInt64(k.goals.count))
            let hard = Double(i) / Double(max(1, k.goals.count - 1))
            return Quest(kind: k, goal: k.goals[i], reward: 30 + Int(hard * 30) + (k == .blink || k == .rush ? 10 : 0))
        }
    }
}

extension ProgressStore {
    private var todayKey: String { Self.key(for: Date()) }

    /// Starts a fresh set of quests when the day changes.
    func rolloverQuests() {
        guard questDay != todayKey else { return }
        questDay = todayKey
        questProgress = [:]
        questClaimed = []
    }

    var quests: [Quest] { Quest.today() }

    /// Counts towards today's quests. `amount` is added, or for "best" quests kept if higher.
    func track(_ kind: QuestKind, _ amount: Int) {
        guard amount > 0 else { return }
        rolloverQuests()
        let old = questProgress[kind.rawValue] ?? 0
        questProgress[kind.rawValue] = kind.isBest ? max(old, amount) : old + amount
    }

    func progress(_ q: Quest) -> Int {
        if q.kind == .daily && dailyDone { return q.goal }   // also counts a Daily finished before the quests loaded
        return questDay == todayKey ? min(q.goal, questProgress[q.kind.rawValue] ?? 0) : 0
    }

    func isDone(_ q: Quest) -> Bool { progress(q) >= q.goal }

    func isClaimed(_ q: Quest) -> Bool { questDay == todayKey && questClaimed.contains(q.id) }

    @discardableResult
    func claim(_ q: Quest) -> Int {
        guard isDone(q), !isClaimed(q) else { return 0 }
        questClaimed.insert(q.id)
        coins += q.reward
        return q.reward
    }

    var allQuestsClaimed: Bool { quests.allSatisfy(isClaimed) }

    var bonusClaimed: Bool { questDay == todayKey && questClaimed.contains(Quest.bonusID) }

    @discardableResult
    func claimBonus() -> Int {
        guard allQuestsClaimed, !bonusClaimed else { return 0 }
        questClaimed.insert(Quest.bonusID)
        coins += Quest.allDoneBonus
        return Quest.allDoneBonus
    }

    /// Rewards waiting to be collected (for the red badge on the home screen).
    var questsToClaim: Int {
        quests.filter { isDone($0) && !isClaimed($0) }.count + (allQuestsClaimed && !bonusClaimed ? 1 : 0)
    }

    var questsDone: Int { quests.filter(isDone).count }

    // MARK: Lucky Spin

    /// One free spin a day. Test mode (unlimited coins) spins as often as you like.
    var canSpin: Bool { hasUnlimitedCoins || lastSpin != todayKey }

    /// Picks a prize, pays it out straight away and returns its slot on the wheel.
    func spin() -> Int {
        lastSpin = todayKey
        let total = SpinPrize.wheel.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<total)
        var index = 0
        for (i, p) in SpinPrize.wheel.enumerated() {
            if roll < p.weight { index = i; break }
            roll -= p.weight
        }
        let prize = SpinPrize.wheel[index]
        coins += prize.coins
        hints += prize.hints
        return index
    }
}

struct SpinPrize {
    let coins: Int
    let hints: Int
    let weight: Int

    var label: String { hints > 0 ? "\(hints)" : "\(coins)" }
    var icon: String { hints > 0 ? "lightbulb.fill" : "dollarsign.circle.fill" }
    var isJackpot: Bool { coins >= 500 }
    var text: String { hints > 0 ? "+\(hints) hint\(hints == 1 ? "" : "s")" : "+\(coins) coins" }

    /// Clockwise from the top.
    static let wheel: [SpinPrize] = [
        SpinPrize(coins: 25, hints: 0, weight: 22),
        SpinPrize(coins: 0, hints: 1, weight: 14),
        SpinPrize(coins: 50, hints: 0, weight: 18),
        SpinPrize(coins: 100, hints: 0, weight: 10),
        SpinPrize(coins: 0, hints: 2, weight: 8),
        SpinPrize(coins: 75, hints: 0, weight: 14),
        SpinPrize(coins: 250, hints: 0, weight: 4),
        SpinPrize(coins: 500, hints: 0, weight: 1),
    ]
}

// MARK: - Lucky Spin screen

private struct Wedge: Shape {
    let index: Int
    let count: Int

    func path(in r: CGRect) -> Path {
        let step = 360.0 / Double(count)
        let mid = -90 + Double(index) * step
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: min(r.width, r.height) / 2,
                 startAngle: .degrees(mid - step / 2), endAngle: .degrees(mid + step / 2), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct LuckySpinView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var won: SpinPrize?

    private let gold = Color(hex: 0xFFC300)

    var body: some View {
        let t = store.theme
        ZStack {
            ThemeBackground(theme: t, animated: false)
            VStack(spacing: 22) {
                HStack {
                    StatChip(icon: "dollarsign.circle.fill", value: store.coinText, tint: gold, theme: t)
                        .contentTransition(.numericText())
                    StatChip(icon: "lightbulb.fill", value: "\(store.hints)", tint: t.accent, theme: t)
                    Spacer()
                    CircleButton(icon: "xmark", theme: t) { dismiss() }
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text("LUCKY SPIN")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(t.text)
                    Text("One free spin every day")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(t.subtext)
                }

                wheel(t)
                    .frame(width: 300, height: 300)
                    .padding(.top, 6)

                if let won {
                    HStack(spacing: 8) {
                        Image(systemName: won.icon).foregroundStyle(won.hints > 0 ? t.accent : gold)
                        Text(won.isJackpot ? "JACKPOT! \(won.text)" : "You won \(won.text)")
                    }
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(t.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(t.text.opacity(0.1)))
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 0)

                if store.canSpin {
                    BigButton(title: spinning ? "Spinning…" : "SPIN", icon: "sparkles",
                              color: t.accent, ink: .black, action: spin)
                        .disabled(spinning)
                        .padding(.horizontal, 30)
                } else {
                    VStack(spacing: 6) {
                        Text("Next free spin")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(t.subtext)
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Text(timeToMidnight)
                                .font(.system(.title2, design: .rounded).weight(.black))
                                .monospacedDigit()
                                .foregroundStyle(t.text)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
            .readableWidth(560)
            .padding(.bottom, 10)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: won != nil)
        .interactiveDismissDisabled(spinning)
    }

    private func wheel(_ t: GameTheme) -> some View {
        let prizes = SpinPrize.wheel
        let colors = [t.arrows[0], t.arrows[1], t.arrows[2], t.arrows[3]]
        return ZStack {
            ZStack {
                ForEach(prizes.indices, id: \.self) { i in
                    Wedge(index: i, count: prizes.count)
                        .fill(prizes[i].isJackpot ? gold : colors[i % colors.count])
                    Wedge(index: i, count: prizes.count)
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                    VStack(spacing: 2) {
                        Image(systemName: prizes[i].isJackpot ? "crown.fill" : prizes[i].icon)
                            .font(.system(size: 18, weight: .black))
                        Text(prizes[i].label)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(prizes[i].isJackpot ? Color(hex: 0x5A3A00) : .white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(i) * 360 / Double(prizes.count)))
                }
            }
            .rotationEffect(.degrees(rotation))
            .shadow(color: t.accent.opacity(0.4), radius: 18)

            Circle().stroke(t.text.opacity(0.85), lineWidth: 6)
            Circle()
                .fill(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                .frame(width: 58, height: 58)
                .overlay(SkinTileView(dir: .up, theme: t, size: 34))
                .shadow(radius: 4)
            // Pointer at the top.
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 34))
                .foregroundStyle(t.text)
                .shadow(radius: 3)
                .offset(y: -160)
        }
    }

    private var timeToMidnight: String {
        let cal = Calendar.current
        let next = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let s = max(0, Int(next.timeIntervalSinceNow))
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    private func spin() {
        guard store.canSpin, !spinning else { return }
        won = nil
        spinning = true
        Haptics.heavy()
        let index = store.spin()
        let step = 360.0 / Double(SpinPrize.wheel.count)
        // Land slot `index` under the pointer, a little off centre so it looks natural.
        let target = -Double(index) * step + Double.random(in: -step * 0.3...step * 0.3)
        var delta = (target - rotation).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: 4)) {
            rotation += 360 * 5 + delta
        }
        for k in 0..<12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + pow(Double(k) / 12, 2) * 3.4) { Haptics.light() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.05) {
            spinning = false
            won = SpinPrize.wheel[index]
            Haptics.success()
        }
    }
}

// MARK: - Daily Quests screen

struct QuestsView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss

    private let gold = Color(hex: 0xFFC300)

    var body: some View {
        let t = store.theme
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill").foregroundStyle(gold)
                        Text("\(store.coinText) coins").contentTransition(.numericText())
                        Spacer()
                        Text("New quests at midnight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .padding(.horizontal, 4)

                    ForEach(store.quests) { q in row(q, t) }

                    bonusRow(t)
                }
                .padding()
                .readableWidth(640)
            }
            .background(ThemeBackground(theme: t, animated: false))
            .navigationTitle("Daily Quests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .onAppear { store.rolloverQuests() }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.questClaimed)
    }

    private func row(_ q: Quest, _ t: GameTheme) -> some View {
        let done = store.isDone(q), claimed = store.isClaimed(q)
        let p = store.progress(q)
        return HStack(spacing: 14) {
            Image(systemName: claimed ? "checkmark" : q.kind.icon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(claimed ? Color.green : t.arrows[(QuestKind.allCases.firstIndex(of: q.kind) ?? 0) % 4]))
            VStack(alignment: .leading, spacing: 6) {
                Text(q.title)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(t.text)
                ProgressView(value: Double(p), total: Double(q.goal))
                    .tint(done ? .green : t.accent)
                Text("\(p) / \(q.goal)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(t.subtext)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            claimButton(reward: q.reward, ready: done && !claimed, claimed: claimed, t) {
                if store.claim(q) > 0 { Haptics.success() }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(t.text.opacity(0.08)))
    }

    private func bonusRow(_ t: GameTheme) -> some View {
        let ready = store.allQuestsClaimed && !store.bonusClaimed
        return HStack(spacing: 14) {
            Image(systemName: store.bonusClaimed ? "gift.fill" : "shippingbox.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(hex: 0x5A3A00))
                .frame(width: 46, height: 46)
                .background(Circle().fill(gold))
                .bounceSymbol(value: ready)
            VStack(alignment: .leading, spacing: 4) {
                Text("Quest chest")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(t.text)
                Text("Claim all 3 quests to open it")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(t.subtext)
            }
            Spacer(minLength: 4)
            claimButton(reward: Quest.allDoneBonus, ready: ready, claimed: store.bonusClaimed, t) {
                if store.claimBonus() > 0 { Haptics.success() }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(gold.opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(gold.opacity(0.6), lineWidth: 1.5)))
    }

    private func claimButton(reward: Int, ready: Bool, claimed: Bool, _ t: GameTheme,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if claimed {
                    Image(systemName: "checkmark.circle.fill").font(.title3)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "dollarsign.circle.fill")
                        Text("\(reward)")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    if ready { Text("CLAIM").font(.caption2.weight(.black)) }
                }
            }
            .foregroundStyle(ready ? .black : t.text.opacity(claimed ? 0.5 : 0.8))
            .frame(width: 70, height: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ready ? gold : t.text.opacity(0.08)))
        }
        .buttonStyle(PressableStyle())
        .disabled(!ready)
    }
}
