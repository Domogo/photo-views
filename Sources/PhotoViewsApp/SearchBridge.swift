import Foundation
import PhotoViewsCore

struct SearchFailure: Decodable { var assetID: UUID; var filename: String; var error: String }
struct SearchCoverage: Decodable { var total: Int; var embedded: Int; var failed: Int; var failures: [SearchFailure]? = nil }
struct SearchResult: Decodable {
    var assets: [IndexedAsset]
    var resultCount: Int
    var candidateCount: Int
    var cameras: [String]
    var coverage: SearchCoverage
    var modelVersion: String
    var rankingVersion: String
}
struct EmbeddingProgress: Decodable { var processed: Int; var completed: Int; var failedBatch: Int; var total: Int; var embedded: Int; var failed: Int }

/// Owns a serialized local process away from the UI. Requests yield between small indexing batches.
final class SearchBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label:"PhotoViews.search",qos:.userInitiated)
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private let catalogURL: URL
    init(catalogURL: URL) { self.catalogURL = catalogURL }
    deinit { try? input?.close(); process?.terminate() }
    func request<T: Decodable>(_ payload: [String:Any], as type: T.Type, completion: @escaping (Result<T,Error>) -> Void) {
        queue.async { [self] in
            let result: Result<T,Error>
            do { result = .success(try JSONDecoder().decode(T.self,from:send(payload))) }
            catch { result = .failure(error) }
            DispatchQueue.main.async { completion(result) }
        }
    }
    private func failure(_ text: String) -> NSError { NSError(domain:"PhotoViews.Search",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
    private func launch() throws {
        if let process, process.isRunning { return }
        let cache = FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("PhotoViews/m0")
        let env = ProcessInfo.processInfo.environment
        let python = env["PHOTO_VIEWS_PYTHON"] ?? cache.appendingPathComponent("venv/bin/python").path
        let model = env["PHOTO_VIEWS_MODEL"] ?? cache.appendingPathComponent("model").path
        guard FileManager.default.isExecutableFile(atPath:python), let script = Bundle.main.url(forResource:"search_worker",withExtension:"py") else {
            throw failure("Local search runtime is unavailable. Build the developer app and restore the documented M0 Python environment.")
        }
        let process = Process(), stdin = Pipe(), stdout = Pipe()
        process.executableURL = URL(fileURLWithPath:python)
        process.arguments = [script.path,"--catalog",catalogURL.path,"--model",model]
        var environment = env; environment["HF_HUB_OFFLINE"] = "1"; environment["TRANSFORMERS_OFFLINE"] = "1"; environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment; process.standardInput = stdin; process.standardOutput = stdout
        let log = catalogURL.deletingLastPathComponent().appendingPathComponent("search-worker.log")
        if !FileManager.default.fileExists(atPath:log.path) { FileManager.default.createFile(atPath:log.path,contents:nil) }
        process.standardError = try FileHandle(forWritingTo:log)
        try process.run()
        self.process = process; input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading; buffer = Data()
    }
    private func send(_ payload: [String:Any]) throws -> Data {
        try launch()
        let running = process
        let timeout = DispatchWorkItem { if running?.isRunning == true { running?.terminate() } }
        DispatchQueue.global(qos:.utility).asyncAfter(deadline:.now()+60,execute:timeout)
        defer { timeout.cancel() }
        var request = payload; let id = UUID().uuidString; request["id"] = id; request["protocol"] = 1
        var encoded = try JSONSerialization.data(withJSONObject:request); encoded.append(10)
        do { try input?.write(contentsOf:encoded) } catch { process?.terminate(); throw failure("The local search worker stopped. Try again to restart it.") }
        while !buffer.contains(10) {
            guard let chunk = output?.availableData, !chunk.isEmpty else { process = nil; throw failure("The local search worker stopped. Try again to restart it.") }
            buffer.append(chunk)
            guard buffer.count < 32*1024*1024 else { process?.terminate(); throw failure("The local search response was too large.") }
        }
        let end = buffer.firstIndex(of:10)!, line = Data(buffer[..<end]); buffer.removeSubrange(...end)
        guard let response = try JSONSerialization.jsonObject(with:line) as? [String:Any], response["protocol"] as? Int == 1, response["id"] as? String == id else {
            process?.terminate(); throw failure("The local search worker returned an incompatible response.")
        }
        guard response["ok"] as? Bool == true, let result = response["result"] else { throw failure(response["error"] as? String ?? "Local search failed.") }
        return try JSONSerialization.data(withJSONObject:result)
    }
}
