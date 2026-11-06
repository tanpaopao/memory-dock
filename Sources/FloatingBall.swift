import AppKit

final class BallPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class BallView: NSView {
    var count: Int = 0 {
        didSet { needsDisplay = true }
    }
    var onClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onMoved: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var didDrag = false

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isHovering ? .pointingHand : .arrow)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartMouse.x
        let dy = current.y - dragStartMouse.y
        if hypot(dx, dy) > 3 { didDrag = true }
        guard didDrag else { return }
        window.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
        onMoved?()
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else { return }
        if didDrag {
            snapToScreenEdge(window)
            savePosition()
            onMoved?()
        } else {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    private func snapToScreenEdge(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        let leftDistance = abs(frame.minX - visible.minX)
        let rightDistance = abs(visible.maxX - frame.maxX)
        let margin: CGFloat = 12
        let targetX = leftDistance < rightDistance ? visible.minX + margin : visible.maxX - frame.width - margin
        frame.origin.x = targetX
        frame.origin.y = min(max(frame.minY, visible.minY + 8), visible.maxY - frame.height - 8)
        window.setFrame(frame, display: true)
    }

    private func savePosition() {
        guard let window else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "MemoryDock.ballFrame")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let outer = bounds.insetBy(dx: 8, dy: 8)
        let circleRect = outer
        let scale: CGFloat = isHovering ? 1.03 : 1.0
        let transform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -bounds.midX, y: -bounds.midY)
        ctx.saveGState()
        ctx.concatenate(transform)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 12, color: NSColor.black.withAlphaComponent(0.38).cgColor)
        let path = NSBezierPath(ovalIn: circleRect)
        NSGradient(colors: [Theme.accentWarm, Theme.accent])?.draw(in: path, angle: -55)
        ctx.restoreGState()

        // Soft top highlight.
        ctx.saveGState()
        let highlight = NSBezierPath(ovalIn: circleRect.insetBy(dx: 2, dy: 2))
        NSColor.white.withAlphaComponent(isHovering ? 0.16 : 0.10).setStroke()
        highlight.lineWidth = 1.2
        highlight.stroke()
        ctx.restoreGState()

        drawCardGlyph(in: circleRect)

        if count > 0 {
            drawBadge(in: circleRect)
        }
        ctx.restoreGState()
    }

    private func drawCardGlyph(in rect: NSRect) {
        let w: CGFloat = rect.width
        let baseX = rect.midX - w * 0.22
        let baseY = rect.midY - w * 0.20
        let cardW = w * 0.44
        let cardH = w * 0.22

        for index in 0..<3 {
            let alpha: CGFloat = index == 2 ? 0.97 : (index == 1 ? 0.54 : 0.28)
            let x = baseX + CGFloat(index) * 1.3
            let y = baseY + CGFloat(index) * 5.2
            let card = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: cardW, height: cardH), xRadius: 3.8, yRadius: 3.8)
            NSColor.white.withAlphaComponent(alpha).setFill()
            card.fill()
        }

        // Lines on the top card.
        let topY = baseY + 10.4
        let lineColor = Theme.accent.withAlphaComponent(0.72)
        for index in 0..<2 {
            let line = NSBezierPath(roundedRect: NSRect(
                x: baseX + 4.8,
                y: topY + cardH - 5.4 - CGFloat(index) * 3.7,
                width: cardW - 9.6 - CGFloat(index) * 4,
                height: 1.45
            ), xRadius: 0.7, yRadius: 0.7)
            lineColor.setFill()
            line.fill()
        }

        // Small spark at the upper-right.
        let spark = NSBezierPath()
        let cx = rect.maxX - 15.5
        let cy = rect.maxY - 16.5
        spark.move(to: NSPoint(x: cx, y: cy + 4.4))
        spark.line(to: NSPoint(x: cx + 1.2, y: cy + 1.2))
        spark.line(to: NSPoint(x: cx + 4.4, y: cy))
        spark.line(to: NSPoint(x: cx + 1.2, y: cy - 1.2))
        spark.line(to: NSPoint(x: cx, y: cy - 4.4))
        spark.line(to: NSPoint(x: cx - 1.2, y: cy - 1.2))
        spark.line(to: NSPoint(x: cx - 4.4, y: cy))
        spark.line(to: NSPoint(x: cx - 1.2, y: cy + 1.2))
        spark.close()
        NSColor.white.withAlphaComponent(0.92).setFill()
        spark.fill()
    }

    private func drawBadge(in rect: NSRect) {
        let text = count > 99 ? "99+" : "\(count)"
        let font = NSFont.systemFont(ofSize: 8.5, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attrs)
        let badgeW = max(16, size.width + 8)
        let badgeRect = NSRect(x: rect.maxX - badgeW + 2, y: rect.maxY - 13, width: badgeW, height: 15)
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: 7.5, yRadius: 7.5)
        NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.14, alpha: 0.95).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.20).setStroke()
        path.lineWidth = 0.6
        path.stroke()
        let textPoint = NSPoint(x: badgeRect.midX - size.width / 2, y: badgeRect.midY - size.height / 2 + 0.4)
        (text as NSString).draw(at: textPoint, withAttributes: attrs)
    }
}

@MainActor
final class FloatingBallController {
    let panel: BallPanel
    let ballView: BallView
    private let panelSize: CGFloat = 82

    var onToggle: (() -> Void)?
    var onOpenWorkspace: (() -> Void)?
    var onChooseWorkspace: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var onMoved: (() -> Void)?

    init() {
        panel = BallPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize, height: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        ballView = BallView(frame: NSRect(x: 0, y: 0, width: panelSize, height: panelSize))
        panel.contentView = ballView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false

        ballView.onClick = { [weak self] in self?.onToggle?() }
        ballView.onMoved = { [weak self] in self?.onMoved?() }
        ballView.onRightClick = { [weak self] event in self?.showContextMenu(event) }
        restorePosition()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    var isVisible: Bool { panel.isVisible }

    func update(count: Int) {
        ballView.count = count
    }

    func currentAnchorRect() -> NSRect {
        panel.frame
    }

    private func restorePosition() {
        if let raw = UserDefaults.standard.string(forKey: "MemoryDock.ballFrame") {
            let frame = NSRectFromString(raw)
            if frame.width > 0, NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                panel.setFrame(frame, display: false)
                return
            }
        }
        guard let screen = NSScreen.main else {
            panel.setFrameOrigin(NSPoint(x: 100, y: 100))
            return
        }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - panelSize - 12, y: visible.midY - panelSize / 2))
    }

    private func showContextMenu(_ event: NSEvent) {
        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)

        let open = NSMenuItem(title: "打开记忆坞", action: #selector(menuOpen), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let workspace = NSMenuItem(title: "在 Finder 中打开工作区", action: #selector(menuWorkspace), keyEquivalent: "")
        workspace.target = self
        menu.addItem(workspace)

        let choose = NSMenuItem(title: "更换工作区…", action: #selector(menuChoose), keyEquivalent: "")
        choose.target = self
        menu.addItem(choose)

        let settings = NSMenuItem(title: "设置…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出记忆坞", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: ballView.bounds.midX, y: 8), in: ballView)
    }

    @objc private func menuOpen() { onToggle?() }
    @objc private func menuWorkspace() { onOpenWorkspace?() }
    @objc private func menuChoose() { onChooseWorkspace?() }
    @objc private func menuSettings() { onOpenSettings?() }
    @objc private func menuQuit() { onQuit?() }
}
