import SwiftUI

enum Route: Hashable {
    case levels
    case play(GameMode, Int, GameStyle)
    case creator
    case editor(CustomLevel)
    case playCustom(CustomLevel)
}

struct RootView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .levels:
                        LevelSelectView(path: $path)
                    case .play(let mode, let level, let style):
                        GameView(mode: mode, level: level, style: style)
                    case .creator:
                        MyLevelsView(path: $path)
                    case .editor(let level):
                        LevelEditorView(level: level, path: $path)
                    case .playCustom(let level):
                        GameView(custom: level)
                    }
                }
        }
        .tint(store.theme.accent)
        .preferredColorScheme(store.theme.dark ? .dark : .light)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: ProgressStore
    @Binding var path: [Route]
    @State private var showHow = false
    @State private var showThemes = false
    @State private var showSpin = false
    @State private var showQuests = false
    @State private var bounce = false

    var body: some View {
        let t = store.theme
        ZStack {
            ThemeBackground(theme: t)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    logo(t)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                    statsRow(t)

                    StylePicker(theme: t)

                    ModeCard(icon: GameMode.journey.icon, title: "Journey",
                             subtitle: "\(store.style.title) · Level \(store.unlocked(store.style)) · new arrow types unlock as you go",
                             colors: [t.arrows[0], t.arrows[3]], tall: true) {
                        path.append(.levels)
                    }

                    ModeCard(icon: GameMode.daily.icon, title: "Daily Challenge",
                             subtitle: store.dailyDone
                                ? "Done today ✓ · streak \(store.dailyStreak)🔥"
                                : "One hand-picked board a day · +2 hints",
                             colors: [t.arrows[1], t.arrows[2]], tall: false) {
                        path.append(.play(.daily, 0, store.style))
                    }

                    HStack(spacing: 14) {
                        ModeCard(icon: GameMode.rush.icon, title: "Time Rush",
                                 subtitle: "60s · Best \(store.bestRush)",
                                 colors: [t.arrows[2], t.arrows[0]], tall: false) {
                            path.append(.play(.rush, 0, store.style))
                        }
                        ModeCard(icon: GameMode.zen.icon, title: "Zen",
                                 subtitle: "Relax · Best \(store.bestZen)",
                                 colors: [t.arrows[3], t.arrows[1]], tall: false) {
                            path.append(.play(.zen, 0, store.style))
                        }
                    }

                    ModeCard(icon: GameMode.blink.icon, title: "Blink  ·  NEW",
                             subtitle: "Memorise the arrows, then they hide. How far can your memory go? · Best \(store.bestBlink)",
                             colors: [t.arrows[3], t.accent.opacity(0.85)], tall: false) {
                        path.append(.play(.blink, 0, store.style))
                    }

                    HStack(spacing: 14) {
                        ModeCard(icon: "circle.dashed.inset.filled", title: "Lucky Spin",
                                 subtitle: store.canSpin ? "Free spin ready! 🎁" : "Next spin tomorrow",
                                 colors: [Color(hex: 0xFFB000), Color(hex: 0xFF6B00)], tall: false) {
                            showSpin = true
                        }
                        .overlay(alignment: .topTrailing) { if store.canSpin { badge("1") } }
                        ModeCard(icon: "checklist", title: "Quests",
                                 subtitle: "\(store.questsDone)/3 done today",
                                 colors: [t.arrows[1], t.arrows[0]], tall: false) {
                            showQuests = true
                        }
                        .overlay(alignment: .topTrailing) {
                            if store.questsToClaim > 0 { badge("\(store.questsToClaim)") }
                        }
                    }

                    ModeCard(icon: "hammer.fill", title: "Level Creator",
                             subtitle: store.customLevels.isEmpty
                                ? "Build, test & share your own levels"
                                : "\(store.customLevels.count) of your levels · build, test & share",
                             colors: [t.accent.opacity(0.9), t.arrows[1]], tall: false) {
                        path.append(.creator)
                    }

                    HStack(spacing: 12) {
                        PillButton(icon: "questionmark.circle.fill", title: "How to Play", theme: t) { showHow = true }
                        PillButton(icon: "paintpalette.fill", title: "Theme Shop", theme: t) { showThemes = true }
                        PillButton(icon: store.haptics ? "iphone.radiowaves.left.and.right" : "iphone.slash",
                                   title: "Haptics", theme: t) { store.haptics.toggle() }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .readableWidth(640)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showHow) { HowToPlayView().environmentObject(store) }
        .sheet(isPresented: $showThemes) { ThemePickerView().environmentObject(store) }
        .fullScreenCover(isPresented: $showSpin) { LuckySpinView().environmentObject(store) }
        .sheet(isPresented: $showQuests) { QuestsView().environmentObject(store) }
        .onAppear {
            store.rolloverQuests()
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounce = true }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(.white)
            .frame(minWidth: 22, minHeight: 22)
            .background(Circle().fill(Color.red))
            .offset(x: 4, y: -6)
            .transition(.scale)
    }

    private func logo(_ t: GameTheme) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Direction.allCases, id: \.self) { d in
                    SkinTileView(dir: d, theme: t, size: 46)
                        .shadow(color: t.arrows[d.rawValue].opacity(0.6), radius: 8, y: 4)
                        .offset(x: bounce ? CGFloat(d.dc) * 4 : 0,
                                y: bounce ? CGFloat(d.dr) * 4 : 0)
                }
            }
            Text("ARROW PUZZLE")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(t.text)
            Text("MAX")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [t.accent, t.arrows[0]],
                                                startPoint: .leading, endPoint: .trailing))
                .shadow(color: t.accent.opacity(0.5), radius: 12)
                .padding(.top, -14)
        }
    }

    private func statsRow(_ t: GameTheme) -> some View {
        HStack(spacing: 8) {
            StatChip(icon: "dollarsign.circle.fill", value: store.coinText, tint: Color(hex: 0xFFC300), theme: t)
                .contentTransition(.numericText())
            StatChip(icon: "star.fill", value: "\(store.totalStars)", tint: .yellow, theme: t)
            StatChip(icon: "lightbulb.fill", value: "\(store.hints)", tint: t.accent, theme: t)
            StatChip(icon: "flame.fill", value: "\(store.dailyStreak)", tint: .orange, theme: t)
        }
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]
    let tall: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: tall ? 14 : 10) {
                Image(systemName: icon)
                    .font(.system(size: tall ? 30 : 22, weight: .bold))
                    .frame(width: tall ? 58 : 38, height: tall ? 58 : 38)
                    .background(Circle().fill(.white.opacity(0.22)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(tall ? .title2 : .headline, design: .rounded).weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if tall {
                    Image(systemName: "play.fill").font(.title3.weight(.black))
                }
            }
            .foregroundStyle(.white)
            .padding(tall ? 20 : 14)
            .frame(maxWidth: .infinity, minHeight: tall ? 104 : 78)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: colors[0].opacity(0.45), radius: 10, y: 6)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

struct StatChip: View {
    let icon: String
    let value: String
    let tint: Color
    let theme: GameTheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).foregroundStyle(theme.text)
        }
        .font(.system(.subheadline, design: .rounded).weight(.heavy))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(theme.text.opacity(0.1)))
    }
}

