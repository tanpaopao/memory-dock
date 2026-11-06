import AppKit

enum Theme {
    static let accent = NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.30, alpha: 1.0)
    static let accentWarm = NSColor(calibratedRed: 1.00, green: 0.64, blue: 0.25, alpha: 1.0)
    static let accentSoft = NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.34, alpha: 0.16)

    static let panel = NSColor(calibratedRed: 0.055, green: 0.060, blue: 0.075, alpha: 0.86)
    static let sidebar = NSColor(calibratedRed: 0.025, green: 0.029, blue: 0.039, alpha: 0.72)
    static let card = NSColor(calibratedWhite: 1.0, alpha: 0.075)
    static let cardHover = NSColor(calibratedWhite: 1.0, alpha: 0.115)
    static let cardSelected = NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.34, alpha: 0.13)
    static let stroke = NSColor(calibratedWhite: 1.0, alpha: 0.085)
    static let strokeStrong = NSColor(calibratedWhite: 1.0, alpha: 0.16)
    static let text = NSColor(calibratedWhite: 0.97, alpha: 1.0)
    static let textSecondary = NSColor(calibratedWhite: 0.72, alpha: 1.0)
    static let textTertiary = NSColor(calibratedWhite: 0.50, alpha: 1.0)
    static let field = NSColor(calibratedWhite: 1.0, alpha: 0.07)

    static let titleFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let bodyFont = NSFont.systemFont(ofSize: 12.5, weight: .regular)
    static let smallFont = NSFont.systemFont(ofSize: 10.5, weight: .medium)

    static func color(for ext: String) -> NSColor {
        switch ext.lowercased() {
        case "md", "markdown", "mdown": return NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.34, alpha: 1)
        case "txt", "text", "rtf": return NSColor(calibratedRed: 0.44, green: 0.72, blue: 1.0, alpha: 1)
        case "json", "yaml", "yml", "plist", "xml": return NSColor(calibratedRed: 0.72, green: 0.58, blue: 1.0, alpha: 1)
        case "pdf": return NSColor(calibratedRed: 1.0, green: 0.37, blue: 0.42, alpha: 1)
        case "doc", "docx", "pages": return NSColor(calibratedRed: 0.40, green: 0.62, blue: 1.0, alpha: 1)
        case "csv", "xls", "xlsx", "numbers": return NSColor(calibratedRed: 0.38, green: 0.82, blue: 0.58, alpha: 1)
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return NSColor(calibratedRed: 0.95, green: 0.58, blue: 0.82, alpha: 1)
        default: return NSColor(calibratedWhite: 0.72, alpha: 1)
        }
    }

    static func symbol(for ext: String) -> String {
        switch ext.lowercased() {
        case "md", "markdown", "mdown", "txt", "text", "rtf": return "text.alignleft"
        case "json", "yaml", "yml", "plist", "xml": return "chevron.left.forwardslash.chevron.right"
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx", "pages": return "doc.text.fill"
        case "csv", "xls", "xlsx", "numbers": return "tablecells.fill"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }

    static func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            calibratedRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class LayerView: NSView {
    var fill: NSColor = .clear { didSet { layer?.backgroundColor = fill.cgColor } }
    var radius: CGFloat = 0 { didSet { layer?.cornerRadius = radius } }
    var borderColor: NSColor = .clear { didSet { layer?.borderColor = borderColor.cgColor } }
    var borderWidth: CGFloat = 0 { didSet { layer?.borderWidth = borderWidth } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = fill.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }
}

func makeLabel(_ text: String, font: NSFont, color: NSColor = Theme.text, lines: Int = 1) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = font
    label.textColor = color
    label.lineBreakMode = .byTruncatingTail
    label.maximumNumberOfLines = lines
    label.cell?.wraps = lines > 1
    label.cell?.isScrollable = false
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return label
}

func makeSymbolView(_ name: String, size: CGFloat, color: NSColor, weight: NSFont.Weight = .medium) -> NSImageView {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    let view = NSImageView(image: image ?? NSImage())
    view.contentTintColor = color
    view.imageScaling = .scaleProportionallyUpOrDown
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

func formatRelativeDate(_ date: Date) -> String {
    let seconds = max(0, Date().timeIntervalSince(date))
    if seconds < 60 { return "刚刚" }
    if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
    if seconds < 86_400 { return "\(Int(seconds / 3600)) 小时前" }
    if seconds < 172_800 { return "昨天" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M月d日"
    return f.string(from: date)
}
