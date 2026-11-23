import SwiftUI

struct GameView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: GameEngine
    @State private var featureIntro: Feature?
    @State private var noHintsAlert = false
    @State private var showHow = false
    @State private var showDisplay = false
    @State private var coinsEarned = 0

    init(custom: CustomLevel) {
        _engine = StateObject(wrappedValue: GameEngine(mode: .custom, level: 0, style: custom.style,
                                                       customBoard: custom.board(), customName: custom.name))
    }

    init(mode: GameMode, level: Int, style: GameStyle) {
        _engine = StateObject(wrappedValue: GameEngine(mode: mode, level: level, style: style))
    }

    var body: some View {
        let t = store.theme
        ZStack {
            ThemeBackground(theme: t, animated: false)

            VStack(spacing: 14) {
                topBar(t)
                statusRow(t)
                HStack(spacing: 0) {
                    progressBar(t)
                    Text("\(engine.remaining) left")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(t.subtext)
                        .monospacedDigit()
                        .padding(.trailing)
                }
                Spacer(minLength: 0)
                BoardView(engine: engine, theme: t,
                          background: store.boardBackground, lineMode: store.lineColorMode)
                    .padding(.horizontal, 14)
                Spacer(minLength: 0)
                Text(tip)
                    .font(.footnote.weight(engine.mode == .blink ? .bold : .medium))
                    .foregroundStyle(engine.mode == .blink && !engine.hidden ? t.accent : t.subtext)
                    .contentTransition(.opacity)
                bottomBar(t)
            }
            .padding(.vertical, 8)
            .readableWidth(860)

            if let f = featureIntro {
                FeatureIntroCard(feature: f, theme: t) {
                    store.seenFeatures.insert(f.rawValue)
                    withAnimation(.spring()) { featureIntro = nil }
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(5)
            }

            if engine.state != .playing {
                ResultOverlay(engine: engine, theme: t,
                              best: engine.mode == .rush ? store.bestRush
                                  : engine.mode == .blink ? store.bestBlink : store.bestZen,
                              coins: coinsEarned,
                              shareText: shareText,
                              onNext: nextLevel,
                              onRetry: { engine.restart() },
                              onHome: { dismiss() })
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.state)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            engine.speed = store.animSpeed.factor
            checkFeatureIntro()
        }
        .onChangeCompat(of: store.animSpeedID) { _, _ in engine.speed = store.animSpeed.factor }
        .onDisappear {
            engine.stop()
            if engine.mode == .zen {
                store.bestZen = max(store.bestZen, engine.score)
                store.rewardRun(boards: engine.round, perBoard: 3)
            }
            if engine.mode == .blink && engine.state == .playing {   // left mid-run: keep what was earned
                store.bestBlink = max(store.bestBlink, engine.score)
                store.rewardRun(boards: engine.round, perBoard: 6)
            }
        }
        .onChangeCompat(of: engine.state) { _, s in record(s) }
        .onChangeCompat(of: engine.cleared) { old, new in
            if engine.mode != .custom { store.track(.arrows, new - old) }
        }
        .onChangeCompat(of: engine.bestCombo) { _, c in
            if engine.mode != .custom { store.track(.combo, c) }
        }
        .onChangeCompat(of: engine.round) { old, new in
            if engine.mode == .blink && new > old { store.track(.blink, new - old) }
        }
        .sheet(isPresented: $showHow) { HowToPlayView().environmentObject(store) }
        .sheet(isPresented: $showDisplay) { DisplaySettingsView().environmentObject(store) }
        .alert("No hints left", isPresented: $noHintsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Earn hints by 3-starring levels (+1) and finishing the Daily Challenge (+2).")
        }
    }

    // MARK: - Header

    private var title: String {
        switch engine.mode {
        case .journey: return "Level \(engine.level)" + shapeSuffix
        case .daily: return Date().formatted(.dateTime.month(.abbreviated).day()) + " Daily" + shapeSuffix
        case .rush: return "Time Rush · Board \(engine.round + 1)"
        case .zen: return "Zen · Board \(engine.round + 1)"
        case .blink: return "Blink · Board \(engine.round + 1)"
        case .custom: return engine.customName ?? "Custom level"
        }
    }

    private func topBar(_ t: GameTheme) -> some View {
        HStack {
            CircleButton(icon: "chevron.left", theme: t) { dismiss() }
            Spacer()
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(t.text)
                .contentTransition(.numericText())
            Spacer()
            CircleButton(icon: "arrow.clockwise", theme: t) {
                withAnimation { engine.restart() }
            }
        }
        .padding(.horizontal)
    }

    private func statusRow(_ t: GameTheme) -> some View {
        HStack(spacing: 12) {
            Group {
                switch engine.mode {
                case .journey, .daily, .custom, .blink:
                    HStack(spacing: 4) {
                        ForEach(0..<engine.maxHearts, id: \.self) { i in
                            Image(systemName: i < engine.hearts ? "heart.fill" : "heart")
                                .foregroundStyle(i < engine.hearts ? Color(hex: 0xFF4D6D) : t.subtext)
                                .scaleEffect(i < engine.hearts ? 1 : 0.85)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: engine.hearts)
                case .rush:
                    Label("\(Int(engine.timeLeft.rounded(.up)))s", systemImage: "timer")
                        .foregroundStyle(engine.timeLeft < 10 ? Color.red : t.text)
                        .contentTransition(.numericText())
                case .zen:
                    Label("Relax", systemImage: "leaf.fill")
                        .foregroundStyle(t.accent)
                }
            }
            .font(.system(.headline, design: .rounded).weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(t.text.opacity(0.08)))

            if let d = engine.difficulty {
                Text(d)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(t.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(t.text.opacity(0.08)))
            }

            if engine.mode == .blink && engine.memorizeLeft > 0 {
                Label(String(format: "%.0fs", engine.memorizeLeft.rounded(.up)), systemImage: "eye.fill")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(t.accent))
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }

            Spacer()

            if engine.combo >= 2 {
                Text("COMBO ×\(min(engine.combo, 8))")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(t.accent))
                    .transition(.scale.combined(with: .opacity))
                    .id(engine.combo)
            }

            Text("\(engine.score)")
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(t.text)
                .contentTransition(.numericText())
                .animation(.snappy, value: engine.score)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: engine.combo)
        .padding(.horizontal)
    }

    private func progressBar(_ t: GameTheme) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(t.text.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [t.accent, t.arrows[0]], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * engine.progress)
                    .animation(.spring(response: 0.4), value: engine.progress)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
    }

    private func bottomBar(_ t: GameTheme) -> some View {
        HStack(spacing: 14) {
            if engine.mode == .blink {
                ToolButton(icon: "eye.fill", label: "Peek", count: "\(engine.peeksLeft)", theme: t) {
                    engine.peek()
                }
                .opacity(engine.hidden && engine.peeksLeft > 0 ? 1 : 0.45)
            } else {
                ToolButton(icon: "arrow.uturn.backward", label: "Undo", count: "\(engine.undosLeft)", theme: t) {
                    engine.undo()
                }
            }
            ToolButton(icon: "lightbulb.fill", label: "Hint",
                       count: engine.mode == .zen || engine.mode == .custom ? "∞" : "\(store.hints)", theme: t) {
                useHint()
            }
            ToolButton(icon: "slider.horizontal.3", label: "View", count: nil, theme: t) {
                showDisplay = true
            }
            ToolButton(icon: "info.circle.fill", label: "Help", count: nil, theme: t) {
                showHow = true
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func useHint() {
        if engine.mode == .zen || engine.mode == .custom {
            engine.hint()
        } else if store.hints > 0 {
            if engine.hint() { store.hints -= 1 }
        } else {
            noHintsAlert = true
        }
    }

    private func nextLevel() {
        engine.goTo(level: engine.level + 1)
        checkFeatureIntro()
    }

    private func checkFeatureIntro() {
        guard engine.mode == .journey else { return }
        if let f = Feature.allCases.first(where: {
            $0.unlockLevel == engine.level && engine.style.supports($0) && !store.seenFeatures.contains($0.rawValue)
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) { featureIntro = f }
            }
        }
    }

    private var tip: String {
        if engine.mode == .blink {
            if engine.memorizeLeft > 0 { return "Memorise the arrows! Tap one when you're ready" }
            return engine.hidden ? "Directions hidden · Peek if you forget" : "Peeking…"
        }
        return engine.style == .tiles ? "Tip: hold an arrow to preview its path"
                                      : "Pinch to zoom · drag to pan · hold to preview"
    }

    /// Wordle-style result to paste in a chat: stars, hearts and every tap as an emoji grid.
    private var shareText: String {
        var lines = ["Arrow Puzzle Max 🎯"]
        let styleName = engine.style.title
        switch engine.state {
        case .won(let stars):
            lines.append("\(title) · \(styleName)")
            lines.append(String(repeating: "⭐", count: stars) + String(repeating: "☆", count: 3 - stars)
                         + "  " + String(repeating: "❤️", count: engine.hearts)
                         + String(repeating: "🖤", count: engine.maxHearts - engine.hearts))
            lines.append("Score \(engine.score) · 🔥×\(engine.bestCombo) · \(engine.moves.count) taps")
            let perRow = 8, maxRows = 4
            let rows = stride(from: 0, to: engine.moves.count, by: perRow).map {
                engine.moves[$0..<min($0 + perRow, engine.moves.count)].joined()
            }
            lines.append(contentsOf: rows.prefix(maxRows))
            if rows.count > maxRows { lines.append("…+\(engine.moves.count - perRow * maxRows) more") }
        default:
            let modeName = engine.mode.title
            lines.append("\(modeName) · \(styleName)")
            lines.append("\(engine.round) board\(engine.round == 1 ? "" : "s") cleared · Score \(engine.score) · 🔥×\(engine.bestCombo)")
            if engine.mode == .blink { lines.append("👁️ Can you remember more arrows than me?") }
        }
        lines.append("#ArrowPuzzleMax")
        return lines.joined(separator: "\n")
    }

    /// " · Cat 🐱" for shaped Maze boards.
    private var shapeSuffix: String {
        guard engine.style == .maze, engine.shape != .square else { return "" }
        return " · " + "\(engine.shape.title) \(engine.shape.emoji)".trimmingCharacters(in: .whitespaces)
    }

    private func record(_ s: PlayState) {
        if s == .playing { coinsEarned = 0 }
        switch (s, engine.mode) {
        case (.won(let stars), .journey):
            coinsEarned = store.complete(style: engine.style, level: engine.level, stars: stars)
            store.track(.wins, 1)
            if stars == 3 { store.track(.perfect, 1) }
        case (.won(let stars), .daily):
            coinsEarned = store.recordDaily()
            store.track(.wins, 1)
            store.track(.daily, 1)
            if stars == 3 { store.track(.perfect, 1) }
        case (.lost, .rush):
            store.bestRush = max(store.bestRush, engine.score)
            coinsEarned = store.rewardRun(boards: engine.round, perBoard: 5)
            store.track(.rush, engine.round)
        case (.lost, .blink):
            store.bestBlink = max(store.bestBlink, engine.score)
            coinsEarned = store.rewardRun(boards: engine.round, perBoard: 6)
        default:
            break
        }
    }
}

// MARK: - Result overlay

struct ResultOverlay: View {
    @ObservedObject var engine: GameEngine
    let theme: GameTheme
    let best: Int
    let coins: Int
    var shareText = ""
    let onNext: () -> Void
    let onRetry: () -> Void
    let onHome: () -> Void

    @State private var shownStars = 0

    private var stars: Int {
        if case .won(let s) = engine.state { return s }
        return 0
    }

    private var won: Bool { stars > 0 }

    private var headline: String {
        switch (won, engine.mode) {
        case (true, .daily): return "Daily Cleared!"
        case (true, _): return ["", "Nice!", "Great!", "Perfect!"][stars]
        case (false, .rush): return "Time's Up!"
        case (false, .zen): return "Nice Run"
        default: return "Out of Hearts"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(headline)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if won {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: i == 1 ? 54 : 42))
                                .foregroundStyle(i < shownStars ? Color.yellow : Color.white.opacity(0.2))
                                .scaleEffect(i < shownStars ? 1 : 0.7)
                                .offset(y: i == 1 ? -8 : 0)
                        }
                    }
                } else if engine.mode == .rush || engine.mode == .blink {
                    Text("\(engine.round) board\(engine.round == 1 ? "" : "s") cleared")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color(hex: 0xFF4D6D))
                }

                VStack(spacing: 4) {
                    Text("SCORE").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.6))
                    Text("\(engine.score)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 16) {
                        Label("Best combo ×\(engine.bestCombo)", systemImage: "flame.fill")
                        if engine.mode == .rush || engine.mode == .blink {
                            Label("Best \(max(best, engine.score))", systemImage: "trophy.fill")
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                }

                if coins > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill").foregroundStyle(Color(hex: 0xFFC300))
                        Text("+\(coins) coins")
                    }
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: 0xFFC300, opacity: 0.2)))
                    .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 10) {
                    if won && engine.mode == .journey && engine.level < GameStyle.maxLevel {
                        BigButton(title: "Next Level", icon: "arrow.right", color: theme.accent, ink: .black, action: onNext)
                    }
                    if !won || engine.mode == .journey || engine.mode == .custom {
                        BigButton(title: won ? "Replay" : "Try Again", icon: "arrow.clockwise",
                                  color: .white.opacity(0.2), action: onRetry)
                    }
                    HStack(spacing: 10) {
                        BigButton(title: engine.mode == .custom ? "Creator" : "Home",
                                  icon: engine.mode == .custom ? "hammer.fill" : "house.fill",
                                  color: .white.opacity(0.12), action: onHome)
                        if !shareText.isEmpty && (won || engine.round > 0) {
                            ShareLink(item: shareText) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(.headline, design: .rounded).weight(.heavy))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.white.opacity(0.12)))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 460)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(LinearGradient(colors: theme.background, startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1))
            )
            .padding(28)
        }
        .onAppear(perform: animateStars)
        .onChangeCompat(of: engine.state) { _, _ in animateStars() }
    }

    private func animateStars() {
        shownStars = 0
        for i in 0..<stars {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.25) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shownStars = i + 1 }
                Haptics.light()
            }
        }
    }
}

