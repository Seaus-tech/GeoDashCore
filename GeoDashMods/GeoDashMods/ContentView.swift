import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class ModsLibrary {
    private(set) var mods: [InstalledMod] = []
    private(set) var isScanning = false
    private(set) var lastScanDate: Date?
    private(set) var scanError: String?
    var selectedFolder: URL?
    var isGameRunning = false

    private let bookmarkKey = "modsFolderBookmark"

    init() {
        restoreSelectedFolder()
        refresh()
    }

    var scanLocationDescription: String {
        selectedFolder?.path(percentEncoded: false) ?? "Default Geode locations"
    }

    func refresh() {
        isGameRunning = Self.geometryDashIsRunning()
        scanInstalledMods()
    }

    func setSelectedFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            scanError = "GeoDashMods does not have permission to read this folder."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            selectedFolder = url
            scanInstalledMods()
        } catch {
            scanError = "The selected folder could not be saved: (error.localizedDescription)"
        }
    }

    func useDefaultLocations() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        selectedFolder = nil
        scanInstalledMods()
    }

    private func restoreSelectedFolder() {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return
        }

        do {
            var isStale = false
            let folder = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            selectedFolder = folder

            if isStale {
                setSelectedFolder(folder)
            }
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            scanError = "The saved mods folder is no longer available."
        }
    }

    private func scanInstalledMods() {
        isScanning = true
        scanError = nil
        defer {
            lastScanDate = .now
            isScanning = false
        }

        let folders = selectedFolder.map { [$0] } ?? Self.defaultModsFolders()
        var discoveredMods: [InstalledMod] = []
        var scannedFolder = false

        for folder in folders {
            let needsScopedAccess = selectedFolder == folder
            if needsScopedAccess && !folder.startAccessingSecurityScopedResource() {
                continue
            }
            defer {
                if needsScopedAccess {
                    folder.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            scannedFolder = true
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                discoveredMods.append(contentsOf: urls.compactMap(InstalledMod.init(url:)))
            } catch {
                scanError = "Couldn’t read (folder.lastPathComponent): (error.localizedDescription)"
            }
        }

        mods = discoveredMods.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        if !scannedFolder && selectedFolder == nil {
            scanError = "No Geode mods folder was found. Choose your mods folder to get started."
        }
    }

    private static func defaultModsFolders() -> [URL] {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return [
            library.appending(path: "Application Support/Geode/mods"),
            library.appending(path: "Application Support/GeometryDash/geode/mods")
        ]
    }

    private static func geometryDashIsRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier == "com.robtop.geometrydash"
                || application.localizedName?.localizedCaseInsensitiveContains("geometry dash") == true
        }
    }
}

struct InstalledMod: Identifiable, Equatable {
    let url: URL
    let name: String
    let modifiedDate: Date?
    let fileSize: Int64

    var id: URL { url }

    init?(url: URL) {
        guard ["geode", "zip"].contains(url.pathExtension.lowercased()) else {
            return nil
        }

        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey])
        guard values?.isRegularFile != false else {
            return nil
        }

        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.modifiedDate = values?.contentModificationDate
        self.fileSize = Int64(values?.fileSize ?? 0)
    }
}

struct ContentView: View {
    @State private var library = ModsLibrary()
    @State private var selection: SidebarItem? = .dashboard
    @State private var isImportingFolder = false

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection, modCount: library.mods.count)
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView(
                        library: library,
                        chooseFolder: { isImportingFolder = true }
                    )
                case .mods:
                    ModsListView(mods: library.mods, scanLocation: library.scanLocationDescription)
                case .settings:
                    SettingsView(
                        scanLocation: library.scanLocationDescription,
                        hasSelectedFolder: library.selectedFolder != nil,
                        chooseFolder: { isImportingFolder = true },
                        useDefaultLocations: library.useDefaultLocations
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        library.refresh()
                    } label: {
                        Label("Refresh Mods", systemImage: "arrow.clockwise")
                    }
                    .disabled(library.isScanning)

                    Button {
                        isImportingFolder = true
                    } label: {
                        Label("Choose Folder", systemImage: "folder")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                library.setSelectedFolder(url)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private enum SidebarItem: Hashable {
    case dashboard
    case mods
    case settings
}

private struct Sidebar: View {
    @Binding var selection: SidebarItem?
    let modCount: Int

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Overview", systemImage: "rectangle.grid.1x2")
                    .tag(SidebarItem.dashboard)
                Label("Installed Mods", systemImage: "puzzlepiece.extension")
                    .tag(SidebarItem.mods)
            }

            Section("Settings") {
                Label("Locations", systemImage: "folder.badge.gearshape")
                    .tag(SidebarItem.settings)
            }
        }
        .navigationTitle("GeoDashMods")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: "puzzlepiece.extension")
                Text("\(modCount) installed")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

