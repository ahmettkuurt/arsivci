// Arşivci — macOS için WinRAR benzeri arşiv uygulaması
// Geliştirici: Ahmet Kurt · © 2026 Ahmet Kurt
// Sıkıştırma: ZIP, 7Z, TAR.GZ, TAR.XZ, TAR.BZ2, TAR (her türlü dosya ve klasör)
// Açma/Çıkarma: ZIP, RAR (RAR5 dahil), 7Z, TAR, GZ, BZ2, XZ, ISO, CAB, CPIO, XAR, PKG, DEB, RPM, LHA…
// Motor: macOS'ta yerleşik bsdtar (libarchive). Kuruluysa 7-Zip (brew install sevenzip) yedek motor olarak kullanılır.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Komut satırı araçları

enum Tools {
    static let bsdtar = "/usr/bin/bsdtar"
    static let zip = "/usr/bin/zip"
    static let gzip = "/usr/bin/gzip"
    static let bzip2 = "/usr/bin/bzip2"

    /// Bilgisayarda kurulu 7-Zip (Homebrew vb.)
    static let systemSevenZip: String? =
        ["/opt/homebrew/bin/7zz", "/usr/local/bin/7zz", "/opt/homebrew/bin/7z", "/usr/local/bin/7z"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }

    /// Uygulamanın içine gömülü 7-Zip (Arşivci.app/Contents/MacOS/7zz)
    static let bundledSevenZip: String? = {
        guard let p = Bundle.main.path(forAuxiliaryExecutable: "7zz"),
              FileManager.default.isExecutableFile(atPath: p) else { return nil }
        return p
    }()

    /// Önce bilgisayardaki 7-Zip, yoksa uygulamadaki
    static var sevenZip: String? { systemSevenZip ?? bundledSevenZip }

    static var sevenZipSource: String {
        if systemSevenZip != nil { return "7-ZIP (SİSTEM)" }
        if bundledSevenZip != nil { return "7-ZIP (DAHİLİ)" }
        return ""
    }

