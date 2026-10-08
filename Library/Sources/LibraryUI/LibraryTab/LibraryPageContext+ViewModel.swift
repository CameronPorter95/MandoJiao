import Foundation
import LibraryDomain

extension LibraryViewModel {
    /// What a screen in front of the library starts from: the Route's pages and the driver's alike.
    var pageContext: LibraryPageContext {
        LibraryPageContext(
            vocabulary: state.vocabulary,
            openDeck: { self.send(.opened(.deck($0))) },
            openFolder: { self.send(.opened(.folder($0))) },
            layout: { folderID in
                let layout = self.state.layout
                return FolderLayout(
                    expanded: layout.expanded(in: .folder(folderID)),
                    foldedSections: layout.foldedSections[folderID] ?? [],
                    deckSort: layout.deckSort(in: folderID),
                    setExpanded: { self.send(.folderExpanded($0, $1, in: .folder(folderID))) },
                    toggle: { self.send(.folderSectionToggled(folderID, $0)) },
                    setDeckSort: { self.send(.deckSortChanged(folderID, $0)) }
                )
            },
            wordList: WordListLayout(
                sort: state.layout.wordSort,
                setSort: { self.send(.wordSortChanged($0)) }
            )
        )
    }
}
