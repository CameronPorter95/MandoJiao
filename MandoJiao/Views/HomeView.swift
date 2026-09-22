import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabWord.createdAt) private var words: [VocabWord]
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    @State private var activeRequest: LessonRequest?
    @State private var newDeckName = ""
    @State private var isNamingDeck = false
    @State private var isConfirmingClear = false

    private var usableWords: [VocabWord] { words.filter(\.isUsable) }

    /// Words carrying outstanding mistakes, worst first.
    private var mistakeWords: [VocabWord] {
        usableWords
            .filter { $0.missCount > 0 }
            .sorted {
                ($0.missCount, $0.lastMissedAt ?? .distantPast)
                    > ($1.missCount, $1.lastMissedAt ?? .distantPast)
            }
    }

    var body: some View {
        List {
            Section {
                quickPracticeCard
            }

            if !mistakeWords.isEmpty {
                Section {
                    mistakesCard
                }
            }

            Section {
                if decks.isEmpty {
                    Text("No decks yet. Create one to practise a smaller set of words.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(decks) { deck in
                        NavigationLink(value: deck) {
                            deckRow(deck)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                start(title: deck.name, pool: deck.words.pairs)
                            } label: {
                                Label("Practise", systemImage: "play.fill")
                            }
                            .tint(Theme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(deck)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Decks")
            } footer: {
                Text("Swipe a deck right to practise it, or open it to choose its words.")
            }
        }
        .navigationTitle("MandoJiao")
        .navigationDestination(for: Deck.self) { deck in
            DeckDetailView(deck: deck) { request in
                activeRequest = request
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    WordLibraryView()
                } label: {
                    Label("Library", systemImage: "character.book.closed")
                }

                Button {
                    newDeckName = ""
                    isNamingDeck = true
                } label: {
                    Label("New deck", systemImage: "plus")
                }
            }
        }
        .alert("New deck", isPresented: $isNamingDeck) {
            TextField("Deck name", text: $newDeckName)
            Button("Create", action: createDeck)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give the deck a name, then pick its words.")
        }
        .confirmationDialog(
            "Clear the mistakes list?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                MistakeLog.clearAll(in: context)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(mistakeWords.count) words will be marked as learned.")
        }
        .fullScreenCover(item: $activeRequest) { request in
            LessonView(request: request) { activeRequest = nil }
        }
    }

    // MARK: - Pieces

    private var quickPracticeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick practice")
                    .font(.title3.bold())
                Text("\(LessonBuilder.exercisesPerLesson) rounds of \(LessonBuilder.pairsPerExercise) pairs, drawn at random from all \(usableWords.count) words.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                start(title: "All words", pool: usableWords.pairs)
            } label: {
                Text("Start lesson")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(usableWords.count < LessonBuilder.pairsPerExercise)

            if usableWords.count < LessonBuilder.pairsPerExercise {
                Text("Add at least \(LessonBuilder.pairsPerExercise) words to start a lesson.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var mistakesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mistakes")
                    .font(.title3.bold())
                Text(mistakesSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    start(title: "Mistakes", pool: mistakePool)
                } label: {
                    Text("Practise mistakes")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.miss)
                .disabled(mistakePool.count < LessonBuilder.pairsPerExercise)

                Button("Clear") { isConfirmingClear = true }
                    .font(.subheadline)
                    .tint(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var mistakesSubtitle: String {
        let count = mistakeWords.count
        let noun = count == 1 ? "word" : "words"
        if count < LessonBuilder.pairsPerExercise {
            // Too few to fill a board on their own, so the rest is made up from
            // the library and the mistakes are mixed through it.
            return "\(count) \(noun) to earn back, padded out with other words to fill each round."
        }
        return "\(count) \(noun) to earn back. Get one right in a lesson and it comes off the list."
    }

    /// The mistakes, topped up from the library when there are not enough of
    /// them to fill a board.
    private var mistakePool: [WordPair] {
        var pool = mistakeWords
        if pool.count < LessonBuilder.pairsPerExercise {
            let chosen = Set(pool.map(\.uuid))
            let filler = usableWords.filter { !chosen.contains($0.uuid) }.shuffled()
            pool += filler.prefix(LessonBuilder.pairsPerExercise - pool.count)
        }
        return pool.pairs
    }

    private func deckRow(_ deck: Deck) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(deck.name.isEmpty ? "Untitled deck" : deck.name)
                .font(.body.weight(.medium))
            Text(deckSubtitle(deck))
                .font(.caption)
                .foregroundStyle(deck.canStartLesson ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.miss))
        }
    }

    private func deckSubtitle(_ deck: Deck) -> String {
        let count = deck.usableWordCount
        if count < LessonBuilder.pairsPerExercise {
            return "\(count) words, needs \(LessonBuilder.pairsPerExercise)"
        }
        return "\(count) words"
    }

    // MARK: - Behaviour

    private func start(title: String, pool: [WordPair]) {
        guard pool.count >= LessonBuilder.pairsPerExercise else { return }
        activeRequest = LessonRequest(title: title, pool: pool)
    }

    private func createDeck() {
        let name = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(Deck(name: name))
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(PreviewData.container)
}
