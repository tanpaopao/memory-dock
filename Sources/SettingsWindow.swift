import AppKit

@MainActor
final class SettingsController: NSObject {
    private let store: MemoryStore
    private let panel: DialogPanel
    private let background: DialogBackgroundView
    private let pathLabel = makeLabel("", font: NSFont.systemFont(ofSize: 11, weight: .regular), color: Theme.textSecondary)
    private let dragMode = NSSegmentedControl(labels: ["文件", "纯文本"], trackingMode: .selectOne, target: nil, action: nil)
    var onClose: (() -> Void)?

    init(store: MemoryStore) {
        self.store = store
        background = DialogBackgroundView(title: "设置", subtitle: "工作区、拖拽方式与记忆文件")
        panel = DialogPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
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
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 360))
        container.autoresizingMask = [.width, .height]
        background.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(background)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            background.topAnchor.constraint(equalTo: container.topAnchor),
            background.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            background.widthAnchor.constraint(equalToConstant: 500),
            background.heightAnchor.constraint(equalToConstant: 360),
        ])
        panel.contentView = container
        panel.setContentSize(NSSize(width: 500, height: 360))

        let workspaceLabel = FormLabel("记忆工作区")
        let pathBox = LayerView()
        pathBox.fill = Theme.field
        pathBox.radius = 9
        pathBox.borderColor = Theme.stroke
        pathBox.borderWidth = 1
        let folderIcon = makeSymbolView("folder.fill", size: 13, color: Theme.accentWarm, weight: .medium)
        pathBox.addSubview(folderIcon)
        pathBox.addSubview(pathLabel)
        folderIcon.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        NSLayoutConstraint.activate([
            folderIcon.leadingAnchor.constraint(equalTo: pathBox.leadingAnchor, constant: 12),
            folderIcon.centerYAnchor.constraint(equalTo: pathBox.centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 15),
            folderIcon.heightAnchor.constraint(equalToConstant: 15),
            pathLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 8),
            pathLabel.trailingAnchor.constraint(equalTo: pathBox.trailingAnchor, constant: -12),
            pathLabel.centerYAnchor.constraint(equalTo: pathBox.centerYAnchor),
        ])

        let chooseButton = SoftPillButton(title: "选择文件夹")
        chooseButton.target = self
        chooseButton.action = #selector(chooseWorkspace)
        let revealButton = SoftPillButton(title: "打开")
        revealButton.target = self
        revealButton.action = #selector(revealWorkspace)

        let dragLabel = FormLabel("默认拖出格式")
        dragMode.selectedSegment = UserDefaults.standard.bool(forKey: "MemoryDock.dragAsText") ? 1 : 0
        dragMode.target = self
        dragMode.action = #selector(dragModeChanged)
        dragMode.segmentStyle = .rounded

        let dragHint = makeLabel(
            "文件 = 作为附件拖给 AI；纯文本 = 直接拖进输入框。按住 ⌥ 反转。",
            font: NSFont.systemFont(ofSize: 10, weight: .regular),
            color: Theme.textTertiary,
            lines: 2
        )

        let separator = LayerView()
        separator.fill = Theme.stroke
        let doneButton = AccentPillButton(title: "完成", symbol: "checkmark")
        doneButton.target = self
        doneButton.action = #selector(donePressed)

        let views: [NSView] = [workspaceLabel, pathBox, chooseButton, revealButton, dragLabel, dragMode, dragHint, separator, doneButton]
        for view in views {
            background.panel.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            workspaceLabel.leadingAnchor.constraint(equalTo: background.panel.leadingAnchor, constant: 24),
            workspaceLabel.topAnchor.constraint(equalTo: background.panel.topAnchor, constant: 84),
            pathBox.leadingAnchor.constraint(equalTo: workspaceLabel.leadingAnchor),
            pathBox.topAnchor.constraint(equalTo: workspaceLabel.bottomAnchor, constant: 6),
            pathBox.trailingAnchor.constraint(equalTo: chooseButton.leadingAnchor, constant: -8),
            pathBox.heightAnchor.constraint(equalToConstant: 38),
            chooseButton.trailingAnchor.constraint(equalTo: revealButton.leadingAnchor, constant: -6),
            chooseButton.centerYAnchor.constraint(equalTo: pathBox.centerYAnchor),
            revealButton.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            revealButton.centerYAnchor.constraint(equalTo: pathBox.centerYAnchor),

            dragLabel.leadingAnchor.constraint(equalTo: workspaceLabel.leadingAnchor),
            dragLabel.topAnchor.constraint(equalTo: pathBox.bottomAnchor, constant: 20),
            dragMode.leadingAnchor.constraint(equalTo: workspaceLabel.leadingAnchor),
            dragMode.topAnchor.constraint(equalTo: dragLabel.bottomAnchor, constant: 7),
            dragMode.widthAnchor.constraint(equalToConstant: 190),
            dragHint.leadingAnchor.constraint(equalTo: dragMode.trailingAnchor, constant: 14),
            dragHint.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            dragHint.topAnchor.constraint(equalTo: dragLabel.bottomAnchor, constant: 5),

            separator.leadingAnchor.constraint(equalTo: background.panel.leadingAnchor, constant: 24),
            separator.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            separator.topAnchor.constraint(equalTo: dragMode.bottomAnchor, constant: 20),
            separator.heightAnchor.constraint(equalToConstant: 1),

            doneButton.trailingAnchor.constraint(equalTo: background.panel.trailingAnchor, constant: -24),
            doneButton.bottomAnchor.constraint(equalTo: background.panel.bottomAnchor, constant: -20),
        ])
        refreshPath()
    }

    func show(relativeTo anchor: NSRect) {
        refreshPath()
        dragMode.selectedSegment = UserDefaults.standard.bool(forKey: "MemoryDock.dragAsText") ? 1 : 0
        position(relativeTo: anchor)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func refreshPath() {
        pathLabel.stringValue = store.workspaceDisplayPath
        pathLabel.toolTip = store.workspaceURL.path
    }

    private func position(relativeTo anchor: NSRect) {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchor) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var x = anchor.midX - 250
        var y = anchor.midY - 180
        x = min(max(x, visible.minX + 8), visible.maxX - 500 - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - 360 - 8)
        panel.setFrame(NSRect(x: x, y: y, width: 500, height: 360), display: true)
    }

    @objc private func chooseWorkspace() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.message = "选择一个文件夹作为记忆工作区"
        openPanel.prompt = "选择工作区"
        openPanel.directoryURL = store.workspaceURL
        openPanel.appearance = NSAppearance(named: .darkAqua)
        NSApp.activate(ignoringOtherApps: true)
        guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
        store.setWorkspace(url)
        refreshPath()
    }

    @objc private func revealWorkspace() {
        store.revealWorkspace()
    }

    @objc private func dragModeChanged() {
        UserDefaults.standard.set(dragMode.selectedSegment == 1, forKey: "MemoryDock.dragAsText")
    }

    @objc private func donePressed() { hide() }

    func hide() {
        panel.orderOut(nil)
        onClose?()
    }
}