    /// RAR oluşturmak için RARLAB'ın lisanslı 'rar' aracı (kullanıcı kendisi kurar)
    static var rar: String? {
        ["/opt/homebrew/bin/rar", "/usr/local/bin/rar", "/Applications/rar/rar",
         NSHomeDirectory() + "/rar/rar", NSHomeDirectory() + "/bin/rar"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static var xz: String? {
        ["/opt/homebrew/bin/xz", "/usr/local/bin/xz", "/usr/bin/xz"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

/// Eşzamanlı işler arasında güvenle veri taşımak için küçük kutu
final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ v: T) { _value = v }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
    func mutate(_ change: (inout T) -> Void) {
        lock.lock(); change(&_value); lock.unlock()
    }
}

struct RunResult {
    let status: Int32
    let out: String
    let err: String
    var ok: Bool { status == 0 }
    var message: String {
        let e = err.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? out.trimmingCharacters(in: .whitespacesAndNewlines) : e
    }
}

func run(_ exe: String, _ args: [String], cwd: URL? = nil,
         stdoutFile: URL? = nil, discardStdout: Bool = false) async -> RunResult {
    await withCheckedContinuation { cont in
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            if let cwd { p.currentDirectoryURL = cwd }
            var env = ProcessInfo.processInfo.environment
            env["COPYFILE_DISABLE"] = "1"          // ._ dosyaları oluşmasın
            env["LANG"] = "en_US.UTF-8"            // Türkçe dosya adları doğru kalsın
            env["LC_ALL"] = "en_US.UTF-8"
            p.environment = env
            p.standardInput = FileHandle.nullDevice // şifre sorup takılmasın

            let errPipe = Pipe()
            p.standardError = errPipe
            var outPipe: Pipe? = nil
            var outHandle: FileHandle? = nil
            if let stdoutFile {
                FileManager.default.createFile(atPath: stdoutFile.path, contents: nil)
                outHandle = try? FileHandle(forWritingTo: stdoutFile)
                p.standardOutput = outHandle
            } else if discardStdout {
                p.standardOutput = FileHandle.nullDevice
            } else {
                let pp = Pipe()
                outPipe = pp
                p.standardOutput = pp
            }

            do { try p.run() } catch {
                cont.resume(returning: RunResult(status: -1, out: "", err: error.localizedDescription))
                return
            }

            let outBox = Box(Data())
            let group = DispatchGroup()
            if let outPipe {
                group.enter()
                DispatchQueue.global().async {
                    outBox.value = outPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
            }
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.wait()
            p.waitUntilExit()
            try? outHandle?.close()
            cont.resume(returning: RunResult(status: p.terminationStatus,
                                             out: String(decoding: outBox.value, as: UTF8.self),
                                             err: String(decoding: errData, as: UTF8.self)))
        }
    }
}

// MARK: - Yardımcılar

let archiveExtensions: Set<String> = [
    "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "lzma", "tlz",
    "zst", "tzst", "lz4", "z", "iso", "cab", "cpio", "xar", "pkg", "jar", "war", "apk", "ipa",
    "deb", "rpm", "lha", "lzh", "arj", "cbz", "cbr", "cb7", "dmg", "wim", "001"
]

func isDirectory(_ url: URL) -> Bool {
    var d: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &d) && d.boolValue
}

func isArchive(_ url: URL) -> Bool {
    !isDirectory(url) && archiveExtensions.contains(url.pathExtension.lowercased())
}

/// "foto.tar.gz" → ("foto", ".tar.gz")
func splitName(_ name: String) -> (String, String) {
    for multi in [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz4", ".tar.lzma"]
    where name.lowercased().hasSuffix(multi) {
        return (String(name.dropLast(multi.count)), String(name.suffix(multi.count)))
    }
    if let dot = name.lastIndex(of: "."), dot != name.startIndex {
        return (String(name[..<dot]), String(name[dot...]))
    }
    return (name, "")
}

func uniqueURL(_ url: URL) -> URL {
    let fm = FileManager.default
    if !fm.fileExists(atPath: url.path) { return url }
    let dir = url.deletingLastPathComponent()
    let (stem, ext) = splitName(url.lastPathComponent)
    var i = 2
    while true {
        let c = dir.appendingPathComponent("\(stem) \(i)\(ext)")
        if !fm.fileExists(atPath: c.path) { return c }
        i += 1
    }
}

func formatSize(_ n: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
}

// MARK: - Modeller

struct ArchiveEntry: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let date: String
    let isDir: Bool
}

enum Engine {
    case bsdtar
    case sevenZip(String)
    case rawGzip
    case rawBzip2
    case rawXz(String)
}

enum CompressFormat: String, CaseIterable, Identifiable {
    case zip = "ZIP", sevenZ = "7Z", rar = "RAR", tgz = "TAR.GZ", txz = "TAR.XZ", tbz = "TAR.BZ2", tar = "TAR"
    var id: String { rawValue }
    /// RAR yalnızca bilgisayarda lisanslı 'rar' aracı varsa kullanılabilir
    var isAvailable: Bool { self != .rar || Tools.rar != nil }
    var ext: String {
        switch self {
        case .zip: return "zip"
        case .sevenZ: return "7z"
        case .rar: return "rar"
        case .tgz: return "tar.gz"
        case .txz: return "tar.xz"
        case .tbz: return "tar.bz2"
        case .tar: return "tar"
        }
    }
    var supportsPassword: Bool { self == .zip || self == .sevenZ || self == .rar }
    var note: String {
        switch self {
        case .zip: return "Her bilgisayarda açılır. Paylaşmak için en güvenli seçim."
        case .sevenZ: return "En küçük boyut. Büyük klasörler için ideal."
        case .rar: return Tools.rar != nil
            ? "WinRAR biçimi (RAR5). Bilgisayarındaki lisanslı RAR aracıyla oluşturulur."
            : "RAR oluşturmak için RARLAB'ın 'rar' aracı gerekir. Seçince nasıl kurulacağını göster."
        case .tgz: return "Linux ve sunucular için standart paket."
        case .txz: return "Çok yüksek sıkıştırma, biraz daha yavaş."
        case .tbz: return "Klasik Unix sıkıştırması."
        case .tar: return "Sıkıştırmadan tek dosyada toplar."
        }
    }
}

/// Dosya ya da klasörün toplam boyutu (klasörler için içeriğiyle birlikte)
func diskSize(_ url: URL) -> Int64 {
    if !isDirectory(url) {
        return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
    var total: Int64 = 0
    if let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
        for case let f as URL in en {
            total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
    return total
}

/// bsdtar -tv satırı: "-rw-r--r--  0 user staff  1234 Oct 12 10:00 klasör/dosya.txt"
func parseTarLine(_ line: Substring) -> ArchiveEntry? {
    var fields: [Substring] = []
    var rest = line[...]
    for _ in 0..<8 {
        rest = rest.drop(while: { $0 == " " })
        guard let end = rest.firstIndex(of: " ") else { return nil }
        fields.append(rest[..<end])
        rest = rest[end...]
    }
    var name = String(rest.drop(while: { $0 == " " }))
    if fields[0].hasPrefix("l"), let r = name.range(of: " -> ") { name = String(name[..<r.lowerBound]) }
    if fields[0].hasPrefix("h"), let r = name.range(of: " link to ") { name = String(name[..<r.lowerBound]) }
    guard !name.isEmpty else { return nil }
    let isDir = fields[0].hasPrefix("d") || name.hasSuffix("/")
    return ArchiveEntry(path: name, size: Int64(fields[4]) ?? 0,
                        date: "\(fields[5]) \(fields[6]) \(fields[7])", isDir: isDir)
}

/// 7zz l -slt çıktısı
func parse7zList(_ text: String) -> [ArchiveEntry] {
    guard let range = text.range(of: "----------") else { return [] }
    var result: [ArchiveEntry] = []
    for block in text[range.upperBound...].components(separatedBy: "\n\n") {
        var d: [String: String] = [:]
        for line in block.split(separator: "\n") {
            if let r = line.range(of: " = ") {
                d[String(line[..<r.lowerBound])] = String(line[r.upperBound...])
            }
        }
        guard let path = d["Path"], !path.isEmpty else { continue }
        let isDir = d["Folder"] == "+" || (d["Attributes"]?.hasPrefix("D") ?? false)
        result.append(ArchiveEntry(path: path, size: Int64(d["Size"] ?? "") ?? 0,
                                   date: d["Modified"] ?? "", isDir: isDir))
    }
    return result
}

// MARK: - Uygulama durumu

@MainActor
final class ArchiveModel: ObservableObject {
    static let shared = ArchiveModel()

    enum Mode: String, CaseIterable, Identifiable {
        case compress = "Sıkıştır", browse = "Arşivi Aç"
        var id: String { rawValue }
    }

    @Published var mode: Mode = .compress
    @Published var filesToCompress: [URL] = [] { didSet { recalcSize() } }
    @Published var totalSize: Int64 = 0
    @Published var format: CompressFormat = .zip
    @Published var password = ""
    @Published var archiveURL: URL?
    @Published var entries: [ArchiveEntry] = []
    @Published var selection = Set<ArchiveEntry.ID>()
    @Published var busy = false
    @Published var status = "Dosyaları pencereye sürükleyip bırakın."
    @Published var alertText: String?

    private var engine: Engine = .bsdtar
    private var sizeTask: Task<Void, Never>?

    var entriesSize: Int64 { entries.reduce(0) { $0 + $1.size } }

    private func recalcSize() {
        sizeTask?.cancel()
        let urls = filesToCompress
        sizeTask = Task {
            let total = await Task.detached(priority: .utility) {
                urls.reduce(Int64(0)) { $0 + diskSize($1) }
            }.value
            if !Task.isCancelled { totalSize = total }
        }
    }

    private var sevenZipHint: String {
        Tools.sevenZip == nil
            ? "\n\nİpucu: Daha fazla biçim için Terminal'de 'brew install sevenzip' kurabilirsiniz; Arşivci onu otomatik kullanır."
            : ""
    }

    static let rarHelp = """
    RAR arşivi oluşturmak WinRAR'ın sahibi RARLAB'ın lisanslı 'rar' aracını gerektirir; \
    lisansı gereği Arşivci'nin içine konamaz. RAR arşivlerini AÇMAK için bir şey gerekmez.

    Kurmak için Terminal'de:
      brew install --cask rar

    Deneme süresi 40 gündür; sonrası için rarlab.com'dan lisans alıp 'rarreg.key' \
    dosyasını ev klasörüne '.rarreg.key' adıyla koyun. Kurulumdan sonra Arşivci'yi yeniden açın.
    """

    func selectFormat(_ f: CompressFormat) {
        if f.isAvailable { format = f } else { alertText = Self.rarHelp }
    }

    private func passwordHint(_ msg: String) -> String {
        let m = msg.lowercased()
        if m.contains("passphrase") || m.contains("password") || m.contains("encrypt") || m.contains("wrong") {
            return "\n\nArşiv şifreli olabilir ya da şifre yanlış. Şifre alanına yazıp tekrar deneyin."
        }
        return ""
    }

    // Finder'dan / Dock'tan açılanlar
    func handleOpened(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if urls.count == 1, isArchive(urls[0]) {
            Task { await openArchive(urls[0]) }
        } else {
            addFiles(urls)
            mode = .compress
        }
    }

    func addFiles(_ urls: [URL]) {
        for u in urls where !filesToCompress.contains(u) { filesToCompress.append(u) }
        status = "\(filesToCompress.count) öğe sıkıştırılmaya hazır."
    }

    func chooseFilesToAdd() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Ekle"
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    func chooseArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Aç"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await openArchive(url) }
        }
    }

    private func chooseFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = prompt
        panel.directoryURL = archiveURL?.deletingLastPathComponent()
        return panel.runModal() == .OK ? panel.url : nil
    }

    private var rawName: String {
        archiveURL?.deletingPathExtension().lastPathComponent ?? "dosya"
    }

    // MARK: Arşiv açma

    func openArchive(_ url: URL) async {
        mode = .browse
        archiveURL = url
        entries = []
        selection = []
        busy = true
        status = "Okunuyor: \(url.lastPathComponent)"
        defer { busy = false }

        // 1) Yerleşik bsdtar
        var args: [String] = []
        if !password.isEmpty { args += ["--passphrase", password] }
        args += ["-tvf", url.path]
        let r = await run(Tools.bsdtar, args)
        if r.ok {
            engine = .bsdtar
            entries = r.out.split(separator: "\n").compactMap(parseTarLine)
            finishOpen()
            return
        }

        // 2) 7-Zip (kuruluysa)
        if let sz = Tools.sevenZip {
            var a = ["l", "-slt"]
            if !password.isEmpty { a.append("-p" + password) }
            a.append(url.path)
            let r2 = await run(sz, a)
            if r2.ok {
                engine = .sevenZip(sz)
                entries = parse7zList(r2.out)
                finishOpen()
                return
            }
        }

        // 3) Tek dosyalık sıkıştırılmış dosyalar (.gz, .bz2, .xz)
        let ext = url.pathExtension.lowercased()
        let single = [ArchiveEntry(path: url.deletingPathExtension().lastPathComponent, size: 0, date: "", isDir: false)]
        if ext == "gz" || ext == "z" { engine = .rawGzip; entries = single; finishOpen(); return }
        if ext == "bz2" { engine = .rawBzip2; entries = single; finishOpen(); return }
        if ext == "xz", let x = Tools.xz { engine = .rawXz(x); entries = single; finishOpen(); return }

        status = "Açılamadı: \(url.lastPathComponent)"
        alertText = "Arşiv açılamadı.\n\n\(r.message)\(passwordHint(r.message))\(sevenZipHint)"
    }

    private func finishOpen() {
        status = "\(archiveURL?.lastPathComponent ?? "") — \(entries.count) öğe"
    }

    // MARK: Çıkarma

    func extractHere() async {
        guard let a = archiveURL else { return }
        let stem = splitName(a.lastPathComponent).0
        let dest = uniqueURL(a.deletingLastPathComponent().appendingPathComponent(stem))
        await extract(to: dest, onlySelected: false)
    }

    func extractElsewhere() async {
        guard let dest = chooseFolder(prompt: "Buraya Çıkar") else { return }
        await extract(to: dest, onlySelected: false)
    }

    func extractSelected() async {
        guard let dest = chooseFolder(prompt: "Seçilenleri Çıkar") else { return }
        await extract(to: dest, onlySelected: true)
    }

    func extract(to dest: URL, onlySelected: Bool) async {
        guard let archive = archiveURL else { return }
        let paths: [String] = onlySelected
            ? entries.filter { selection.contains($0.id) }
                     .map { $0.path.hasSuffix("/") ? String($0.path.dropLast()) : $0.path }
            : []
        if onlySelected && paths.isEmpty { alertText = "Önce listeden öğe seçin."; return }

        busy = true
        status = "Çıkarılıyor…"
        defer { busy = false }
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        let r: RunResult
        switch engine {
        case .bsdtar:
            var a: [String] = []
            if !password.isEmpty { a += ["--passphrase", password] }
            a += ["-xf", archive.path, "-C", dest.path] + paths
            r = await run(Tools.bsdtar, a)
        case .sevenZip(let sz):
            var a = ["x", archive.path, "-o" + dest.path, "-y"]
            if !password.isEmpty { a.append("-p" + password) }
            r = await run(sz, a + paths)
        case .rawGzip:
            r = await run(Tools.gzip, ["-dc", archive.path], stdoutFile: uniqueURL(dest.appendingPathComponent(rawName)))
        case .rawBzip2:
            r = await run(Tools.bzip2, ["-dc", archive.path], stdoutFile: uniqueURL(dest.appendingPathComponent(rawName)))
        case .rawXz(let x):
            r = await run(x, ["-dc", archive.path], stdoutFile: uniqueURL(dest.appendingPathComponent(rawName)))
        }

        if r.ok {
            status = "Çıkarıldı → \(dest.path)"
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        } else {
            status = "Çıkarma başarısız."
            alertText = "Çıkarma başarısız.\n\n\(r.message)\(passwordHint(r.message))"
        }
    }

    // MARK: Test

    func testArchive() async {
        guard let archive = archiveURL else { return }
        busy = true
        status = "Test ediliyor…"
        defer { busy = false }
        let r: RunResult
        switch engine {
        case .bsdtar:
            var a: [String] = []
            if !password.isEmpty { a += ["--passphrase", password] }
            r = await run(Tools.bsdtar, a + ["-xOf", archive.path], discardStdout: true)
        case .sevenZip(let sz):
            var a = ["t", archive.path]
            if !password.isEmpty { a.append("-p" + password) }
            r = await run(sz, a)
        case .rawGzip:
            r = await run(Tools.gzip, ["-t", archive.path])
        case .rawBzip2:
            r = await run(Tools.bzip2, ["-t", archive.path])
        case .rawXz(let x):
            r = await run(x, ["-t", archive.path])
        }
        if r.ok {
            status = "Test başarılı."
            alertText = "Arşiv sağlam, hata bulunamadı. ✅"
        } else {
            status = "Test başarısız."
            alertText = "Arşivde sorun var.\n\n\(r.message)\(passwordHint(r.message))"
        }
    }

    // MARK: Sıkıştırma

    func compress() async {
        guard let first = filesToCompress.first else { return }
        let fm = FileManager.default
        let stem: String
        if filesToCompress.count == 1 {
            stem = isDirectory(first) ? first.lastPathComponent : splitName(first.lastPathComponent).0
        } else {
            stem = "Arşiv"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(stem).\(format.ext)"
        panel.directoryURL = first.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.prompt = "Sıkıştır"
        guard panel.runModal() == .OK, let out = panel.url else { return }

        if format.supportsPassword && !password.isEmpty && format == .sevenZ && Tools.sevenZip == nil {
            alertText = "Şifreli 7Z oluşturmak için 7-Zip gerekli.\nTerminal'de: brew install sevenzip\n\nYa da biçimi ZIP seçin."
            return
        }
        if format == .rar && Tools.rar == nil {
            alertText = Self.rarHelp
            return
        }

        busy = true
        status = "Sıkıştırılıyor…"
        defer { busy = false }
        if fm.fileExists(atPath: out.path) { try? fm.removeItem(at: out) }

        // Farklı klasörlerden gelen dosyaları klasörlerine göre grupla
        var order: [String] = []
        var groups: [String: [String]] = [:]
        for u in filesToCompress {
            let dir = u.deletingLastPathComponent().path
            if groups[dir] == nil { order.append(dir); groups[dir] = [] }
            groups[dir]!.append(u.lastPathComponent)
        }

        var result = RunResult(status: 0, out: "", err: "")
        let usePassword = format.supportsPassword && !password.isEmpty

        if format == .rar, let rar = Tools.rar {
            // RARLAB 'rar' aracı ile RAR5 arşivi (şifre varsa dosya adları da gizlenir)
            for dir in order {
                var a = ["a", "-r", "-ma5", "-idq", "-y", "-x*.DS_Store"]
                if usePassword { a.append("-hp" + password) }
                a += [out.path] + groups[dir]!
                result = await run(rar, a, cwd: URL(fileURLWithPath: dir))
                if !result.ok { break }
            }
        } else if usePassword, let sz = Tools.sevenZip {
            // 7-Zip ile AES-256 şifreleme
            for dir in order {
                var a = ["a", format == .zip ? "-tzip" : "-t7z", "-p" + password, "-xr!.DS_Store"]
                a.append(format == .zip ? "-mem=AES256" : "-mhe=on")
                a += [out.path] + groups[dir]!
                result = await run(sz, a, cwd: URL(fileURLWithPath: dir))
                if !result.ok { break }
            }
        } else if usePassword && format == .zip {
            // macOS'un yerleşik zip'i ile şifreli ZIP
            for dir in order {
                let a = ["-r", "-q", "-y", "-P", password, out.path] + groups[dir]! + ["-x", "*.DS_Store"]
                result = await run(Tools.zip, a, cwd: URL(fileURLWithPath: dir))
                if !result.ok { break }
            }
        } else {
            // bsdtar ile şifresiz arşiv
            var a = ["-c", "-f", out.path]
            switch format {
            case .zip: a += ["--format", "zip"]
            case .sevenZ: a += ["--format", "7zip"]
            case .tgz: a += ["-z"]
            case .txz: a += ["-J"]
            case .tbz: a += ["-j"]
            case .tar, .rar: break
            }
            a += ["--exclude", ".DS_Store"]
            for dir in order { a += ["-C", dir] + groups[dir]! }
            result = await run(Tools.bsdtar, a)
        }

        if result.ok {
            let size = (try? fm.attributesOfItem(atPath: out.path)[.size] as? Int64) ?? nil
            status = "Oluşturuldu: \(out.lastPathComponent)" + (size.map { " (\(formatSize($0)))" } ?? "")
            NSWorkspace.shared.activateFileViewerSelecting([out])
        } else {
            status = "Sıkıştırma başarısız."
            alertText = "Sıkıştırma başarısız.\n\n\(result.message)"
        }
    }
}

