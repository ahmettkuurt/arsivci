// Arşivci — Arayüz (Neubrutalism)
// Geliştirici: Ahmet Kurt · © 2026 Ahmet Kurt
// Kalın siyah çerçeveler, sert ofset gölgeler, düz canlı renkler, ağır tipografi.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Tema

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }

    /// Açık / koyu moda göre değişen renk
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

enum Theme {
    static let bg      = Color.adaptive(0xFFF6E0, 0x16161A)   // krem / gece
    static let surface = Color.adaptive(0xFFFFFF, 0x24242C)
    static let ink     = Color.adaptive(0x111111, 0xF3EBD8)   // çizgi + yazı
    static let muted   = Color.adaptive(0x5C5446, 0xB3AB9A)
    static let onPop   = Color(hex: 0x111111)                  // canlı renkler üstündeki yazı

    static let yellow  = Color(hex: 0xFFD23F)
    static let coral   = Color(hex: 0xFF6B6B)
    static let teal    = Color(hex: 0x4ECDC4)
    static let blue    = Color(hex: 0x7CB4FF)
    static let violet  = Color(hex: 0xC3A6FF)
    static let pops: [Color] = [yellow, coral, teal, blue, violet]
}

func popColor(for key: String) -> Color {
    let h = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    return Theme.pops[h % Theme.pops.count]
}

private let trLocale = Locale(identifier: "tr_TR")

// MARK: - Yapı taşları

struct BrutalBox: ViewModifier {
    var fill: Color
    var radius: CGFloat = 10
    var offset: CGFloat = 5
    var line: CGFloat = 3

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: line))
            .background(shape.fill(Theme.ink).offset(x: offset, y: offset))
    }
}

extension View {
    func brutal(_ fill: Color, radius: CGFloat = 10, offset: CGFloat = 5, line: CGFloat = 3) -> some View {
        modifier(BrutalBox(fill: fill, radius: radius, offset: offset, line: line))
    }
}

/// Küçük, büyük harfli, monospaced bölüm etiketi
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased(with: trLocale))
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }
}

struct Chip: View {
    let text: String
    var fill: Color = Theme.yellow
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(Theme.onPop)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.onPop, lineWidth: 1.5))
    }
}

/// Basınca "içeri gömülen" kalın butonlar
struct BrutalButtonStyle: ButtonStyle {
    var fill: Color = Theme.yellow
    var big = false
    func makeBody(configuration: Configuration) -> some View {
        BrutalButtonBody(configuration: configuration, fill: fill, big: big)
    }
}

private struct BrutalButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let big: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var cursorPushed = false

    var body: some View {
        let pressed = configuration.isPressed && isEnabled
        let depth: CGFloat = big ? 5 : 4
        let lift: CGFloat = pressed ? depth : ((hovering && isEnabled) ? -1 : 0)
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        return configuration.label
            .font(.system(size: big ? 15 : 13, weight: .heavy))
            .foregroundStyle(Theme.onPop)
            .padding(.horizontal, big ? 22 : 14)
            .padding(.vertical, big ? 13 : 8)
            .frame(minHeight: 32)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Theme.onPop, lineWidth: 2.5))
            .background(shape.fill(Theme.ink).offset(x: depth - lift, y: depth - lift))
            .offset(x: lift, y: lift)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
            .onHover { h in
                hovering = h
                if h && isEnabled && !cursorPushed { NSCursor.pointingHand.push(); cursorPushed = true }
                else if !h && cursorPushed { NSCursor.pop(); cursorPushed = false }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovering)
    }
}

struct PasswordField: View {
    @Binding var text: String
    var enabled = true
    var placeholder = "İsteğe bağlı"
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .focused($focused)
                .accessibilityLabel("Şifre")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .brutal(Theme.surface, radius: 8, offset: focused ? 3 : 0, line: 2.5)   // odakta gölge belirir
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: focused)
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
    }
}

/// Eğik, gölgeli ikon bloğu (boş ekranlar için)
struct StickerIcon: View {
    let systemName: String
    let fill: Color
    var angle: Double = -6
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.ink).frame(width: 96, height: 96).offset(x: 6, y: 6)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(fill).frame(width: 96, height: 96)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.onPop, lineWidth: 3))
            Image(systemName: systemName)
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(Theme.onPop)
        }
        .rotationEffect(.degrees(angle))
        .accessibilityHidden(true)
    }
}