struct PillButton: View {
    let icon: String
    let title: String
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.bold))
            }
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.text.opacity(0.1)))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Choose the game style. Every mode (Journey, Daily, Rush, Zen) uses the chosen style.
struct StylePicker: View {
    @EnvironmentObject private var store: ProgressStore
    let theme: GameTheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(GameStyle.allCases) { style in
                let selected = store.style == style
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.style = style }
                    Haptics.light()
                } label: {
                    VStack(spacing: 6) {
                        StylePreview(style: style, theme: theme)
                            .frame(height: 40)
                        Text(style.title)
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                        Text(style.blurb)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .opacity(0.75)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(height: 28, alignment: .top)
                    }
                    .foregroundStyle(theme.text)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.text.opacity(selected ? 0.16 : 0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(selected ? theme.accent : .clear, lineWidth: 3))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(theme.accent)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// Tiny static drawing of each style for the picker.
struct StylePreview: View {
    let style: GameStyle
    let theme: GameTheme

    var body: some View {
        switch style {
        case .tiles:
            HStack(spacing: 4) {
                ForEach([Direction.right, .up, .left], id: \.self) { d in
                    SkinTileView(dir: d, theme: theme, size: 24)
                }
            }
        case .ribbons:
            ribbons([
                Arrow(id: 0, cells: [Pos(r: 2, c: 0), Pos(r: 1, c: 0), Pos(r: 1, c: 1), Pos(r: 1, c: 2), Pos(r: 0, c: 2)], dir: .up, kind: .normal),
                Arrow(id: 1, cells: [Pos(r: 0, c: 4), Pos(r: 1, c: 4), Pos(r: 2, c: 4), Pos(r: 2, c: 5), Pos(r: 2, c: 6)], dir: .right, kind: .normal),
            ], cell: 12, cols: 7, rows: 3, width: 4)
        case .maze:
            ribbons([
                Arrow(id: 0, cells: [Pos(r: 4, c: 0), Pos(r: 3, c: 0), Pos(r: 2, c: 0), Pos(r: 2, c: 1), Pos(r: 2, c: 2), Pos(r: 1, c: 2), Pos(r: 0, c: 2)], dir: .up, kind: .normal),
                Arrow(id: 1, cells: [Pos(r: 0, c: 0), Pos(r: 0, c: 1)], dir: .right, kind: .normal),
                Arrow(id: 2, cells: [Pos(r: 4, c: 4), Pos(r: 4, c: 3), Pos(r: 3, c: 3), Pos(r: 3, c: 2), Pos(r: 3, c: 1), Pos(r: 4, c: 1)], dir: .down, kind: .normal),
                Arrow(id: 3, cells: [Pos(r: 1, c: 3), Pos(r: 1, c: 4), Pos(r: 2, c: 4), Pos(r: 2, c: 5), Pos(r: 1, c: 5), Pos(r: 0, c: 5)], dir: .up, kind: .normal),
                Arrow(id: 4, cells: [Pos(r: 3, c: 5), Pos(r: 4, c: 5)], dir: .down, kind: .normal),
            ], cell: 8, cols: 6, rows: 5, width: 1.6)
        }
    }

    private func ribbons(_ list: [Arrow], cell: CGFloat, cols: Int, rows: Int, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(list) { r in
                let track = RibbonGeometry.track(for: r, boardSize: max(cols, rows))
                let len = RibbonGeometry.length(for: r)
                let color = style == .maze ? theme.text : theme.arrows[r.dir.rawValue]
                theme.skin.ribbonStroke(RibbonBody(track: track, start: 0, length: len, cell: cell),
                                        color: color, width: width, inner: theme.tubeInner,
                                        ghost: false, thin: style == .maze)
                RibbonHead(track: track, start: 0, length: len, cell: cell, dir: r.dir,
                           headScale: style == .maze ? 0.9 : 1, style: theme.skin.head)
                    .fill(color)
            }
        }
        .frame(width: cell * CGFloat(cols), height: cell * CGFloat(rows))
    }
}
