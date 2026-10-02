import Foundation
import PhotoViewsCore

struct FilterChip { var key: String; var title: String }
extension WorkspaceModel {
    var activeFilterChips: [FilterChip] {
        let f = recipe.filters
        var chips: [FilterChip] = []
        for (key,title,value) in [("camera","Camera",f.camera),("lens","Lens",f.lens),("format","Format",f.format),("folder","Folder",f.folder)] {
            if let value { chips.append(FilterChip(key:key,title:title+": "+value)) }
        }
        let dates = DateFormatter(); dates.dateStyle = .medium
        if let date = f.fromDate { chips.append(FilterChip(key:"from",title:"From "+dates.string(from:date))) }
        if let date = f.toDate { chips.append(FilterChip(key:"through",title:"Through "+dates.string(from:date))) }
        for (key,title,value) in [("minISO","ISO ≥",f.minISO),("maxISO","ISO ≤",f.maxISO),("minAperture","f-number ≥",f.minAperture),("maxAperture","f-number ≤",f.maxAperture),("minShutter","Shutter s ≥",f.minShutterSeconds),("maxShutter","Shutter s ≤",f.maxShutterSeconds),("minWidth","Width ≥",f.minWidth),("maxWidth","Width ≤",f.maxWidth),("minHeight","Height ≥",f.minHeight),("maxHeight","Height ≤",f.maxHeight)] {
            if let value { chips.append(FilterChip(key:key,title:title+" "+value.formatted())) }
        }
        for tag in f.confirmedTags { chips.append(FilterChip(key:"tag:"+tag,title:"Tag: "+tag)) }
        return chips
    }
    func removeFilter(_ key: String) {
        switch key {
        case "camera": recipe.filters.camera = nil; case "lens": recipe.filters.lens = nil
        case "format": recipe.filters.format = nil; case "folder": recipe.filters.folder = nil
        case "from": recipe.filters.fromDate = nil; case "through": recipe.filters.toDate = nil
        case "minISO": recipe.filters.minISO = nil; case "maxISO": recipe.filters.maxISO = nil
        case "minAperture": recipe.filters.minAperture = nil; case "maxAperture": recipe.filters.maxAperture = nil
        case "minShutter": recipe.filters.minShutterSeconds = nil; case "maxShutter": recipe.filters.maxShutterSeconds = nil
        case "minWidth": recipe.filters.minWidth = nil; case "maxWidth": recipe.filters.maxWidth = nil
        case "minHeight": recipe.filters.minHeight = nil; case "maxHeight": recipe.filters.maxHeight = nil
        default: if key.hasPrefix("tag:") { recipe.filters.confirmedTags.removeAll { $0 == String(key.dropFirst(4)) } }
        }
    }
}
