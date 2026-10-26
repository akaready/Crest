import AppKit

/// A picture the person chose as Crest's icon, checked and prepared to keep.
/// Only the app makes one; the Dock tile plug-in reads the PNG that is kept.
///
/// The picture must be square and at least `minimumSide` pixels, and is kept
/// at no more than `maximumSide`. A picture with transparent corners is
/// finished artwork and is kept as it is. One that fills its corners is given
/// the macOS icon shape and margin, because the Dock does not round an icon.
struct BrowserMacCustomAppIcon {
    // MARK: - Types

    /// Why a file cannot be the icon.
    struct Rejection: Error {
        let message: LocalizedStringResource

        static let unreadable = Rejection(message: "Crest could not read this file as an image.")
        static let tooLarge = Rejection(message: "Choose an image file under 25 MB.")
        static let notSquare = Rejection(message: "Choose a square image.")
        static let tooSmall = Rejection(message: "Choose an image at least 256 × 256 pixels.")
    }

    // MARK: - Static Variables

    static let maximumFileBytes = 25_000_000
    static let minimumSide = 256
    /// Covers the largest Dock tile on a Retina display.
    static let maximumSide = 512
    /// The macOS icon grid: the shape fills 824 of 1024 points, with corners of about 22.4% of its width.
    private static let shapeFraction = 824.0 / 1024.0
    private static let cornerFraction = 0.2237

    // MARK: - Variables

    /// The PNG to keep.
    let png: Data

    // MARK: - Initializers

    /// Reads the picture at `url`, or throws the `Rejection` that says why it cannot be the icon.
    init(contentsOf url: URL) throws {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard bytes <= Self.maximumFileBytes else { throw Rejection.tooLarge }
        guard let image = NSImage(contentsOf: url), let pixels = Self.pixelSize(of: image) else {
            throw Rejection.unreadable
        }
        guard pixels.width == pixels.height else { throw Rejection.notSquare }
        guard pixels.width >= Self.minimumSide else { throw Rejection.tooSmall }
        let side = min(pixels.width, Self.maximumSide)
        var bitmap = Self.render(image, side: side, shaped: false)
        if let flat = bitmap, Self.fillsCorners(flat) { bitmap = Self.render(image, side: side, shaped: true) }
        guard let png = bitmap?.representation(using: .png, properties: [:]) else { throw Rejection.unreadable }
        self.png = png
    }

    // MARK: - Actions - Reading

    /// The pixels of `image`'s largest representation. A picture with no pixels of its own, such as a PDF, has
    /// the size it draws at.
    private static func pixelSize(of image: NSImage) -> (width: Int, height: Int)? {
        let representations = image.representations
        var width = representations.map(\.pixelsWide).max() ?? 0
        var height = representations.map(\.pixelsHigh).max() ?? 0
        if width <= 0 || height <= 0 {
            width = Int(image.size.width.rounded())
            height = Int(image.size.height.rounded())
        }
        return width > 0 && height > 0 ? (width, height) : nil
    }

    /// Whether all four corners of `bitmap` are opaque.
    private static func fillsCorners(_ bitmap: NSBitmapImageRep) -> Bool {
        let last = bitmap.pixelsWide - 1
        return [(0, 0), (last, 0), (0, last), (last, last)].allSatisfy {
            (bitmap.colorAt(x: $0.0, y: $0.1)?.alphaComponent ?? 0) > 0.99
        }
    }

    // MARK: - Actions - Drawing

    /// `image` drawn into a transparent square of `side` pixels, either filling it or, when `shaped`, inside the
    /// macOS icon shape and margin.
    private static func render(_ image: NSImage, side: Int, shaped: Bool) -> NSBitmapImageRep? {
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let full = CGFloat(side)
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: full, height: full).fill(using: .copy)
        let inset = shaped ? full * (1 - shapeFraction) / 2 : 0
        let rect = NSRect(x: inset, y: inset, width: full - 2 * inset, height: full - 2 * inset)
        if shaped {
            let radius = rect.width * cornerFraction
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
        }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        return bitmap
    }
}
