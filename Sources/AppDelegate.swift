import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = MemoryStore.shared
    private var palette: PaletteController!
    private var ball: FloatingBallController!
    private var compose: ComposeController!
    private var settings: SettingsController!
    private var statusItem: NSStatusItem!
    private var ballVisible = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()
        store.bootstrap()

        palette = PaletteController(store: store)
        ball = FloatingBallController()
        compose = ComposeController(store: store)
        settings = SettingsController(store: store)

        wireActions()
        createStatusItem()

        store.onChange = { [weak self] in
            guard let self else { return }
            self.palette.reload()
            self.ball.update(count: self.store.totalCount)
        }
        store.onWorkspaceChange = { [weak self] in
            self?.palette.reload()
            self?.ball.update(count: self?.store.totalCount ?? 0)
        }

        ball.update(count: store.totalCount)
        ball.show()
        palette.reload()

        let onboardKey = "MemoryDock.didOnboard"
        if !UserDefaults.standard.bool(forKey: onboardKey) {
            UserDefaults.standard.set(true, forKey: onboardKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self else { return }
                self.palette.show(anchor: self.ball.currentAnchorRect())
            }
        }
    }

    private func wireActions() {
        ball.onToggle = { [weak self] in
            guard let self else { return }
            self.palette.toggle(anchor: self.ball.currentAnchorRect())
        }
        ball.onMoved = { [weak self] in
            guard let self else { return }
            self.palette.repositionIfVisible(relativeTo: self.ball.currentAnchorRect())
        }
        ball.onOpenWorkspace = { [weak self] in self?.store.revealWorkspace() }
        ball.onChooseWorkspace = { [weak self] in self?.chooseWorkspace(nil) }
        ball.onOpenSettings = { [weak self] in
            guard let self else { return }
            let anchor = self.palette.isVisible ? self.palette.panel.frame : self.ball.currentAnchorRect()
            self.settings.show(relativeTo: anchor)
        }
        ball.onQuit = { NSApp.terminate(nil) }

        palette.onNewMemory = { [weak self] in
            guard let self else { return }
            let anchor = self.palette.isVisible ? self.palette.panel.frame : self.ball.currentAnchorRect()
            self.compose.show(relativeTo: anchor, preferredCategoryID: self.palette.selectedCategoryID)
        }
        palette.onOpenSettings = { [weak self] in
            guard let self else { return }
            let anchor = self.palette.isVisible ? self.palette.panel.frame : self.ball.currentAnchorRect()
            self.settings.show(relativeTo: anchor)
        }
        palette.onRevealWorkspace = { [weak self] in self?.store.revealWorkspace() }
        palette.onChooseWorkspace = { [weak self] in self?.chooseWorkspace(nil) }

        compose.onSaved = { [weak self] in
            self?.palette.reload()
            self?.ball.update(count: self?.store.totalCount ?? 0)
        }
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.stack.fill", accessibilityDescription: "记忆坞")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "记忆坞 · 拖拽记忆"
        }

        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.addItem(item("打开记忆坞", action: #selector(togglePaletteFromMenu)))
        menu.addItem(item("在 Finder 中打开工作区", action: #selector(revealWorkspaceFromMenu)))
        menu.addItem(item("更换工作区…", action: #selector(chooseWorkspaceFromMenu)))
        menu.addItem(.separator())
        menu.addItem(item("设置…", action: #selector(openSettingsFromMenu)))
        menu.addItem(item(ballVisible ? "隐藏悬浮球" : "显示悬浮球", action: #selector(toggleBallFromMenu)))
        menu.addItem(.separator())
        menu.addItem(item("退出记忆坞", action: #selector(quitFromMenu), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    private func refreshStatusMenu() {
        guard let menu = statusItem.menu else { return }
        for item in menu.items where item.action == #selector(toggleBallFromMenu) {
            item.title = ballVisible ? "隐藏悬浮球" : "显示悬浮球"
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于记忆坞", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏记忆坞", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出记忆坞", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func togglePaletteFromMenu() {
        if !ballVisible { setBallVisible(true) }
        palette.toggle(anchor: ball.currentAnchorRect())
    }

    @objc private func revealWorkspaceFromMenu() {
        store.revealWorkspace()
    }

    @objc private func chooseWorkspaceFromMenu() {
        chooseWorkspace(nil)
    }

    @objc private func openSettingsFromMenu() {
        let anchor = palette.isVisible ? palette.panel.frame : ball.currentAnchorRect()
        settings.show(relativeTo: anchor)
    }

    @objc private func toggleBallFromMenu() {
        setBallVisible(!ballVisible)
    }

    private func setBallVisible(_ visible: Bool) {
        ballVisible = visible
        if visible {
            ball.show()
        } else {
            palette.hide()
            ball.hide()
        }
        refreshStatusMenu()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func chooseWorkspace(_ sender: Any?) {
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
        if openPanel.runModal() == .OK, let url = openPanel.url {
            store.setWorkspace(url)
        }
    }
}
