import Foundation
import PhotoViewsCore

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
// The runner isolates the catalog and denies worker startup. No run-loop yielding
// occurs here: these checks exercise navigation while queries are still pending.
MainActor.assumeIsolated {
    let model = WorkspaceModel()
    require(model.isReady && model.searching, "Initial first-page request must be pending")
    model.selectPeople()
    require(model.browsingPeople && !model.searching, "People must cancel the pending photo request")
    model.selectAll()
    require(!model.browsingPeople && model.searching, "Returning to an unchanged All photos recipe must replace the canceled first page")
    model.cancelSearch()
    model.resultCount = 1500
    model.loadMore()
    require(model.loadingMore && model.assetLimit == 1000, "Pagination must be pending before this navigation case")
    model.selectPeople()
    require(!model.loadingMore && !model.searching, "People must cancel pending pagination")
    model.selectAll()
    require(model.searching && model.assetLimit == 500 && !model.loadingMore, "All photos must replace canceled pagination with a first-page refresh")
    model.cancelSearch()
}
print("PASS: People return replaces canceled first-page and pagination requests for an unchanged browse recipe.")