private struct DashboardView: View {
    let library: ModsLibrary
    let chooseFolder: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DashboardHeader(
                    isGameRunning: library.isGameRunning,
                    modCount: library.mods.count
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Mod Library", systemImage: "folder")
                            .font(.headline)
                        Text(library.scanLocationDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        HStack {
                            if library.isScanning {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Scanning…")
                            } else if let date = library.lastScanDate {
                                Text("Last checked \(date.formatted(.relative(presentation: .named)))")
                            } else {
                                Text("Not scanned yet")
                            }
                            Spacer()
                            Button("Choose Folder", action: chooseFolder)
                        }
                        .font(.callout)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                if let scanError = library.scanError {
                    ContentUnavailableView(
                        "Mods Folder Unavailable",
                        systemImage: "folder.badge.questionmark",
                        description: Text(scanError)
                    )
                } else if library.mods.isEmpty {
                    ContentUnavailableView(
                        "No Mods Found",
                        systemImage: "puzzlepiece.extension",
                        description: Text("GeoDashMods will show .geode files in your selected folder.")
                    )
                } else {
                    ModsSection(mods: library.mods)
                }
            }
            .padding(24)
        }
        .navigationTitle("Overview")
    }
}

private struct DashboardHeader: View {
    let isGameRunning: Bool
    let modCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your mod library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(modCount == 1 ? "1 mod available" : "(modCount) mods available")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(
                isGameRunning ? "Geometry Dash Running" : "Geometry Dash Not Running",
                systemImage: isGameRunning ? "checkmark.circle.fill" : "circle"
            )
            .foregroundStyle(isGameRunning ? .green : .secondary)
        }
    }
}

private struct ModsSection: View {
    let mods: [InstalledMod]

    var body: some View {
        GroupBox {
            LazyVStack(spacing: 0) {
                ForEach(mods) { mod in
                    ModRow(mod: mod)
                    if mod.id != mods.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text("Installed Mods")
        }
    }
}

private struct ModsListView: View {
    let mods: [InstalledMod]
    let scanLocation: String

    var body: some View {
        Group {
            if mods.isEmpty {
                ContentUnavailableView(
                    "No Mods Found",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Select a folder containing your Geode mods.")
                )
            } else {
                List(mods) { mod in
                    ModRow(mod: mod)
                }
            }
        }
        .navigationTitle("Installed Mods")
        .safeAreaInset(edge: .bottom) {
            Text(scanLocation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.bar)
        }
    }
}

private struct ModRow: View {
    let mod: InstalledMod

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(mod.name)
                    .fontWeight(.medium)
                if let date = mod.modifiedDate {
                    Text("Modified \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: mod.fileSize, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

private struct SettingsView: View {
    let scanLocation: String
    let hasSelectedFolder: Bool
    let chooseFolder: () -> Void
    let useDefaultLocations: () -> Void

    var body: some View {
        Form {
            Section("Mods Folder") {
                LabeledContent("Current location") {
                    Text(scanLocation)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }

                Button("Choose Mods Folder…", action: chooseFolder)

                if hasSelectedFolder {
                    Button("Use Default Locations", action: useDefaultLocations)
                }
            }

            Section {
                Text("GeoDashMods scans .geode and .zip files. Choose the folder that contains the mods managed by Geode.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Locations")
    }
}

#Preview {
    ContentView()
}