// MARK: - Sürükle-bırak

func loadURLs(_ providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
    let group = DispatchGroup()
    let box = Box([URL]())
    for p in providers where p.canLoadObject(ofClass: URL.self) {
        group.enter()
        _ = p.loadObject(ofClass: URL.self) { url, _ in
            if let url { box.mutate { $0.append(url) } }
            group.leave()
        }
    }
    group.notify(queue: .main) { completion(box.value) }
}

// MARK: - Ana pencere

struct ContentView: View {
    @EnvironmentObject var model: ArchiveModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Header()
                    .padding(.horizontal, 26)
                    .padding(.top, 36)          // trafik ışıklarına yer
                    .padding(.bottom, 20)
                    .disabled(model.busy)

                Group {
                    if model.mode == .compress { CompressView() } else { BrowseView() }
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(model.busy)

                StatusBar()
            }
        }
        .tint(Theme.blue)
        .alert("Arşivci", isPresented: Binding(
            get: { model.alertText != nil },
            set: { if !$0 { model.alertText = nil } })
        ) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(model.alertText ?? "")
        }
    }
}

struct Header: View {
    @EnvironmentObject var model: ArchiveModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("ARŞİVCİ")
                    .font(.system(size: 28, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    Rectangle().fill(Theme.coral).frame(width: 48, height: 5)
                    Text("by AHMET KURT")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Theme.muted)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 20)
            ModeTabs()
            Button { model.chooseArchive() } label: {
                Label("Arşiv Aç", systemImage: "folder.fill")
            }
            .buttonStyle(BrutalButtonStyle(fill: Theme.teal))
            .help("Bir arşiv dosyası seç (⌘O)")
        }
    }
}

struct ModeTabs: View {
    @EnvironmentObject var model: ArchiveModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ArchiveModel.Mode.allCases) { m in
                let selected = model.mode == m
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { model.mode = m }
                } label: {
                    Label(m.rawValue, systemImage: m == .compress ? "arrow.down.right.and.arrow.up.left" : "shippingbox.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(selected ? Theme.onPop : Theme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(selected ? Theme.yellow : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                if m == .compress { Rectangle().fill(Theme.ink).frame(width: 2.5) }
            }
        }
        .fixedSize()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .brutal(Theme.surface, radius: 8, offset: 4, line: 2.5)
    }
}

struct StatusBar: View {
    @EnvironmentObject var model: ArchiveModel

    var body: some View {
        HStack(spacing: 10) {
            if model.busy {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(Theme.teal).frame(width: 8, height: 8).accessibilityHidden(true)
            }
            Text(model.status)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.bg)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(Tools.sevenZip == nil ? "MOTOR · BSDTAR" : "MOTOR · BSDTAR + 7-ZIP")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.bg.opacity(0.7))
            Rectangle().fill(Theme.bg.opacity(0.35)).frame(width: 1.5, height: 14)
            Text("AHMET KURT TARAFINDAN YAPILDI")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.yellow)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 9)
        .background(Theme.ink)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sıkıştır

