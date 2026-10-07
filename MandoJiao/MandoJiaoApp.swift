import CoreDomain
import DictionaryDI
import LibraryDI
import OSLog
import SwiftData
import SwiftUI

@main
struct MandoJiaoApp: App {
    private let dependencies: LiveDependencies

    init() {
        let errorLog = Logger(subsystem: "com.cameronporter.MandoJiao", category: "errors")
        ErrorLog.sink = { model, context in
            errorLog.notice(
                "\(context, privacy: .public) failed: \(model.domain, privacy: .public) \(model.code) \(model.description, privacy: .public)"
            )
        }

        do {
            let store = try VocabularyRepositoryFactory.openStore(hskWords: { (try? DictionaryRepositoryFactory.bundledHSKWords()) ?? [] })
            dependencies = LiveDependencies(modelContainer: store)
        } catch {
            fatalError("Could not open the vocabulary store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}
