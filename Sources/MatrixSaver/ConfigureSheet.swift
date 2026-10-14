import SwiftUI

/// Options sheet shown from System Settings. "Done" saves and dismisses.
struct ConfigureSheet: View {
    @State private var settings: SaverSettings
    private let onDone: () -> Void

    init(initial: SaverSettings, onDone: @escaping () -> Void) {
        _settings = State(initialValue: initial)
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Picker("Palette", selection: $settings.palette) {
                    ForEach(SaverSettings.Palette.allCases, id: \.self) { palette in
                        Text(palette.displayName).tag(palette)
                    }
                }
                slider("Speed", value: $settings.speed, in: SaverSettings.speedRange,
                       label: String(format: "%.2f×", settings.speed))
                slider("Density", value: $settings.density, in: SaverSettings.densityRange,
                       label: String(format: "%.0f%%", settings.density * 100))
                slider("Glyph size", value: $settings.glyphSize, in: SaverSettings.glyphSizeRange, step: 1,
                       label: String(format: "%.0f pt", settings.glyphSize))
                Toggle("Glow", isOn: $settings.glow)
            }
            HStack {
                Button("Reset to Defaults") { settings = .defaults }
                Spacer()
                Button("Done") {
                    settings.save()
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    @ViewBuilder
    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
                        step: Double? = nil, label: String) -> some View {
        LabeledContent(title) {
            HStack {
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
                Text(label)
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}
