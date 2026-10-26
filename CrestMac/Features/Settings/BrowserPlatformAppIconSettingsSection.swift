import SwiftUI
import UniformTypeIdentifiers

struct BrowserPlatformAppIconSettingsSection: View {
    /// The side of an icon tile. A macOS icon's artwork fills 824 of the 1024 points of its canvas.
    private static let tileSide: CGFloat = 58
    private static let artworkSide = tileSide * 824 / 1024

    @AppStorage(BrowserMacAppIconAssets.preferenceKey, store: BrowserMacDockTile.shared.defaults)
    private var selectedName = ""
    @AppStorage(BrowserMacAppIconAssets.customImageKey, store: BrowserMacDockTile.shared.defaults)
    private var customImageData: Data?
    @State private var showsError = false
    @State private var errorMessage = Self.genericError
    @State private var isChoosingImage = false
    @State private var isHoveringCustom = false
    @State private var appearanceRevision = 0
    @State private var appearanceObserver: BrowserMacAppIconAppearanceObserver?

    private static let genericError: LocalizedStringResource = "Crest could not load this icon. Please try again."

    var body: some View {
        CrestSettingsGroup(
            "App icon",
            settings: [resettable]
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 12)], spacing: 16) {
                iconChoice(name: "", title: "Crest")
                ForEach(SpaceHouse.all, id: \.self) { house in
                    iconChoice(name: house.appIconName, title: house.title)
                }
            }
            .padding(.top, 8)
            customRow
        }
        .onAppear {
            appearanceObserver = BrowserMacAppIconAppearanceObserver { appearanceRevision += 1 }
        }
        .onDisappear {
            appearanceObserver?.stop()
            appearanceObserver = nil
        }
        .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try BrowserMacDockTile.shared.chooseCustomImage(at: url)
            } catch let rejection as BrowserMacCustomAppIcon.Rejection {
                report(rejection.message)
            } catch {
                report(Self.genericError)
            }
        }
        .alert("Couldn’t change app icon", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var resettable: CrestResettableSetting {
        CrestResettableSetting(title: "App icon", isDefault: selectedName.isEmpty) {
            BrowserMacDockTile.shared.resetIcon()
        }
    }

    private func report(_ message: LocalizedStringResource) {
        errorMessage = message
        showsError = true
    }

    private func iconChoice(name: String, title: LocalizedStringResource) -> some View {
        choice(name: name, title: title) {
            if !BrowserMacDockTile.shared.select(name) { report(Self.genericError) }
        } artwork: {
            Image(
                nsImage: name.isEmpty
                    ? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
                    : BrowserMacAppIconAssets.image(named: name, in: .main) ?? NSImage()
            )
            .resizable().scaledToFit()
        }
    }

    /// The custom icon beside what it takes: its tile picks it, once there is a picture, and the buttons
    /// choose, replace or remove that picture.
    private var customRow: some View {
        let image = customImageData.flatMap(NSImage.init(data:))
        return HStack(spacing: 12) {
            choice(name: BrowserMacAppIconAssets.customName, title: "Custom") {
                if image == nil {
                    isChoosingImage = true
                } else if !BrowserMacDockTile.shared.select(BrowserMacAppIconAssets.customName) {
                    report(Self.genericError)
                }
            } artwork: {
                if let image {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    emptyIcon
                }
            }
            .onHover { isHoveringCustom = $0 }
            .frame(width: 78)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(image == nil ? "Choose Image…" : "Replace Image…") { isChoosingImage = true }
                    if image != nil {
                        Button("Remove") { BrowserMacDockTile.shared.removeCustomImage() }
                    }
                }
                Text("A square PNG, 512 × 512 pixels or larger. One with square corners gets the macOS icon shape.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// An icon's shape with a plus in it, at the size the other icons' artwork has within their tiles.
    private var emptyIcon: some View {
        let shape = RoundedRectangle(cornerRadius: Self.artworkSide * 0.2237, style: .continuous)
        return
            shape
            .fill(isHoveringCustom ? HierarchicalShapeStyle.tertiary : .quaternary)
            .overlay { shape.strokeBorder(.separator, lineWidth: 0.5) }
            .overlay {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(isHoveringCustom ? .primary : .secondary)
            }
            .frame(width: Self.artworkSide, height: Self.artworkSide)
            .frame(width: Self.tileSide, height: Self.tileSide)
    }

    /// One tile of the grid. `select` picks the icon, or reports why it could not.
    private func choice(
        name: String, title: LocalizedStringResource, select: @escaping () -> Void,
        @ViewBuilder artwork: () -> some View
    ) -> some View {
        Button(action: select) {
            VStack(spacing: 6) {
                artwork()
                    .id(appearanceRevision)
                    .frame(width: Self.tileSide, height: Self.tileSide)
                    .clipShape(.rect(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(selectedName == name ? Color.accentColor : .clear, lineWidth: 3)
                    }
                Text(title).font(.caption).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedName == name ? .isSelected : [])
        .accessibilityIdentifier("app-icon-" + (name.isEmpty ? "default" : name))
    }
}
