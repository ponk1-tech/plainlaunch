import SwiftUI

struct CustomizeView: View {
    @State private var configuration: WidgetDisplayConfiguration = WidgetSettingsStore.shared.load()
    @State private var renamingTarget: LaunchTarget?

    private let store = WidgetSettingsStore.shared

    var body: some View {
        NavigationView {
            List {
                Section {
                    WidgetRowsView(configuration: configuration) { $0.localizedDefaultName }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.black)
                }

                Section(String(localized: "customize.items")) {
                    ForEach(configuration.items) { item in
                        itemRow(item)
                    }
                    .onMove { configuration.items.move(fromOffsets: $0, toOffset: $1) }
                }
                .listRowBackground(Color.black)

                Section(String(localized: "customize.layout")) {
                    Picker(String(localized: "customize.alignment"), selection: $configuration.alignment) {
                        Text("customize.alignment.leading").tag(TextAlignmentOption.leading)
                        Text("customize.alignment.center").tag(TextAlignmentOption.center)
                        Text("customize.alignment.trailing").tag(TextAlignmentOption.trailing)
                    }
                    .pickerStyle(.segmented)

                    Picker(String(localized: "customize.weight"), selection: $configuration.fontWeight) {
                        Text("customize.weight.regular").tag(FontWeightOption.regular)
                        Text("customize.weight.medium").tag(FontWeightOption.medium)
                        Text("customize.weight.semibold").tag(FontWeightOption.semibold)
                        Text("customize.weight.bold").tag(FontWeightOption.bold)
                    }
                    .pickerStyle(.segmented)

                    sliderRow(titleKey: "customize.fontSize", value: $configuration.fontSize, range: 18...40)
                    sliderRow(titleKey: "customize.lineSpacing", value: $configuration.lineSpacing, range: 2...24)
                }
                .listRowBackground(Color(white: 0.08))

                Section(String(localized: "customize.colors")) {
                    ColorPicker(String(localized: "customize.textColor"), selection: colorBinding(\.textColorHex), supportsOpacity: false)
                    ColorPicker(String(localized: "customize.backgroundColor"), selection: colorBinding(\.backgroundColorHex), supportsOpacity: false)
                }
                .listRowBackground(Color(white: 0.08))

                Section {
                    Button(role: .destructive) {
                        configuration = .default
                    } label: {
                        Text("customize.reset")
                    }
                }
                .listRowBackground(Color(white: 0.08))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "tab.customize"))
            .toolbar { EditButton() }
            .sheet(item: $renamingTarget) { target in
                RenameSheet(target: target, configuration: $configuration)
            }
            .onChange(of: configuration) { newValue in
                store.save(newValue)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func itemRow(_ item: WidgetItemSettings) -> some View {
        HStack {
            Toggle(isOn: bindingForEnabled(item.target)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.customName?.isEmpty == false ? item.customName! : item.target.localizedDefaultName)
                        .foregroundColor(.white)
                    if item.customName?.isEmpty == false {
                        Text(item.target.localizedDefaultName)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .white))
            Button {
                renamingTarget = item.target
            } label: {
                Image(systemName: "pencil")
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    private func sliderRow(titleKey: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey(titleKey)).foregroundColor(.white.opacity(0.85))
            Slider(value: value, in: range)
        }
    }

    private func bindingForEnabled(_ target: LaunchTarget) -> Binding<Bool> {
        Binding(
            get: { configuration.items.first(where: { $0.target == target })?.isEnabled ?? true },
            set: { newValue in
                guard let index = configuration.items.firstIndex(where: { $0.target == target }) else { return }
                configuration.items[index].isEnabled = newValue
            }
        )
    }

    private func colorBinding(_ keyPath: WritableKeyPath<WidgetDisplayConfiguration, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: configuration[keyPath: keyPath]) },
            set: { configuration[keyPath: keyPath] = $0.toHex() }
        )
    }
}

private struct RenameSheet: View {
    let target: LaunchTarget
    @Binding var configuration: WidgetDisplayConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationView {
            Form {
                TextField(target.localizedDefaultName, text: $text)
            }
            .navigationTitle(target.localizedDefaultName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        if let index = configuration.items.firstIndex(where: { $0.target == target }) {
                            configuration.items[index].customName = text.trimmingCharacters(in: .whitespaces)
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            text = configuration.items.first(where: { $0.target == target })?.customName ?? ""
        }
    }
}
