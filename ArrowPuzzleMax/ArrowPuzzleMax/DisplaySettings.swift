import SwiftUI

/// Board look options: background, line colours and animation speed.
struct DisplaySettingsView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Background", selection: $store.backgroundID) {
                        ForEach(BoardBackground.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Background")
                } footer: {
                    Text("Used by Ribbons and Maze.")
                }

                Section("Line colour") {
                    Picker("Line colour", selection: $store.lineModeID) {
                        ForEach(LineColorMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Animation speed") {
                    Picker("Animation", selection: $store.animSpeedID) {
                        ForEach(AnimSpeed.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Haptics", isOn: $store.haptics)
                }
            }
            .navigationTitle("View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
