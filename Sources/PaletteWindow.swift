import AppKit

final class PalettePanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

final class LogoMarkView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSGradient(colors: [Theme.accentWarm, Theme.accent])?.draw(in: path, angle: -60)
        let bars = [
            NSRect(x: 7, y: 16, width: 12, height: 2.1),
            NSRect(x: 7, y: 12, width: 9, height: 2.1),
            NSRect(x: 7, y: 8, width: 12, height: 2.1),
        ]
        NSColor.white.withAlphaComponent(0.95).setFill()
        for bar in bars {
            NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1).fill()
        }
    }
}

final class SearchBoxView: LayerView, NSTextFieldDelegate {
    let textField = NSTextField()
    private let icon = makeSymbolView("magnifyingglass", size: 12, color: Theme.textTertiary, weight: .medium)
    private let clearButton = NSButton()
    var onTextChange: ((String) -> Void)?

    init() {
        super.init(frame: .zero)
        fill = Theme.field
        radius = 10
        borderColor = Theme.stroke
        borderWidth = 1
        layer?.backgroundColor = fill.cgColor

        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        textField.textColor = Theme.text
        textField.placeholderAttributedString = NSAttributedString(
            string: "搜索标题、分组或内容…",
            attributes: [.foregroundColor: Theme.textTertiary, .font: NSFont.systemFont(ofSize: 12)]
        )
        textField.delegate = self
        textField.cell?.usesSingleLineMode = true

        clearButton.isBordered = false
        clearButton.bezelStyle = .regularSquare
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "清除")
        clearButton.contentTintColor = Theme.textTertiary
        clearButton.target = self
        clearButton.action = #selector(clearText)
        clearButton.isHidden = true

        addSubview(icon)
        addSubview(textField)
        addSubview(clearButton)
        icon.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 13),
            icon.heightAnchor.constraint(equalToConstant: 13),
            textField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 18),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 18),
            clearButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func controlTextDidChange(_ obj: Notification) {
        clearButton.isHidden = textField.stringValue.isEmpty
        borderColor = textField.stringValue.isEmpty ? Theme.stroke : Theme.accent.withAlphaComponent(0.55)
        layer?.borderColor = borderColor.cgColor
        onTextChange?(textField.stringValue)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        borderColor = Theme.accent.withAlphaComponent(0.70)
        layer?.borderColor = borderColor.cgColor
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        borderColor = textField.stringValue.isEmpty ? Theme.stroke : Theme.accent.withAlphaComponent(0.35)
        layer?.borderColor = borderColor.cgColor
    }

    @objc private func clearText() {
        textField.stringValue = ""
        clearButton.isHidden = true
        borderColor = Theme.stroke
        layer?.borderColor = borderColor.cgColor
        onTextChange?("")
        window?.makeFirstResponder(textField)
    }

    func focus() {
        window?.makeFirstResponder(textField)
    }
}

final class ToolbarIconButton: NSButton {
    private var trackingArea: NSTrackingArea?

    init(symbol: String, tooltip: String, size: CGFloat = 13) {
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        contentTintColor = Theme.textSecondary
        self.toolTip = tooltip
        wantsLayer = true
        layer?.cornerRadius = 7
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        image = image?.withSymbolConfiguration(config)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 26).isActive = true
        heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.09).cgColor
        contentTintColor = Theme.text
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
        contentTintColor = Theme.textSecondary
    }
}