struct CompressView: View {
    @EnvironmentObject var model: ArchiveModel
    @State private var targeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            dropArea
            settingsPanel.frame(width: 300)
        }
    }

    private var dropArea: some View {
        ZStack {
            if model.filesToCompress.isEmpty { emptyState } else { fileList }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brutal(targeted ? Theme.teal : Theme.surface, radius: 16, offset: targeted ? 2 : 7)
        .padding(.trailing, 7)
        .padding(.bottom, 7)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: targeted)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            loadURLs(providers) { urls in Task { @MainActor in model.addFiles(urls) } }
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            StickerIcon(systemName: "arrow.down", fill: Theme.coral)
            Text("BIRAK.")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(targeted ? Theme.onPop : Theme.ink)
            Text("Dosya, klasör, video, uygulama — ne olursa.\nSürükle buraya, gerisini Arşivci halleder.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(targeted ? Theme.onPop : Theme.muted)
                .multilineTextAlignment(.center)
            Button { model.chooseFilesToAdd() } label: {
                Label("Dosya Seç", systemImage: "plus")
            }
            .buttonStyle(BrutalButtonStyle(fill: Theme.yellow))
            .padding(.top, 4)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(16)
        )
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Eyebrow(text: "\(model.filesToCompress.count) öğe · \(formatSize(model.totalSize))")
                Spacer()
                Button("Temizle") { model.filesToCompress = [] }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .underline()
                    .help("Listeyi boşalt")
                Button { model.chooseFilesToAdd() } label: {
                    Label("Ekle", systemImage: "plus")
                }
                .buttonStyle(BrutalButtonStyle(fill: Theme.yellow))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Rectangle().fill(Theme.ink).frame(height: 3)

            List {
                ForEach(model.filesToCompress, id: \.self) { url in
                    FileRow(url: url)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 8, trailing: 18))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Biçim")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(CompressFormat.allCases) { f in
                    FormatChip(format: f, selected: model.format == f) { model.format = f }
                }
            }
            Text(model.format.note)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Eyebrow(text: "Şifre").padding(.top, 6)
            PasswordField(text: $model.password,
                          enabled: model.format.supportsPassword,
                          placeholder: model.format.supportsPassword ? "İsteğe bağlı" : "Bu biçimde şifre yok")

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Toplam")
                Text(model.filesToCompress.isEmpty ? "—" : formatSize(model.totalSize))
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Button { Task { await model.compress() } } label: {
                HStack {
                    Image(systemName: "archivebox.fill")
                    Text("SIKIŞTIR")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrutalButtonStyle(fill: Theme.coral, big: true))
            .keyboardShortcut(.defaultAction)
            .disabled(model.filesToCompress.isEmpty)
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .brutal(Theme.surface, radius: 16, offset: 7)
        .padding(.trailing, 7)
        .padding(.bottom, 7)
    }
}

struct FormatChip: View {
    let format: CompressFormat
    let selected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(format.rawValue)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(selected ? Theme.onPop : Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .brutal(selected ? Theme.yellow : Theme.surface, radius: 8, offset: selected ? 3 : 0, line: selected ? 2.5 : 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Biçim \(format.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: selected)
    }
}

struct FileRow: View {
    @EnvironmentObject var model: ArchiveModel
    let url: URL

    var body: some View {
        let dir = isDirectory(url)
        let ext = dir ? "KLASÖR" : (url.pathExtension.isEmpty ? "DOSYA" : url.pathExtension.uppercased())
        return HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 8)
            Chip(text: ext, fill: popColor(for: ext))
            Button {
                model.filesToCompress.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.onPop)
                    .frame(width: 28, height: 28)
                    .brutal(Theme.coral, radius: 6, offset: 2, line: 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Listeden kaldır")
            .accessibilityLabel("\(url.lastPathComponent) öğesini kaldır")
        }
        .padding(10)
        .brutal(Theme.surface, radius: 10, offset: 3, line: 2.5)
    }
}

// MARK: - Arşivi Aç

struct BrowseView: View {
    @EnvironmentObject var model: ArchiveModel
    @State private var targeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let formats = ["ZIP", "RAR", "7Z", "TAR", "GZ", "BZ2", "XZ", "ISO", "CAB", "PKG", "DEB", "RPM"]

