import AppKit

final class DialogPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

final class SoftPillButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private let normal = NSColor.white.withAlphaComponent(0.08)
    private let hover = NSColor.white.withAlphaComponent(0.14)

    init(title: String) {
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = normal.cgColor
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.86),
        ])
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        widthAnchor.constraint(equalToConstant: 74).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = hover.cgColor }
    override func mouseExited(with event: NSEvent) { layer?.backgroundColor = normal.cgColor }
}

final class DialogBackgroundView: NSView {
    let panel = LayerView()
    let titleLabel: NSTextField
    let subtitleLabel: NSTextField

    init(title: String, subtitle: String) {
        titleLabel = makeLabel(title, font: NSFont.systemFont(ofSize: 16, weight: .semibold), color: Theme.text)
        subtitleLabel = makeLabel(subtitle, font: NSFont.systemFont(ofSize: 10.5), color: Theme.textTertiary, lines: 2)
        super.init(frame: .zero)
        wantsLayer = true
        panel.fill = Theme.panel.withAlphaComponent(0.97)
        panel.radius = 16
        panel.borderColor = NSColor.white.withAlphaComponent(0.12)
        panel.borderWidth = 1
        addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        panel.addSubview(titleLabel)
        panel.addSubview(subtitleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 22),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class FormLabel: NSTextField {
    init(_ text: String) {
        super.init(frame: .zero)
        stringValue = text
        font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        textColor = Theme.textTertiary
        isEditable = false
        isBordered = false
        drawsBackground = false
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class PassthroughLabel: NSTextField {
    init(_ text: String, font: NSFont) {
        super.init(frame: .zero)
        stringValue = text
        self.font = font
        textColor = Theme.textTertiary.withAlphaComponent(0.8)
        isEditable = false
        isBordered = false
        drawsBackground = false
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class ComposeController: NSObject, NSTextFieldDelegate, NSTextViewDelegate {
    private let store: MemoryStore
    private let panel: DialogPanel
    private let background: DialogBackgroundView
    private let titleField = NSTextField()
    private let categoryPopup = NSPopUpButton()
    private let textView = NSTextView()
    private let scroll = NSScrollView()
    private let placeholderLabel = PassthroughLabel("写下这张记忆卡的背景、规则或示例…", font: NSFont.systemFont(ofSize: 12, weight: .regular))
    private let saveButton: AccentPillButton
    private var categoryIDs: [String] = []
    private var preferredCategoryID: String?
    var onSaved: (() -> Void)?

    override init() {
        fatalError("Use init(store:)")
    }

    init(store: MemoryStore) {
        self.store = store
        background = DialogBackgroundView(title: "新建记忆", subtitle: "写成一张可以随时拖给 AI 的记忆卡")
        saveButton = AccentPillButton(title: "保存记忆", symbol: "checkmark")
        panel = DialogPanel(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 430),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.onEscape = { [weak self] in self?.hide() }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 470, height: 430))
        container.autoresizingMask = [.width, .height]
        background.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(background)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            background.topAnchor.constraint(equalTo: container.topAnchor),
            background.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            background.widthAnchor.constraint(equalToConstant: 470),
            background.heightAnchor.constraint(equalToConstant: 430),
        ])
        panel.contentView = container
        panel.setContentSize(NSSize(width: 470, height: 430))

        let titleLabel = FormLabel("标题")
        titleField.isBezeled = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = Theme.text
        titleField.placeholderAttributedString = NSAttributedString(string: "例如：项目背景与约束", attributes: [
            .foregroundColor: Theme.textTertiary,
            .font: NSFont.systemFont(ofSize: 13),
        ])
        titleField.delegate = self

        let titleBox = LayerView()
        titleBox.fill = Theme.field
        titleBox.radius = 9
        titleBox.borderColor = Theme.stroke
        titleBox.borderWidth = 1
        titleBox.addSubview(titleField)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: titleBox.leadingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: titleBox.trailingAnchor, constant: -12),
            titleField.centerYAnchor.constraint(equalTo: titleBox.centerYAnchor),
            titleField.heightAnchor.constraint(equalToConstant: 20),
        ])

        let categoryLabel = FormLabel("分组")
        categoryPopup.isBordered = false
        categoryPopup.bezelStyle = .regularSquare
        categoryPopup.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        categoryPopup.contentTintColor = Theme.text
        categoryPopup.wantsLayer = true
        categoryPopup.layer?.backgroundColor = Theme.field.cgColor
        categoryPopup.layer?.cornerRadius = 9
        categoryPopup.layer?.borderColor = Theme.stroke.cgColor
        categoryPopup.layer?.borderWidth = 1

