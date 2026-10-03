import SwiftUI
import PhotoViewsCore

extension WorkspaceModel {
    func selectPeople() {
        browsingPeople = true; selectedAssetID = nil; showInspector = false
        refreshPeople()
    }
    func selectPerson(_ person: PersonGroup) {
        browsingPeople = false; selectedSavedView = nil; recipe = ViewRecipe(); recipe.personID = person.id
        selectedAssetID = nil; persistRecipe()
    }
    func refinePeople() {
        pausePeople()
        requestPeople(["op":"people-refine"]) { _ in }
    }
    func refreshPeople() {
        requestPeople(["op":"people"]) { [weak self] progress in
            if let self, !self.didStartPeople && progress.remaining > 0 { self.didStartPeople = true; self.indexPeople() }
        }
    }
    func indexPeople(retry: Bool = false) {
        guard !peopleIndexing else { return }
        peopleGeneration += 1; peopleIndexing = true; peopleError = nil
        peopleBatch(generation:peopleGeneration,retry:retry)
    }
    func pausePeople() { peopleGeneration += 1; peopleIndexing = false }
    private func peopleBatch(generation: Int, retry: Bool = false) {
        requestPeople(["op":"people-index","limit":4,"retry":retry]) { [weak self] progress in
            guard let self, self.peopleGeneration == generation else { return }
            if progress.processed == 0 || !self.peopleIndexing { self.peopleIndexing = false; if self.recipe.personID != nil { self.refreshAssets() }; return }
            self.peopleBatch(generation:generation)
        }
    }
    private func requestPeople(_ payload: [String:Any], completed: @escaping (PeopleProgress) -> Void) {
        peopleBridge.request(payload,as:PeopleProgress.self) { [weak self] response in
            guard let self else { return }
            switch response {
            case .success(let value): self.people = value.people; self.peopleProgress = value; self.peopleError = nil; completed(value)
            case .failure(let error): self.peopleIndexing = false; self.peopleError = error.localizedDescription
            }
        }
    }
    func removeFromPerson(_ asset: IndexedAsset) {
        guard let person = recipe.personID else { return }
        requestPeople(["op":"people-correct","action":"remove","personID":person.uuidString,"assetID":asset.id.uuidString]) { [weak self] _ in self?.refreshAssets() }
    }
    func mergePeople(_ person: PersonGroup, into target: PersonGroup) {
        requestPeople(["op":"people-correct","action":"merge","personID":person.id.uuidString,"targetID":target.id.uuidString]) { _ in }
    }
    func restorePersonMatches() {
        guard let person = recipe.personID else { return }
        requestPeople(["op":"people-correct","action":"restore","personID":person.uuidString]) { [weak self] _ in self?.refreshAssets() }
    }
}

struct PeopleBrowser: View {
    @ObservedObject var model: WorkspaceModel
    @State private var merging: PersonGroup?
    private let columns = [GridItem(.adaptive(minimum:132,maximum:180),spacing:24)]
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Text("People").font(.title2.weight(.semibold))
                Spacer()
                if let progress = model.peopleProgress {
                    Text("\(progress.prepared) / \(progress.total) previews checked").font(.caption).foregroundStyle(.secondary)
                    if progress.failed > 0 { Text("\(progress.failed) failed").font(.caption).foregroundStyle(.secondary) }
                }
                if model.peopleIndexing {
                    ProgressView().controlSize(.small)
                    Button("Pause") { model.pausePeople() }
                } else {
                    if model.people.count > 1 { Button("Refine Groups") { model.refinePeople() }.help("Combine strongly matching groups using all detected faces") }
                    Button(model.people.isEmpty ? "Find People" : "Scan New Photos") { model.indexPeople() }
                    if (model.peopleProgress?.failed ?? 0) > 0 { Button("Retry Failed") { model.indexPeople(retry:true) } }
                }
            }.padding(20)
            if let error = model.peopleError { Text(error).foregroundStyle(.secondary).textSelection(.enabled).padding(.horizontal,20) }
            if model.people.isEmpty {
                Spacer()
                Image(systemName:"person.crop.circle").font(.system(size:40)).foregroundStyle(.secondary)
                Text(model.peopleIndexing ? "Finding faces…" : "Browse familiar faces").font(.title3).padding(.top,8)
                Text("Find people in your cached photos. Everything stays on this Mac.").foregroundStyle(.secondary).padding(.top,4)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns:columns,spacing:24) {
                        ForEach(model.people) { person in
                            Button { model.selectPerson(person) } label: {
                                VStack(spacing:8) {
                                    CachedPhoto(path:person.avatarPath,revision:person.id.uuidString,fill:true)
                                        .frame(width:112,height:112).clipShape(Circle())
                                    Text("\(person.count) \(person.count == 1 ? "photo" : "photos")").font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth:.infinity)
                            }.buttonStyle(.plain).accessibilityLabel("Person, \(person.count) photos").help("Suggested person group. Right-click to merge groups.")
                            .contextMenu { Button("Merge with Another Person…") { merging = person } }
                        }
                    }.padding(20)
                }
            }
        }
        .sheet(item:$merging) { person in
            VStack(alignment:.leading,spacing:16) {
                Text("Same person?").font(.title2)
                Text("Choose the face to combine these photos with.").foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(columns:columns,spacing:16) {
                        ForEach(model.people.filter { $0.id != person.id }) { target in
                            Button { model.mergePeople(person,into:target); merging = nil } label: {
                                CachedPhoto(path:target.avatarPath,revision:target.id.uuidString,fill:true).frame(width:80,height:80).clipShape(Circle())
                            }.buttonStyle(.plain).accessibilityLabel("Merge into person with \(target.count) photos")
                        }
                    }
                }
                Button("Cancel") { merging = nil }.keyboardShortcut(.cancelAction)
            }.padding(24).frame(width:520,height:440)
        }
    }
}