// MARK: - Feature intro

struct FeatureIntroCard: View {
    let feature: Feature
    let theme: GameTheme
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onDone)
            VStack(spacing: 16) {
                Text("NEW ARROW")
                    .font(.caption.weight(.black))
                    .tracking(2)
                    .foregroundStyle(theme.accent)
                FeatureSample(feature: feature, theme: theme)
                    .frame(width: 84, height: 84)
                Text(feature.title)
                    .font(.system(.title, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text(feature.detail)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                BigButton(title: "Got it!", icon: "checkmark", color: theme.accent, ink: .black, action: onDone)
            }
            .padding(26)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: theme.background, startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.15))))
            .padding(32)
        }
    }
}

/// A static arrow tile showing what a special arrow looks like.
struct FeatureSample: View {
    let feature: Feature
    let theme: GameTheme

    var body: some View {
        GeometryReader { geo in
            ArrowPiece(arrow: Arrow(id: -1, pos: Pos(r: 0, c: 0), dir: .right, kind: kind),
                       theme: theme, locked: false, isHint: false,
                       cell: geo.size.width / 0.8, onTap: {}, onPreview: { _ in })
                .frame(width: geo.size.width, height: geo.size.height)
                .allowsHitTesting(false)
        }
    }

    private var kind: ArrowKind {
        switch feature {
        case .twin: return .twin
        case .ghost: return .ghost
        case .bomb: return .bomb
        case .keyLock: return .key
        }
    }
}

// MARK: - Buttons

struct CircleButton: View {
    let icon: String
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(theme.text.opacity(0.1)))
        }
        .buttonStyle(PressableStyle())
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    let count: String?
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold))
                Text(label).font(.caption.weight(.bold))
            }
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.text.opacity(0.09)))
            .overlay(alignment: .topTrailing) {
                if let count {
                    Text(count)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.accent))
                        .offset(x: -6, y: -6)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct BigButton: View {
    let title: String
    let icon: String
    let color: Color
    var ink: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
        }
        .buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