        let contentLabel = FormLabel("内容")
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        textView.textColor = Theme.text
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.insertionPointColor = Theme.accent
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: 422, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 422, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: 422, height: 160)

        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.contentView.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let contentBox = LayerView()
        contentBox.fill = NSColor.white.withAlphaComponent(0.065)
        contentBox.radius = 10
        contentBox.borderColor = NSColor.white.withAlphaComponent(0.17)
        contentBox.borderWidth = 1
        contentBox.translatesAutoresizingMaskIntoConstraints = false
        contentBox.addSubview(scroll)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentBox.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: 13),
            placeholderLabel.topAnchor.constraint(equalTo: contentBox.topAnchor, constant: 10),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentBox.trailingAnchor, constant: -13),
        ])

        let cancelButton = SoftPillButton(title: "取消")
        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)
        saveButton.target = self
        saveButton.action = #selector(savePressed)

        for view in [titleLabel, titleBox, categoryLabel, categoryPopup, contentLabel, contentBox, cancelButton, saveButton] {
            background.panel.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: 1),
            scroll.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -1),
            scroll.topAnchor.constraint(equalTo: contentBox.topAnchor, constant: 1),
            scroll.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -1),
        ])

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: background.panel.leadingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: background.panel.topAnchor, constant: 84),
            titleBox.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            titleBox.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            titleBox.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            titleBox.heightAnchor.constraint(equalToConstant: 38),

            categoryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            categoryLabel.topAnchor.constraint(equalTo: titleBox.bottomAnchor, constant: 13),
            categoryPopup.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            categoryPopup.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 6),
            categoryPopup.widthAnchor.constraint(equalToConstant: 190),
            categoryPopup.heightAnchor.constraint(equalToConstant: 30),

            contentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentLabel.topAnchor.constraint(equalTo: categoryPopup.bottomAnchor, constant: 13),
            contentBox.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentBox.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            contentBox.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 6),
            contentBox.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: background.panel.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            saveButton.bottomAnchor.constraint(equalTo: background.panel.bottomAnchor, constant: -20),
        ])
    }

    func show(relativeTo anchor: NSRect, preferredCategoryID: String?) {
        self.preferredCategoryID = preferredCategoryID
        titleField.stringValue = ""
        textView.string = ""
        placeholderLabel.isHidden = false
        categoryPopup.removeAllItems()
        categoryIDs = []
        for group in store.groups where group.id != "__root__" {
            categoryIDs.append(group.id)
            categoryPopup.addItem(withTitle: group.name)
        }
        categoryIDs.append("__root__")
        categoryPopup.addItem(withTitle: "未分类")
        if let preferredCategoryID, let index = categoryIDs.firstIndex(of: preferredCategoryID) {
            categoryPopup.selectItem(at: index)
        }
        position(relativeTo: anchor)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.contentView?.layoutSubtreeIfNeeded()
        let contentSize = scroll.contentSize
        textView.frame = NSRect(x: 0, y: 0, width: max(100, contentSize.width), height: max(120, contentSize.height))
        textView.textContainer?.containerSize = NSSize(width: max(100, contentSize.width), height: CGFloat.greatestFiniteMagnitude)
        windowMakeFirstResponder(titleField, delay: 0.08)
    }

    private func position(relativeTo anchor: NSRect) {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchor) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var x = anchor.midX - 235
        var y = anchor.midY - 215
        x = min(max(x, visible.minX + 8), visible.maxX - 470 - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - 430 - 8)
        panel.setFrame(NSRect(x: x, y: y, width: 470, height: 430), display: true)
    }

    private func windowMakeFirstResponder(_ responder: NSResponder, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.panel.makeFirstResponder(responder)
        }
    }

    func textDidChange(_ notification: Notification) {
        placeholderLabel.isHidden = !textView.string.isEmpty
    }

    @objc private func savePressed() {
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            NSSound.beep()
            titleField.layer?.borderWidth = 1
            panel.makeFirstResponder(titleField)
            return
        }
        let index = categoryPopup.indexOfSelectedItem
        let categoryID = index >= 0 && index < categoryIDs.count ? categoryIDs[index] : nil
        let content = textView.string
        if store.createMemory(title: title, content: content, categoryID: categoryID) != nil {
            onSaved?()
            hide()
        } else {
            NSSound.beep()
        }
    }

    @objc private func cancelPressed() { hide() }

    func hide() {
        panel.orderOut(nil)
        titleField.stringValue = ""
        textView.string = ""
        placeholderLabel.isHidden = false
    }
}