final class AccentPillButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private let normalColor = Theme.accent
    private let hoverColor = NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.36, alpha: 1.0)

    init(title: String, symbol: String) {
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = normalColor.cgColor
        font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        contentTintColor = .white
        self.title = "  \(title)"
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        imagePosition = .imageLeading
        attributedTitle = NSAttributedString(string: "  \(title)", attributes: [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        widthAnchor.constraint(equalToConstant: 104).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = hoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = normalColor.cgColor
    }
}

final class CategoryRowView: NSView {
    let id: String
    var onClick: (() -> Void)?
    var selected: Bool = false {
        didSet { applyStyle() }
    }

    private let dot = LayerView()
    private let nameLabel: NSTextField
    private let countLabel: NSTextField
    private var trackingArea: NSTrackingArea?
    private var hovering = false

    init(group: MemoryGroup?, title: String, count: Int, selected: Bool) {
        self.id = group?.id ?? "__all__"
        nameLabel = makeLabel(title, font: NSFont.systemFont(ofSize: 11.5, weight: .medium), color: Theme.textSecondary)
        countLabel = makeLabel("\(count)", font: NSFont.systemFont(ofSize: 9.5, weight: .medium), color: Theme.textTertiary)
        super.init(frame: .zero)
        self.selected = selected
        wantsLayer = true
        layer?.cornerRadius = 8

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        dot.layer?.backgroundColor = categoryColor(for: title).cgColor
        addSubview(dot)
        addSubview(nameLabel)
        addSubview(countLabel)
        dot.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -4),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func categoryColor(for title: String) -> NSColor {
        if title == "全部记忆" { return Theme.accent }
        let palette: [NSColor] = [
            NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.33, alpha: 1),
            NSColor(calibratedRed: 0.45, green: 0.72, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.71, green: 0.58, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.38, green: 0.82, blue: 0.60, alpha: 1),
            NSColor(calibratedRed: 0.94, green: 0.55, blue: 0.80, alpha: 1),
        ]
        var hash = 0
        for scalar in title.unicodeScalars { hash = (hash &* 31 &+ Int(scalar.value)) & 0x7fffffff }
        return palette[hash % palette.count]
    }

    private func applyStyle() {
        if selected {
            layer?.backgroundColor = Theme.accentSoft.cgColor
            nameLabel.textColor = Theme.text
            countLabel.textColor = Theme.accentWarm
        } else {
            layer?.backgroundColor = hovering ? NSColor.white.withAlphaComponent(0.05).cgColor : NSColor.clear.cgColor
            nameLabel.textColor = Theme.textSecondary
            countLabel.textColor = Theme.textTertiary
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        applyStyle()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        applyStyle()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

final class SidebarView: NSScrollView {
    private let doc = FlippedView()
    private var rowViews: [CategoryRowView] = []
    private var headerLabel: NSTextField?
    private let sideInset: CGFloat = 7

    init() {
        super.init(frame: .zero)
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        scrollerStyle = .overlay
        verticalScrollElasticity = .none
        documentView = doc
        doc.autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { fatalError() }

    func rebuild(groups: [MemoryGroup], selectedID: String, totalCount: Int, onSelect: @escaping (String) -> Void) {
        for view in doc.subviews { view.removeFromSuperview() }
        rowViews = []

        let header = makeLabel("记忆库", font: NSFont.systemFont(ofSize: 9, weight: .semibold), color: Theme.textTertiary)
        header.frame = NSRect(x: 14, y: 8, width: 100, height: 14)
        doc.addSubview(header)
        headerLabel = header

        let allRow = CategoryRowView(group: nil, title: "全部记忆", count: totalCount, selected: selectedID == "__all__")
        allRow.onClick = { onSelect("__all__") }
        rowViews.append(allRow)
        doc.addSubview(allRow)

        for group in groups {
            let row = CategoryRowView(group: group, title: group.name, count: group.files.count, selected: selectedID == group.id)
            row.onClick = { onSelect(group.id) }
            rowViews.append(row)
            doc.addSubview(row)
        }
        relayout()
    }

    override func layout() {
        super.layout()
        relayout()
    }

    private func relayout() {
        let width = max(100, contentView.bounds.width - sideInset * 2)
        var y: CGFloat = 30
        for row in rowViews {
            row.frame = NSRect(x: sideInset, y: y, width: width, height: 31)
            y += 33
        }
        doc.frame = NSRect(x: 0, y: 0, width: contentView.bounds.width, height: max(y + 6, contentView.bounds.height))
    }
}

final class PaletteBackgroundView: LayerView {
    let effect = NSVisualEffectView()

    init() {
        super.init(frame: .zero)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true
        addSubview(effect)
        effect.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let tint = LayerView()
        tint.fill = NSColor(calibratedRed: 0.045, green: 0.050, blue: 0.064, alpha: 0.94)
        addSubview(tint)
        tint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tint.leadingAnchor.constraint(equalTo: leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: trailingAnchor),
            tint.topAnchor.constraint(equalTo: topAnchor),
            tint.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class MemoryCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("MemoryCardItem")
    private var card: MemoryCardView?

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 330, height: 92))
        v.wantsLayer = true
        view = v
    }

    func configure(with memory: MemoryFile) {
        card?.removeFromSuperview()
        let card = MemoryCardView(memory: memory)
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.topAnchor.constraint(equalTo: view.topAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.card = card
    }
}

@MainActor
final class PaletteController: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout, NSWindowDelegate {
    let panel: PalettePanel
    private let store: MemoryStore
    private var selectedGroupID = "__all__"
    private var searchQuery = ""
    private var displayedFiles: [MemoryFile] = []

    private let searchBox = SearchBoxView()
    private let sidebar = SidebarView()
    private let collectionView = NSCollectionView()
    private let scrollView = NSScrollView()
    private let emptyView = EmptyListView()
    private let countLabel = makeLabel("", font: NSFont.systemFont(ofSize: 9.5, weight: .medium), color: Theme.textTertiary)
    private let footerHint = makeLabel("拖卡片 · ⌥ 纯文本", font: NSFont.systemFont(ofSize: 9.5, weight: .medium), color: Theme.textTertiary)
    private var toastWorkItem: DispatchWorkItem?

    var selectedCategoryID: String? {
        selectedGroupID == "__all__" ? nil : selectedGroupID
    }

    var onNewMemory: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onChooseWorkspace: (() -> Void)?
    var onRevealWorkspace: (() -> Void)?

    private let panelSize = NSSize(width: 500, height: 570)
    private let sidebarWidth: CGFloat = 140

    init(store: MemoryStore) {
        self.store = store
        panel = PalettePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.hide() }
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentMinSize = panelSize
        panel.contentMaxSize = panelSize
        buildUI()
        reload()
    }

    private func buildUI() {
        let background = PaletteBackgroundView()
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.autoresizingMask = [.width, .height]
        background.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(background)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            background.topAnchor.constraint(equalTo: container.topAnchor),
            background.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            background.widthAnchor.constraint(equalToConstant: panelSize.width),
            background.heightAnchor.constraint(equalToConstant: panelSize.height),
        ])
        panel.contentView = container
        panel.setContentSize(panelSize)

        let header = NSView()
        let logo = LogoMarkView()
        let title = makeLabel("记忆坞", font: NSFont.systemFont(ofSize: 15, weight: .semibold), color: Theme.text)
        let subtitle = makeLabel("拖一张记忆卡到任意 AI", font: NSFont.systemFont(ofSize: 10, weight: .regular), color: Theme.textTertiary)
        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 1

        let closeButton = ToolbarIconButton(symbol: "xmark", tooltip: "关闭")
        closeButton.target = self
        closeButton.action = #selector(closePressed)

        header.addSubview(logo)
        header.addSubview(titleStack)
        header.addSubview(closeButton)
        logo.translatesAutoresizingMaskIntoConstraints = false
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 18),
            logo.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 28),
            logo.heightAnchor.constraint(equalToConstant: 28),
            titleStack.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 10),
            titleStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])

        let separator = LayerView()
        separator.fill = Theme.stroke
        header.addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 18),
            separator.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
        ])

        searchBox.onTextChange = { [weak self] text in
            self?.searchQuery = text
            self?.refreshList()
        }

        // Main body: sidebar + divider + content.
        let body = NSView()
        let sidebarBackground = LayerView()
        sidebarBackground.fill = Theme.sidebar
        sidebarBackground.radius = 12
        body.addSubview(sidebarBackground)
        body.addSubview(sidebar)
        let divider = LayerView()
        divider.fill = Theme.stroke
        body.addSubview(divider)

        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebarBackground.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sidebarBackground.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 8),
            sidebarBackground.topAnchor.constraint(equalTo: body.topAnchor),
            sidebarBackground.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            sidebarBackground.widthAnchor.constraint(equalToConstant: sidebarWidth),
            sidebar.leadingAnchor.constraint(equalTo: sidebarBackground.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: body.topAnchor, constant: 2),
            sidebar.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -2),
            divider.leadingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor, constant: 7),
            divider.topAnchor.constraint(equalTo: body.topAnchor, constant: 8),
            divider.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -8),
            divider.widthAnchor.constraint(equalToConstant: 1),
        ])

        let content = NSView()
        body.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 7),
            content.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: body.topAnchor),
            content.bottomAnchor.constraint(equalTo: body.bottomAnchor),
        ])

        countLabel.alignment = .right
        content.addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            countLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 2),
            countLabel.heightAnchor.constraint(equalToConstant: 14),
        ])

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 326, height: 92)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 9
        layout.sectionInset = NSEdgeInsets(top: 20, left: 0, bottom: 10, right: 0)
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.clear]
        collectionView.wantsLayer = true
        collectionView.register(MemoryCollectionItem.self, forItemWithIdentifier: MemoryCollectionItem.identifier)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = collectionView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            emptyView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            emptyView.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            emptyView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        // Footer.
        let footer = NSView()
        let footerLine = LayerView()
        footerLine.fill = Theme.stroke
        footer.addSubview(footerLine)
        footerLine.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            footerLine.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 18),
            footerLine.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -18),
            footerLine.topAnchor.constraint(equalTo: footer.topAnchor),
            footerLine.heightAnchor.constraint(equalToConstant: 1),
        ])

        let newButton = AccentPillButton(title: "新建记忆", symbol: "plus")
        newButton.target = self
        newButton.action = #selector(newPressed)
        footer.addSubview(newButton)

        let folderButton = ToolbarIconButton(symbol: "folder", tooltip: "在 Finder 中打开工作区")
        folderButton.target = self
        folderButton.action = #selector(folderPressed)
        let settingsButton = ToolbarIconButton(symbol: "gearshape", tooltip: "设置")
        settingsButton.target = self
        settingsButton.action = #selector(settingsPressed)

        footer.addSubview(footerHint)
        footer.addSubview(folderButton)
        footer.addSubview(settingsButton)
        footerHint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 18),
            newButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1),
            settingsButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            settingsButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1),
            folderButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -4),
            folderButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1),
            footerHint.trailingAnchor.constraint(equalTo: folderButton.leadingAnchor, constant: -8),
            footerHint.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1),
        ])

        background.addSubview(header)
        background.addSubview(searchBox)
        background.addSubview(body)
        background.addSubview(footer)
        header.translatesAutoresizingMaskIntoConstraints = false
        searchBox.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        footer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            header.topAnchor.constraint(equalTo: background.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 66),

            searchBox.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            searchBox.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            searchBox.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            searchBox.heightAnchor.constraint(equalToConstant: 36),

            body.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            body.topAnchor.constraint(equalTo: searchBox.bottomAnchor, constant: 12),
            body.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    // MARK: - Data

    private func filesForCurrentSelection() -> [MemoryFile] {
        var files: [MemoryFile]
        if selectedGroupID == "__all__" {
            files = store.allFiles
        } else {
            files = store.groups.first(where: { $0.id == selectedGroupID })?.files ?? []
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            files = files.filter {
                $0.title.localizedCaseInsensitiveContains(q)
                || $0.preview.localizedCaseInsensitiveContains(q)
                || $0.categoryName.localizedCaseInsensitiveContains(q)
                || $0.url.lastPathComponent.localizedCaseInsensitiveContains(q)
            }
        }
        return files
    }

    private func effectiveSelectionID() -> String {
        if selectedGroupID == "__all__" { return selectedGroupID }
        if store.groups.contains(where: { $0.id == selectedGroupID }) { return selectedGroupID }
        selectedGroupID = "__all__"
        return selectedGroupID
    }

    func reload() {
        selectedGroupID = effectiveSelectionID()
        refreshSidebar()
        refreshList()
    }

    private func refreshSidebar() {
        sidebar.rebuild(groups: store.groups, selectedID: selectedGroupID, totalCount: store.totalCount) { [weak self] id in
            guard let self else { return }
            self.selectedGroupID = id
            self.refreshSidebar()
            self.refreshList()
        }
    }

    private func refreshList() {
        displayedFiles = filesForCurrentSelection()
        collectionView.reloadData()
        emptyView.isHidden = !displayedFiles.isEmpty
        countLabel.stringValue = displayedFiles.isEmpty ? "" : "\(displayedFiles.count) 张"
        if displayedFiles.isEmpty {
            let searching = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            emptyView.configure(
                title: searching ? "没有匹配的记忆" : "这里还没有记忆",
                subtitle: searching ? "换个关键词，或切换到全部记忆" : "把 Markdown、TXT 或文档放进工作区分组\n或者点左下角新建一张"
            )
        }
    }

    // MARK: - Collection view

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedFiles.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: MemoryCollectionItem.identifier, for: indexPath) as? MemoryCollectionItem else {
            return NSCollectionViewItem()
        }
        let memory = displayedFiles[indexPath.item]
        item.configure(with: memory)
        if let card = item.view.subviews.compactMap({ $0 as? MemoryCardView }).first {
            card.onOpen = { [weak self] in
                NSWorkspace.shared.open(memory.url)
                self?.hide()
            }
            card.onCopy = { [weak self] in
                guard let self else { return }
                if self.store.copyToPasteboard(memory) {
                    self.showToast("已复制记忆内容")
                }
            }
            card.onReveal = {
                NSWorkspace.shared.activateFileViewerSelecting([memory.url])
            }
            card.onDelete = { [weak self] in
                self?.confirmDelete(memory)
            }
            card.fullTextProvider = { [weak self] in self?.store.fullText(for: memory) }
        }
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        NSSize(width: max(260, collectionView.bounds.width - 2), height: 92)
    }

    // MARK: - Actions

    @objc private func closePressed() { hide() }
    @objc private func newPressed() { onNewMemory?() }
    @objc private func folderPressed() { onRevealWorkspace?() }
    @objc private func settingsPressed() { onOpenSettings?() }

    private func confirmDelete(_ memory: MemoryFile) {
        let alert = NSAlert()
        alert.messageText = "把这张记忆移到废纸篓？"
        alert.informativeText = memory.title
        alert.alertStyle = .warning
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.store.delete(memory) { success in
                if !success { self?.showToast("删除失败") }
            }
        }
    }

    private func showToast(_ text: String) {
        toastWorkItem?.cancel()
        footerHint.stringValue = text
        footerHint.textColor = Theme.accentWarm
        let work = DispatchWorkItem { [weak self] in
            self?.footerHint.stringValue = "拖卡片 · ⌥ 纯文本"
            self?.footerHint.textColor = Theme.textTertiary
        }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    // MARK: - Presentation

    func show(anchor: NSRect) {
        reload()
        position(relativeTo: anchor)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.searchBox.focus()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle(anchor: NSRect) {
        if panel.isVisible {
            hide()
        } else {
            show(anchor: anchor)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func repositionIfVisible(relativeTo anchor: NSRect) {
        guard panel.isVisible else { return }
        position(relativeTo: anchor)
    }

    private func position(relativeTo anchor: NSRect) {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchor) }) ?? NSScreen.main else {
            panel.setFrameOrigin(NSPoint(x: anchor.minX - panelSize.width - 12, y: anchor.minY))
            return
        }
        let visible = screen.visibleFrame
        let preferLeft = anchor.midX > visible.midX
        var x = preferLeft ? anchor.minX - panelSize.width - 12 : anchor.maxX + 12
        x = min(max(x, visible.minX + 8), visible.maxX - panelSize.width - 8)
        var y = anchor.midY - panelSize.height / 2
        y = min(max(y, visible.minY + 8), visible.maxY - panelSize.height - 8)
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Keep the palette visible while dragging to another app; the ball or Esc closes it.
    }
}
