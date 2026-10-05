import PhotoViewsCore

/// Bounded first pages for immediate return navigation, refreshed by the worker afterward.
/// Search/filter membership is never inferred from a broader cached page.
struct BrowseSnapshots {
    private var pages: [(recipe:ViewRecipe,result:SearchResult)] = []
    private func key(_ recipe: ViewRecipe) -> ViewRecipe? {
        guard recipe.search.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, recipe.referenceAssetID == nil,
              recipe.palette == nil, recipe.filters == ExactFilters() else { return nil }
        var key = recipe; key.grouping = .none; key.minimumSimilarity = nil
        key.modelVersion = nil; key.rankingVersion = nil; key.searchMode = nil
        key.collapsePairs = recipe.collapsePairs != false
        return key
    }
    func restore(_ recipe: ViewRecipe) -> SearchResult? {
        guard let key = key(recipe) else { return nil }
        return pages.first { $0.recipe == key }?.result
    }
    mutating func remember(_ result: SearchResult, for recipe: ViewRecipe) {
        guard let key = key(recipe) else { return }
        var page = result; page.assets = Array(result.assets.prefix(500)); page.selectedAsset = nil
        pages.removeAll { $0.recipe == key }; pages.insert((key,page),at:0)
        if pages.count > 6 { pages.removeLast() }
    }
    mutating func invalidate() { pages.removeAll() }
    mutating func invalidatePeople() { pages.removeAll { $0.recipe.personID != nil } }
}