    var body: some View {
        Group {
            if let url = model.archiveURL { loaded(url) } else { emptyState }
        }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            loadURLs(providers) { urls in
                if let first = urls.first { Task { @MainActor in await model.openArchive(first) } }
            }
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            StickerIcon(systemName: "shippingbox.fill", fill: Theme.teal, angle: 5)
            Text("ARŞİVİ BIRAK.")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(targeted ? Theme.onPop : Theme.ink)
            Text("ya da sağ üstteki Arşiv Aç ile seç")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(targeted ? Theme.onPop : Theme.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                ForEach(formats, id: \.self) { Chip(text: $0, fill: popColor(for: $0)) }
            }
            .frame(maxWidth: 380)
            .padding(.top, 6)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(16)
        )
        .brutal(targeted ? Theme.yellow : Theme.surface, radius: 16, offset: targeted ? 2 : 7)
        .padding(.trailing, 7)
        .padding(.bottom, 7)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: targeted)
    }

    private func loaded(_ url: URL) -> some View {
        let ext = url.pathExtension.isEmpty ? "ARŞİV" : url.pathExtension.uppercased()
        return VStack(spacing: 18) {
            // Arşiv kartı
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.head)
                    HStack(spacing: 6) {
                        Chip(text: ext, fill: popColor(for: ext))
                        Chip(text: "\(model.entries.count) ÖĞE", fill: Theme.teal)
                        if model.entriesSize > 0 { Chip(text: formatSize(model.entriesSize), fill: Theme.yellow) }
                    }
                    .padding(.top, 3)
                }
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Şifre")
                    HStack(spacing: 10) {
                        PasswordField(text: $model.password, placeholder: "Şifreliyse yaz").frame(width: 170)
                        Button("Yeniden Oku") { Task { await model.openArchive(url) } }
                            .buttonStyle(BrutalButtonStyle(fill: Theme.violet))
                    }
                }
            }
            .padding(16)
            .brutal(Theme.surface, radius: 16, offset: 6)
            .padding(.trailing, 6)

            // İçerik listesi
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Eyebrow(text: "Ad").padding(.leading, 28)
                    Spacer()
                    Eyebrow(text: "Boyut").frame(width: 90, alignment: .trailing)
                    Eyebrow(text: "Tarih").frame(width: 140, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)

                Rectangle().fill(Theme.ink).frame(height: 3)

                List(model.entries, selection: $model.selection) { entry in
                    EntryRow(entry: entry)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .brutal(Theme.surface, radius: 16, offset: 6)
            .padding(.trailing, 6)

            // Eylemler
            HStack(spacing: 12) {
                Button { Task { await model.testArchive() } } label: {
                    Label("Test Et", systemImage: "checkmark.shield.fill")
                }
                .buttonStyle(BrutalButtonStyle(fill: Theme.violet))
                Text(model.selection.isEmpty ? "⌘ ile birden çok öğe seçebilirsin" : "\(model.selection.count) öğe seçili")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer()
                Button { Task { await model.extractSelected() } } label: {
                    Label("Seçilenleri Çıkar", systemImage: "checklist")
                }
                .buttonStyle(BrutalButtonStyle(fill: Theme.blue))
                .disabled(model.selection.isEmpty)
                Button { Task { await model.extractElsewhere() } } label: {
                    Label("Farklı Konuma", systemImage: "folder.badge.plus")
                }
                .buttonStyle(BrutalButtonStyle(fill: Theme.teal))
                Button { Task { await model.extractHere() } } label: {
                    Label("BURAYA ÇIKAR", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(BrutalButtonStyle(fill: Theme.coral, big: true))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 5)
        }
    }
}

struct EntryRow: View {
    let entry: ArchiveEntry
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(entry.isDir ? Theme.ink : Theme.muted)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(entry.path)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(entry.isDir || entry.size == 0 ? "—" : formatSize(entry.size))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .frame(width: 90, alignment: .trailing)
            Text(entry.date)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hakkında

@MainActor
func showAboutPanel() {
    let credits = NSMutableAttributedString(
        string: "Ahmet Kurt tarafından yapıldı.\n",
        attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .bold),
                     .foregroundColor: NSColor.labelColor])
    credits.append(NSAttributedString(
        string: "Mac için her dosya türüyle çalışan arşiv uygulaması.\nSıkıştır · Aç · Çıkar",
        attributes: [.font: NSFont.systemFont(ofSize: 11),
                     .foregroundColor: NSColor.secondaryLabelColor]))
    let center = NSMutableParagraphStyle()
    center.alignment = .center
    credits.addAttribute(.paragraphStyle, value: center, range: NSRange(location: 0, length: credits.length))

    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "Arşivci",
        .credits: credits,
        NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Ahmet Kurt. Tüm hakları saklıdır."
    ])
    NSApp.activate(ignoringOtherApps: true)
}

// MARK: - Uygulama

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in ArchiveModel.shared.handleOpened(urls) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ArsivciApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var model = ArchiveModel.shared

    var body: some Scene {
        Window("Arşivci", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1060, height: 680)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Arşivci Hakkında") { showAboutPanel() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Arşiv Aç…") { model.chooseArchive() }
                    .keyboardShortcut("o")
                Button("Sıkıştırmak İçin Dosya Ekle…") { model.mode = .compress; model.chooseFilesToAdd() }
                    .keyboardShortcut("n")
            }
        }
    }
}
