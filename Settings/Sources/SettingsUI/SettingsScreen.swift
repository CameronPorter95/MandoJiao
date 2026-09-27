import CoreDesignSystem
import MatchingDomain
import SpeakingDomain
import SwiftUI

struct SettingsScreen: View {
    let state: SettingsState
    let onAction: (SettingsAction) -> Void

    var body: some View {
        List {
            Section {
                Picker(
                    "Strictness",
                    selection: Binding(get: { state.strictness }, set: { onAction(.strictnessChanged($0)) })
                ) {
                    ForEach(AnswerStrictness.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Text(state.strictness.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Speaking")
            } footer: {
                // Worth saying plainly, because it is the setting people expect to find
                // here and it is already on.
                Text("Tones are never graded, at any setting. A recogniser's idea of which tone you used is its own guess as much as yours, so failing you on it would be unfair and impossible to argue with.")
            }

            Section {
                Toggle(
                    "Show pinyin",
                    isOn: Binding(get: { state.showsPinyin }, set: { onAction(.showsPinyinChanged($0)) })
                )
            } footer: {
                Text("Shows pinyin under every Hanzi tile. The button in a lesson changes this too.")
            }

            Section {
                Stepper(
                    "Matching rounds: \(state.matchingRounds)",
                    value: Binding(get: { state.matchingRounds }, set: { onAction(.matchingRoundsChanged($0)) }),
                    in: MatchingSettings.roundsRange
                )
                Stepper(
                    "Drill card limit: \(state.speakingCardLimit)",
                    value: Binding(get: { state.speakingCardLimit }, set: { onAction(.speakingCardLimitChanged($0)) }),
                    in: SpeakingSettings.cardLimitRange
                )
            } header: {
                Text("Lesson length")
            } footer: {
                Text("A matching lesson is this many rounds of \(MatchingPlanBuilder.pairsPerExercise) pairs. A mistakes drill is one card per word, stopping at the limit when the list is longer.")
            }

            Section {
                Link("CC-CEDICT", destination: URL(string: "https://cc-cedict.org/wiki/")!)
                Link("CC BY-SA 4.0 licence", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
            } header: {
                Text("Acknowledgements")
            } footer: {
                Text("Suggested pinyin and English come from CC-CEDICT, shortened to one sense per word.")
            }
        }
        .navigationTitle("Settings")
        .inlineNavigationTitle()
    }
}

#Preview {
    NavigationStack {
        SettingsScreen(state: SettingsState(), onAction: { _ in })
    }
}
