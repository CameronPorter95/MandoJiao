import CoreDomain
import MatchingDomain
import SpeakingDomain
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.Key.speechStrictness) private var strictnessRaw = AnswerStrictness.default.rawValue
    @AppStorage(Preferences.Key.showsPinyin) private var showsPinyin = false
    @AppStorage(Preferences.Key.matchingRounds) private var matchingRounds = MatchingSettings.defaultRounds
    @AppStorage(Preferences.Key.speakingCardLimit) private var speakingCardLimit = SpeakingSettings.defaultCardLimit

    private var strictness: AnswerStrictness {
        AnswerStrictness(rawValue: strictnessRaw) ?? .default
    }

    var body: some View {
        List {
            Section {
                Picker("Strictness", selection: $strictnessRaw) {
                    ForEach(AnswerStrictness.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(strictness.detail)
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
                Toggle("Show pinyin", isOn: $showsPinyin)
            } footer: {
                Text("Shows pinyin under every Hanzi tile. The button in a lesson changes this too.")
            }

            Section {
                Stepper(
                    "Matching rounds: \(matchingRounds)",
                    value: $matchingRounds,
                    in: Preferences.matchingRoundsRange
                )
                Stepper(
                    "Drill card limit: \(speakingCardLimit)",
                    value: $speakingCardLimit,
                    in: Preferences.speakingCardLimitRange
                )
            } header: {
                Text("Lesson length")
            } footer: {
                Text("A matching lesson is this many rounds of \(MatchingPlanBuilder.pairsPerExercise) pairs. A mistakes drill is one card per word, stopping at the limit when the list is longer.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
