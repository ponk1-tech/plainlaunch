import SwiftUI

struct WidgetGuideView: View {
    private let stepKeys = [
        "guide.step1", "guide.step2", "guide.step3", "guide.step4", "guide.step5",
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("guide.title")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("guide.subtitle")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(stepKeys.enumerated()), id: \.offset) { index, key in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.white))
                                Text(LocalizedStringKey(key))
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.2))

                    Text("guide.shortcutsTitle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("guide.shortcutsBody")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "tab.widget"))
        }
        .navigationViewStyle(.stack)
    }
}
