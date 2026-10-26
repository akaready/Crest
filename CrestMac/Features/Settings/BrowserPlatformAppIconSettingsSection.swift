import SwiftUI
import UniformTypeIdentifiers

struct BrowserPlatformAppIconSettingsSection: View {
    @AppStorage(BrowserMacAppIconAssets.preferenceKey, store: BrowserMacDockTile.shared.defaults)
    private var selectedName = ""
    @AppStorage(BrowserMacAppIconAssets.customImageKey, store: BrowserMacDockTile.shared.defaults)
    private var customImageData: Data?
    @State private var showsError = false
    @State private var isChoosingImage = false
    @State private var appearanceRevision = 0
    @State private var appearanceObserver: BrowserMacAppIconAppearanceObserver?

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
                customChoice
            }
            .padding(.vertical, 8)
            HStack {
                Button("Choose Image…") { isChoosingImage = true }
                if customImageData != nil {
                    Button("Remove Custom Icon") { BrowserMacDockTile.shared.removeCustomImage() }
                }
            }
        }
        .onAppear {
            appearanceObserver = BrowserMacAppIconAppearanceObserver { appearanceRevision += 1 }
        }
        .onDisappear {
            appearanceObserver?.stop()
            appearanceObserver = nil
        }
        .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                showsError = !BrowserMacDockTile.shared.chooseCustomImage(at: url)
            }
        }
        .alert("Couldn’t change app icon", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Crest could not load this icon. Please try again.")
        }
    }

    private var resettable: CrestResettableSetting {
        CrestResettableSetting(title: "App icon", isDefault: selectedName.isEmpty) {
            showsError = !BrowserMacDockTile.shared.select("")
        }
    }

    private func iconChoice(name: String, title: LocalizedStringResource) -> some View {
        choice(name: name, title: title) {
            BrowserMacDockTile.shared.select(name)
        } artwork: {
            Image(
                nsImage: name.isEmpty
                    ? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
                    : BrowserMacAppIconAssets.image(named: name, in: .main) ?? NSImage()
            )
            .resizable().scaledToFit()
        }
    }

    /// The picture the person chose, or a plus that asks for one.
    private var customChoice: some View {
        let name = BrowserMacAppIconAssets.customName
        let image = BrowserMacAppIconAssets.customImage(in: BrowserMacDockTile.shared.defaults)
        return choice(name: name, title: "Custom") {
            if image == nil {
                isChoosingImage = true
                return true
            }
            return BrowserMacDockTile.shared.select(name)
        } artwork: {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "plus")
                    .font(.title2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
    }

    /// One tile of the grid. `select` returns false when the icon could not be picked.
    private func choice(
        name: String, title: LocalizedStringResource, select: @escaping () -> Bool,
        @ViewBuilder artwork: () -> some View
    ) -> some View {
        Button {
            showsError = !select()
        } label: {
            VStack(spacing: 6) {
                artwork()
                    .id(appearanceRevision)
                    .frame(width: 58, height: 58)
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
