import AppKit

@MainActor
final class MemoryCardView: NSView, NSDraggingSource {
    let memory: MemoryFile
    var onOpen: (() -> Void)?
    var onCopy: (() -> Void)?
    var onReveal: (() -> Void)?
    var onDelete: (() -> Void)?
    var fullTextProvider: (() -> String?)?

    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var mouseDownPoint: NSPoint = .zero
    private var didDrag = false
    private var dragStarted = false

    private let iconBackground = LayerView()
    private let iconView: NSImageView
    private let titleLabel: NSTextField
    private let previewLabel: NSTextField
    private let metaLabel: NSTextField
    private let gripView: NSImageView

    init(memory: MemoryFile) {
        self.memory = memory
        iconView = makeSymbolView(memory.icon, size: 17, color: memory.tint, weight: .semibold)
        titleLabel = makeLabel(memory.title, font: NSFont.systemFont(ofSize: 13, weight: .semibold), color: Theme.text)
        previewLabel = makeLabel(memory.preview, font: NSFont.systemFont(ofSize: 11, weight: .regular), color: Theme.textSecondary, lines: 2)
        metaLabel = makeLabel(
            "\(memory.categoryName)  ·  \(formatRelativeDate(memory.modified))  ·  \(memory.kindName)",
            font: NSFont.systemFont(ofSize: 9.5, weight: .medium),
            color: Theme.textTertiary
        )
        gripView = makeSymbolView("line.3.horizontal", size: 10, color: Theme.textTertiary.withAlphaComponent(0.7), weight: .semibold)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = Theme.card.cgColor
        layer?.borderColor = Theme.stroke.cgColor
        layer?.borderWidth = 1
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.16
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        iconBackground.wantsLayer = true
        iconBackground.layer?.cornerRadius = 10
        iconBackground.layer?.backgroundColor = memory.tint.withAlphaComponent(0.13).cgColor
        iconBackground.layer?.borderColor = memory.tint.withAlphaComponent(0.22).cgColor
        iconBackground.layer?.borderWidth = 0.8

        addSubview(iconBackground)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(previewLabel)
        addSubview(metaLabel)
        addSubview(gripView)

        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        gripView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            iconBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 40),
            iconBackground.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),

            previewLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            previewLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            previewLabel.bottomAnchor.constraint(lessThanOrEqualTo: metaLabel.topAnchor, constant: -3),

            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            gripView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            gripView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            gripView.widthAnchor.constraint(equalToConstant: 12),
            gripView.heightAnchor.constraint(equalToConstant: 12),
        ])

        setAccessibilityRole(.button)
        setAccessibilityLabel("记忆：\(memory.title)")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isHovering ? .openHand : .arrow)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        layer?.backgroundColor = Theme.cardHover.cgColor
        layer?.borderColor = Theme.strokeStrong.cgColor
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        layer?.backgroundColor = Theme.card.cgColor
        layer?.borderColor = Theme.stroke.cgColor
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didDrag = false
        dragStarted = false
        if event.clickCount == 2 {
            onOpen?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted else { return }
        let p = convert(event.locationInWindow, from: nil)
        let distance = hypot(p.x - mouseDownPoint.x, p.y - mouseDownPoint.y)
        guard distance > 4 else { return }
        didDrag = true
        dragStarted = true
        startDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        // Double-click is handled in mouseDown. A single click keeps the card calm.
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.addItem(menuItem("用默认应用打开", action: #selector(menuOpen)))
        menu.addItem(menuItem("复制记忆内容", action: #selector(menuCopy)))
        menu.addItem(menuItem("在 Finder 中显示", action: #selector(menuReveal)))
        menu.addItem(.separator())
        menu.addItem(menuItem("移到废纸篓…", action: #selector(menuDelete)))
        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func menuOpen() { onOpen?() }
    @objc private func menuCopy() { onCopy?() }
    @objc private func menuReveal() { onReveal?() }
    @objc private func menuDelete() { onDelete?() }

    private func startDrag(with event: NSEvent) {
        let dragAsTextByDefault = UserDefaults.standard.bool(forKey: "MemoryDock.dragAsText")
        let optionPressed = event.modifierFlags.contains(.option)
        let useText = dragAsTextByDefault != optionPressed

        let draggingItem: NSDraggingItem
        if useText, let text = fullTextProvider?() {
            let pbItem = NSPasteboardItem()
            pbItem.setString(text, forType: .string)
            draggingItem = NSDraggingItem(pasteboardWriter: pbItem)
        } else {
            draggingItem = NSDraggingItem(pasteboardWriter: memory.url as NSURL)
        }

        let image = snapshotImage()
        let frame = NSRect(x: 0, y: 0, width: max(bounds.width, 260), height: bounds.height)
        draggingItem.setDraggingFrame(frame, contents: image)
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .stack
    }

    private func snapshotImage() -> NSImage {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return NSImage(size: NSSize(width: 260, height: 88)) }
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return NSImage(size: size) }
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    }
}

final class EmptyListView: NSView {
    private let iconView = makeSymbolView("rectangle.stack.badge.plus", size: 28, color: Theme.textTertiary, weight: .regular)
    private let titleLabel = makeLabel("这里还没有记忆", font: NSFont.systemFont(ofSize: 13, weight: .semibold), color: Theme.textSecondary)
    private let subtitleLabel = makeLabel("把 Markdown、TXT 或文档放进工作区分组\n或者点左下角新建一张", font: NSFont.systemFont(ofSize: 10.5), color: Theme.textTertiary, lines: 2)

    init() {
        super.init(frame: .zero)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        subtitleLabel.alignment = .center
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -44),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
    }
}
