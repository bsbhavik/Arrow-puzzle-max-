import SwiftUI

// MARK: - Level select

struct LevelSelectView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @Binding var path: [Route]

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 5 per row on iPhone, 10 on iPad: both divide a 100-level chapter evenly.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 10 : 5)
    }

    var body: some View {
        let t = store.theme
        let style = store.style
        let maxLevel = GameStyle.maxLevel
        ZStack {
            ThemeBackground(theme: t, animated: false)
            VStack(spacing: 12) {
                HStack {
                    CircleButton(icon: "chevron.left", theme: t) { dismiss() }
                    Spacer()
                    Text("Journey · \(style.title)")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(t.text)
                    Spacer()
                    StatChip(icon: "star.fill", value: "\(store.totalStars(style))", tint: .yellow, theme: t)
                }
                .padding(.horizontal)

                ScrollViewReader { proxy in
                    // 100 chapters is a long scroll, so jump straight to one.
                    Menu {
                        Button("Current level (\(store.unlocked(style)))") {
                            withAnimation { proxy.scrollTo(store.unlocked(style), anchor: .center) }
                        }
                        ForEach(0..<(maxLevel / 1000), id: \.self) { k in
                            Menu("Levels \(k * 1000 + 1)–\((k + 1) * 1000)") {
                                ForEach(0..<10, id: \.self) { c in
                                    let ch = k * 10 + c
                                    Button("Chapter \(ch + 1) · \(ch * 100 + 1)–\(ch * 100 + 100)") {
                                        proxy.scrollTo(ch * 100 + 1, anchor: .top)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Jump to chapter", systemImage: "list.number")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(t.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(t.text.opacity(0.1)))
                    }

                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 12, pinnedViews: [.sectionHeaders]) {
                            ForEach(0..<(maxLevel / 100), id: \.self) { chapter in
                                Section {
                                    ForEach((chapter * 100 + 1)...(chapter * 100 + 100), id: \.self) { n in
                                        levelCell(n, t)
                                            .id(n)
                                    }
                                } header: {
                                    chapterHeader(chapter, t)
                                }
                            }
                        }
                        .padding()
                        .readableWidth(900)
                    }
                    .onAppear { proxy.scrollTo(store.unlocked(style), anchor: .center) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func chapterHeader(_ chapter: Int, _ t: GameTheme) -> some View {
        let style = store.style
        let first = chapter * 100 + 1, last = chapter * 100 + 100
        let earned = (first...last).reduce(0) { $0 + store.stars(style, level: $1) }
        return HStack {
            Text("Chapter \(chapter + 1)")
                .font(.system(.headline, design: .rounded).weight(.black))
            Text("\(first)–\(last)")
                .font(.caption.weight(.bold))
                .opacity(0.6)
            Spacer()
            Label("\(earned)/300", systemImage: "star.fill")
                .font(.caption.weight(.heavy))
        }
        .foregroundStyle(t.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
    }

    @ViewBuilder
    private func levelCell(_ n: Int, _ t: GameTheme) -> some View {
        let style = store.style
        let open = n <= store.unlocked(style)
        let s = store.stars(style, level: n)
        let newFeature = Feature.allCases.first { $0.unlockLevel == n && style.supports($0) }
        let boss = LevelConfig.isBoss(n)
        let gold = Color(hex: 0xFFC300)
        Button {
            if open { path.append(.play(.journey, n, style)) }
        } label: {
            VStack(spacing: 3) {
                if open {
                    Text("\(n)")
                        .font(.system(.title3, design: .rounded).weight(.black))
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(i < s ? Color.yellow : Color.white.opacity(0.3))
                        }
                    }
                } else {
                    Image(systemName: boss ? "crown.fill" : "lock.fill").font(.headline)
                        .foregroundStyle(boss ? gold.opacity(0.7) : t.subtext)
                }
            }
            .foregroundStyle(open ? Color.white : t.subtext)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(open ? AnyShapeStyle(LinearGradient(colors: [t.arrows[n % 4], t.arrows[(n + 1) % 4]],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                               : AnyShapeStyle(t.text.opacity(0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(n == store.unlocked(style) ? t.accent : (boss ? gold : .clear), lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if boss && open {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: 0x5A3A00))
                        .padding(4)
                        .background(Circle().fill(gold))
                        .offset(x: 4, y: -4)
                } else if let f = newFeature {
                    Image(systemName: f.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(4)
                        .background(Circle().fill(t.accent))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!open)
    }
}

// MARK: - How to play

struct HowToPlayView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let t = store.theme
        NavigationStack {
            ZStack {
                ThemeBackground(theme: t, animated: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section("Goal", t) {
                            rule("hand.tap.fill", "Tap an arrow to slide it the way it points. If nothing is in the way, it escapes the board.", t)
                            rule("heart.slash.fill", "If another arrow or a stone is in the way it bounces back and you lose a heart.", t)
                            rule("hand.point.up.left.fill", "Hold an arrow to preview its path: green means clear, red shows what's blocking it.", t)
                            rule("flame.fill", "Clear arrows quickly one after another to build a combo, up to ×8 points.", t)
                            rule("checkmark.seal.fill", "Every board can be solved. You can't get stuck, so take your time.", t)
                        }

                        section("Three styles", t) {
                            rule("square.grid.3x3.fill", "Tiles: every arrow is one square. Bigger boards and twin arrows come later.", t)
                            rule("scribble.variable", "Ribbons: long bending arrows on a big grid. Tap anywhere on a ribbon and its whole body follows the head out, round every bend. Only the head's straight path needs to be clear.", t)
                            rule("squareshape.split.3x3", "Maze: huge boards in shapes (heart, flower, ring…) packed with thin line arrows. Pinch to zoom, drag to pan, and change dots/grid and line colours with the View button.", t)
                            rule("arrow.left.arrow.right", "Switch style on the home screen. Each style has its own Journey progress.", t)
                        }

                        section("Special arrows", t) {
                            ForEach(Feature.allCases) { f in
                                HStack(alignment: .top, spacing: 14) {
                                    FeatureSample(feature: f, theme: t).frame(width: 44, height: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.title).font(.headline).foregroundStyle(t.text)
                                        Text(f.detail + " Unlocks at level \(f.unlockLevel).")
                                            .font(.subheadline).foregroundStyle(t.subtext)
                                    }
                                }
                            }
                            HStack(alignment: .top, spacing: 14) {
                                StoneView(theme: t, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Stone Block").font(.headline).foregroundStyle(t.text)
                                    Text("Never moves. Blocks every arrow, ghosts included. Only bombs break it.")
                                        .font(.subheadline).foregroundStyle(t.subtext)
                                }
                            }
                        }

                        section("Modes", t) {
                            rule("map.fill", "Journey: 10,000 levels in every style, with 1–3 stars. 3 stars earns a hint.", t)
                            rule("crown.fill", "Boss levels: every 25th level is a bigger, trickier Boss board that pays double coins.", t)
                            rule("calendar", "Daily: the same board for everyone today. Keep your streak alive.", t)
                            rule("eye.slash.fill", "Blink: you get a few seconds to memorise the board, then the arrow directions hide. Tap one when you're ready to start early. 2 peeks per board, and a perfect board gives a heart back.", t)
                            rule("circle.dashed.inset.filled", "Lucky Spin: one free spin a day for coins or hints.", t)
                            rule("checklist", "Daily Quests: 3 new goals every day. Claim all three to open the quest chest.", t)
                            rule("square.and.arrow.up", "Share: after a win, share your result as an emoji grid of every tap you made.", t)
                            rule("bolt.fill", "Time Rush: 60 seconds. Each cleared board adds time, each mistake costs 5s.", t)
                            rule("leaf.fill", "Zen: no hearts, no timer, unlimited hints.", t)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func section<Content: View>(_ title: String, _ t: GameTheme, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .tracking(1.5)
                .foregroundStyle(t.accent)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(t.text.opacity(0.08)))
    }

    private func rule(_ icon: String, _ text: String, _ t: GameTheme) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(t.accent)
                .frame(width: 24)
            Text(text).foregroundStyle(t.text)
        }
        .font(.subheadline)
    }
}

// MARK: - Theme shop

struct ThemePickerView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var notEnough: GameTheme?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill").foregroundStyle(Color(hex: 0xFFC300))
                        Text("\(store.coinText) coins")
                            .contentTransition(.numericText())
                        Spacer()
                        Text("Win levels to earn more")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .padding(.horizontal, 4)

                    #if DEBUG
                    // Test builds only: unlock every theme without earning coins.
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $store.unlimitedCoins.animation()) {
                            Label("Test mode: unlimited coins", systemImage: "infinity")
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        }
                        .tint(.orange)
                        HStack {
                            Button("Lock paid themes again") {
                                store.ownedThemes = Set(GameTheme.all.filter { $0.price == 0 }.map(\.id))
                                if !store.ownedThemes.contains(store.themeID) { store.themeID = GameTheme.neon.id }
                            }
                            Spacer()
                            Button("+1,000 coins") { store.coins += 1000 }
                        }
                        .font(.caption.weight(.bold))
                        Text("Only in Debug builds. Hidden in the App Store version.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    #endif

                    ForEach(GameTheme.all) { theme in
                        themeRow(theme)
                    }
                }
                .padding()
            }
            .navigationTitle("Theme Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("Not enough coins", isPresented: Binding(get: { notEnough != nil }, set: { if !$0 { notEnough = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let t = notEnough {
                    Text("\(t.name) costs \(t.price) coins. You need \(t.price - store.coins) more. Pass levels to earn coins!")
                }
            }
        }
        .presentationDetents([.large])
    }

    private func themeRow(_ theme: GameTheme) -> some View {
        let owned = store.owns(theme)
        let selected = store.themeID == theme.id
        return Button {
            if owned {
                withAnimation { store.themeID = theme.id }
                Haptics.light()
            } else if store.buy(theme) {
                Haptics.success()
            } else {
                notEnough = theme
                Haptics.error()
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(theme.name)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(theme.text)
                    if selected {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.accent)
                    } else if owned {
                        Text("Tap to use")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.subtext)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Image(systemName: "dollarsign.circle.fill").foregroundStyle(Color(hex: 0xFFC300))
                            Text("\(theme.price)")
                        }
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(theme.text.opacity(0.15)))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach(Direction.allCases, id: \.self) { d in
                            SkinTileView(dir: d, theme: theme, size: 28)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(theme.skin.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.subtext)
                        SkinRibbonSample(theme: theme, cell: 9)
                    }
                }
                .opacity(owned ? 1 : 0.6)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: theme.background, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selected ? theme.accent : Color.primary.opacity(0.08), lineWidth: selected ? 3 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}
