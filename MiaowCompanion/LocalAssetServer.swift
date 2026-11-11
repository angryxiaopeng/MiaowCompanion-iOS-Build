import Foundation
import Network
import Combine

/// Read-only, token-scoped HTTP on loopback so WebKit video, JSON and WebGL share a normal local origin.
final class LocalAssetServer: ObservableObject {
    @Published private(set) var pageURL: URL?
    @Published private(set) var failure: String?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "cn.miaow.local-assets")
    private let root: URL
    private let token = UUID().uuidString
    private var triedFallback = false
    init() {
        root = Bundle.main.resourceURL!.appendingPathComponent("Web", isDirectory: true).standardizedFileURL
        start(port: UInt16(UserDefaults.standard.integer(forKey: "miaow.localPort")).nonzero ?? 17746)
    }
    private func start(port: UInt16) {
        do {
            let endpoint = NWEndpoint.Port(rawValue: port) ?? .any
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: endpoint)
            parameters.allowLocalEndpointReuse = true
            let newListener = try NWListener(using: parameters, on: endpoint)
            listener = newListener
            newListener.stateUpdateHandler = { [weak self, weak newListener] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    guard let number = newListener?.port?.rawValue,
                          let url = URL(string: "http://127.0.0.1:\(number)/\(self.token)/index.html") else { return }
                    UserDefaults.standard.set(Int(number), forKey: "miaow.localPort")
                    DispatchQueue.main.async { self.pageURL = url; self.failure = nil }
                case .failed(let error):
                    if !self.triedFallback { self.triedFallback = true; newListener?.cancel(); self.start(port: 0) }
                    else { DispatchQueue.main.async { self.failure = "本地画面服务未启动：\(error.localizedDescription)" } }
                default: break
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                guard let self = self else { connection.cancel(); return }
                connection.start(queue: self.queue)
                self.readHeader(connection, accumulated: Data())
            }
            newListener.start(queue: queue)
        } catch { DispatchQueue.main.async { self.failure = error.localizedDescription } }
    }
    private func readHeader(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, ended, error in
            guard let self = self else { connection.cancel(); return }
            var bytes = accumulated
            if let data = data { bytes.append(data) }
            if bytes.count > 16384 { self.simple(connection, status: "431 Request Header Fields Too Large"); return }
            if let text = String(data: bytes, encoding: .utf8), text.contains("\r\n\r\n") { self.respond(connection, header: text); return }
            if ended || error != nil { connection.cancel() }
            else { self.readHeader(connection, accumulated: bytes) }
        }
    }
    private func respond(_ connection: NWConnection, header: String) {
        let lines = header.components(separatedBy: "\r\n")
        let request = (lines.first ?? "").split(separator: " ")
        guard request.count >= 2 else { simple(connection, status: "400 Bad Request"); return }
        let method = String(request[0]); guard method == "GET" || method == "HEAD" else { simple(connection, status: "405 Method Not Allowed"); return }
        let target = String(request[1]).components(separatedBy: "?")[0]
        let prefix = "/\(token)/"
        guard target.hasPrefix(prefix), let path = String(target.dropFirst(prefix.count)).removingPercentEncoding,
              !path.contains("\0"), !path.split(separator: "/").contains("..") else { simple(connection, status: "404 Not Found"); return }
        let file = root.appendingPathComponent(path.isEmpty ? "index.html" : path).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"), let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true, let size = values.fileSize else { simple(connection, status: "404 Not Found"); return }
        var start = 0; var end = max(0, size - 1); var partial = false
        if let rangeLine = lines.first(where: { $0.lowercased().hasPrefix("range:") }) {
            let value = rangeLine.dropFirst(6).trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("bytes="), !value.contains(",") else { simple(connection, status: "416 Range Not Satisfiable", extra: "Content-Range: bytes */\(size)\r\n"); return }
            let parts = value.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 2 else { simple(connection, status: "416 Range Not Satisfiable"); return }
            if parts[0].isEmpty {
                guard let suffix = Int(parts[1]), suffix > 0 else { simple(connection, status: "416 Range Not Satisfiable"); return }
                start = max(0, size - suffix)
            } else {
                guard let first = Int(parts[0]), first >= 0 else { simple(connection, status: "416 Range Not Satisfiable"); return }
                start = first
                if !parts[1].isEmpty { guard let last = Int(parts[1]) else { simple(connection, status: "416 Range Not Satisfiable"); return }; end = min(last, end) }
            }
            guard start < size, end >= start else { simple(connection, status: "416 Range Not Satisfiable", extra: "Content-Range: bytes */\(size)\r\n"); return }
            partial = true
        }
        let length = size == 0 ? 0 : end - start + 1
        let types = ["html":"text/html; charset=utf-8", "js":"application/javascript", "css":"text/css", "json":"application/json", "png":"image/png", "svg":"image/svg+xml", "mp4":"video/mp4", "webmanifest":"application/manifest+json"]
        let type = types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let range = partial ? "Content-Range: bytes \(start)-\(end)/\(size)\r\n" : ""
        let response = "HTTP/1.1 \(partial ? "206 Partial Content" : "200 OK")\r\nContent-Type: \(type)\r\nContent-Length: \(length)\r\nAccept-Ranges: bytes\r\n\(range)Connection: close\r\nX-Content-Type-Options: nosniff\r\nCache-Control: no-store\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            if error != nil || method == "HEAD" || length == 0 { connection.cancel(); return }
            guard let self = self, let handle = try? FileHandle(forReadingFrom: file) else { connection.cancel(); return }
            do { try handle.seek(toOffset: UInt64(start)); self.sendFile(connection, handle: handle, remaining: length) }
            catch { try? handle.close(); connection.cancel() }
        })
    }
    private func sendFile(_ connection: NWConnection, handle: FileHandle, remaining: Int) {
        do {
            let data = try handle.read(upToCount: min(65536, remaining)) ?? Data()
            guard !data.isEmpty else { try? handle.close(); connection.cancel(); return }
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                let next = remaining - data.count
                if error != nil || next <= 0 { try? handle.close(); connection.cancel() }
                else { self?.sendFile(connection, handle: handle, remaining: next) }
            })
        } catch { try? handle.close(); connection.cancel() }
    }
    private func simple(_ connection: NWConnection, status: String, extra: String = "") {
        connection.send(content: Data("HTTP/1.1 \(status)\r\n\(extra)Content-Length: 0\r\nConnection: close\r\n\r\n".utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
    deinit { listener?.cancel() }
}
private extension UInt16 { var nonzero: UInt16? { self == 0 ? nil : self } }
