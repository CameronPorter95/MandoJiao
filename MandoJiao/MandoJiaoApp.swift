import CoreDomain
import CoreUI
#if DEBUG
import CoreRemote
#endif
import DictionaryDI
import LibraryDI
import OSLog
import SwiftData
import SwiftUI

@main
struct MandoJiaoApp: App {
    private let dependencies: LiveDependencies
    private let screenRegistry: ScreenRegistry?
    #if DEBUG
    private let remoteServer: RemoteServer?
    #endif

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

        // `mando --remote` drives the app launched with -remote. Debug builds only: an open
        // port in a release build would be a security hole.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-remote") {
            let registry = ScreenRegistry()
            screenRegistry = registry
            remoteServer = try? RemoteServer(control: RemoteControl(registry: registry))
            remoteServer?.start()
        } else {
            screenRegistry = nil
            remoteServer = nil
        }
        #else
        screenRegistry = nil
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies, screenRegistry: screenRegistry)
        }
    }
}
