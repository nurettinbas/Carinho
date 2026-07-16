import SwiftUI
import UniformTypeIdentifiers

/// Trailhound has no analytics or crash reporting (the app is fully offline), so
/// this is the only way to see what happened on a user's device — e.g. exact
/// CarPlay connect/disconnect timing around a false-stop report. Only shown
/// once Developer Mode is enabled (tap the version number 5 times in Ayarlar).
struct DevLogView: View {
    @State private var lines: [String] = []
    @State private var filter: DevLogCategory?
    @State private var showClearConfirmation = false
    @State private var refreshTask: Task<Void, Never>?

    private var filteredLines: [String] {
        guard let filter else { return lines }
        let tag = "[\(filter.rawValue)]"
        return lines.filter { $0.contains(tag) }
    }

    var body: some View {
        List {
            Section {
                if filteredLines.isEmpty {
                    Text(L10n.string("Henüz kayıt yok. CarPlay/Bluetooth bağlantısı kurup sürmeye başlayınca burada akış görünecek."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(filteredLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(tint(for: line))
                            .textSelection(.enabled)
                    }
                }
            } header: {
                categoryFilterChips
            } footer: {
                Text(L10n.string("Günlük yaklaşık son 2 MB'ı tutar; dışa aktarınca tüm dosyayı gönderirsin."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.string("Geliştirici Günlüğü"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // ShareLink avoids Menu→.sheet races that leave a blank
                    // UIActivityViewController sheet on screen.
                    ShareLink(
                        item: DevLogExportItem(),
                        preview: SharePreview(
                            "trailhound-debug.log",
                            image: Image(systemName: "doc.text")
                        )
                    ) {
                        Label(L10n.string("Dışa Aktar (.log)"), systemImage: "square.and.arrow.up")
                    }
                    Button {
                        reload()
                    } label: {
                        Label(L10n.string("Yenile"), systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label(L10n.string("Günlüğü Temizle"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            L10n.string("Günlüğü temizlemek istediğine emin misin?"),
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Temizle"), role: .destructive) {
                DevLog.shared.clear()
                lines = []
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .onAppear {
            reload()
            startAutoRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: L10n.string("Tümü"), isSelected: filter == nil) {
                    filter = nil
                }
                ForEach(DevLogCategory.allCases, id: \.self) { category in
                    filterChip(title: category.rawValue, isSelected: filter == category) {
                        filter = category
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .textCase(nil)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        lines = DevLog.shared.recentLines(maxCount: 500)
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                reload()
            }
        }
    }

    private func tint(for line: String) -> Color {
        if line.contains("[ERR]") { return .red }
        if line.contains("[WARN]") { return .orange }
        return .primary
    }
}

/// Writes a fresh `trailhound-debug.log` only when the system actually requests
/// the share payload — keeps the Menu action snappy and avoids stale files.
private struct DevLogExportItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { _ in
            let text = DevLog.shared.readAllText()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("trailhound-debug.log")
            try text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}

#Preview {
    NavigationStack { DevLogView() }
}
