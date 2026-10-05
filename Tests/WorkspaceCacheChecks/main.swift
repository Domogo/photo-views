import Foundation
import PhotoViewsCore

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
var cache = BrowseSnapshots()
let source = UUID()
let assets: [[String:Any]] = (0..<650).map { index in
    ["asset":["id":UUID().uuidString,"sourceID":source.uuidString,"relativePath":"photo-\(index).jpg","byteSize":100],"available":true]
}
let data = try JSONSerialization.data(withJSONObject:["assets":assets,"resultCount":18000,"candidateCount":18000,"cameras":[],"coverage":["total":18000,"embedded":18000,"failed":0],"modelVersion":"fixture","rankingVersion":"fixture"])
let result = try JSONDecoder().decode(SearchResult.self,from:data)
let all = ViewRecipe()
cache.remember(result,for:all)
require(cache.restore(all)?.assets.count == 500,"Browse pages must be bounded even after deep pagination")
require(cache.restore(all)?.resultCount == 18000,"Loaded count must not replace total count")
var presentation = all; presentation.grouping = .camera; presentation.searchMode = "filename"; presentation.collapsePairs = true
require(cache.restore(presentation) != nil,"Presentation-only changes must reuse an equivalent browse page")
var uncollapsed = all; uncollapsed.collapsePairs = false
require(cache.restore(uncollapsed) == nil,"Pair membership must not be borrowed from a collapsed cache")
var filtered = all; filtered.filters.camera = "Nikon"
require(cache.restore(filtered) == nil,"Exact-filter changes must not reuse unfiltered membership")
var searched = all; searched.search = "women"
require(cache.restore(searched) == nil,"A semantic query must not receive the broad browse page")
var similar = all; similar.referenceAssetID = UUID()
require(cache.restore(similar) == nil,"A reference search must not receive the broad browse page")
var favorites = all; favorites.favoritesOnly = true
require(cache.restore(favorites) == nil,"Favorites must not borrow All photos")
var person = all; person.personID = UUID(); cache.remember(result,for:person)
var other = person; other.personID = UUID()
require(cache.restore(other) == nil,"People identities must stay isolated")
cache.invalidatePeople()
require(cache.restore(person) == nil && cache.restore(all) != nil,"Face corrections invalidate person pages without delaying All photos")
var sorted = all; sorted.sorting = .captureOldest
require(cache.restore(sorted) == nil,"Different sort order must get its own first page")
for _ in 0..<7 { var scoped = all; scoped.sourceIDs = [UUID()]; cache.remember(result,for:scoped) }
require(cache.restore(all) == nil,"Bounded cache must evict old pages")
cache.remember(result,for:all); cache.invalidate()
require(cache.restore(all) == nil,"Catalog changes must invalidate browse pages")
print("PASS: browse-cache membership isolation, RAW/JPEG equivalence, count/size limits, sort keys, People correction invalidation and bounded eviction.")
