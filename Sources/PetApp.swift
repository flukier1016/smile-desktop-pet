import AppKit
import QuartzCore

private let appName = "笑笑桌宠"

@main
final class PetAppDelegate: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: PetAppDelegate?
    private var controller: PetController?

    static func main() {
        let application = NSApplication.shared
        let delegate = PetAppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = PetController()
        controller?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetController: NSObject {
    private let windowSize = NSSize(width: 320, height: 430)
    private var panel: PetPanel!
    private var petView: PetView!
    private var statusItem: NSStatusItem!
    private var idleTimer: Timer?
    private var quietUntil: Date?
    private var clickThrough = false

    private let idlePhrases = [
        "你工作，我负责可爱。",
        "我在监督你喝水 👀",
        "摸鱼五分钟，批准！",
        "叮！快乐余额 +1",
        "桌面这么大，都是我的地盘。",
        "发呆中…其实在缓存灵感。",
        "再忙也要伸个懒腰呀～",
        "今天也要笑得很大声！",
        "要不要一起去吃点好的？",
        "别皱眉，送你一个笑脸！",
        "刚刚那行代码，是你写的吗？",
        "我没有偷懒，我在待机。"
    ]

    func start() {
        makePanel()
        makeStatusItem()
        restorePosition()
        panel.orderFrontRegardless()
        petView.showMessage("嗨！戳戳我，或者右键看看～", duration: 5)
        petView.celebrate(symbols: ["✨", "♥︎", "✨"], count: 10)

        idleTimer = Timer.scheduledTimer(
            timeInterval: 11,
            target: self,
            selector: #selector(idleMoment),
            userInfo: nil,
            repeats: true
        )
        if let idleTimer {
            RunLoop.main.add(idleTimer, forMode: .common)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenLayoutChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func makePanel() {
        panel = PetPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow

        guard let imageURL = Bundle.main.url(forResource: "pet", withExtension: "png"),
              let image = NSImage(contentsOf: imageURL) else {
            let alert = NSAlert()
            alert.messageText = "\(appName)缺少图片资源"
            alert.informativeText = "请重新运行 build.sh。"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        petView = PetView(frame: NSRect(origin: .zero, size: windowSize), image: image)
        petView.controller = self
        panel.contentView = petView
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "face.smiling.inverse",
                accessibilityDescription: appName
            )
            button.toolTip = appName
        }

        let menu = NSMenu()
        addMenuItem("👋 叫她回来", action: #selector(bringBack), to: menu)
        addMenuItem("💬 让她说句话", action: #selector(saySomething), to: menu)
        menu.addItem(.separator())

        let passItem = NSMenuItem(
            title: "🫥 鼠标穿透",
            action: #selector(toggleClickThrough(_:)),
            keyEquivalent: ""
        )
        passItem.target = self
        passItem.tag = 101
        menu.addItem(passItem)

        let quietItem = NSMenuItem(
            title: "😴 安静 10 分钟",
            action: #selector(toggleQuiet(_:)),
            keyEquivalent: ""
        )
        quietItem.target = self
        quietItem.tag = 102
        menu.addItem(quietItem)

        menu.addItem(.separator())
        addMenuItem("退出笑笑桌宠", action: #selector(quit), to: menu)
        statusItem.menu = menu
    }

    private func addMenuItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    func contextualMenu() -> NSMenu {
        let menu = NSMenu()
        addMenuItem("🍪 喂她一口", action: #selector(feed), to: menu)
        addMenuItem("✨ 夸夸她", action: #selector(praise), to: menu)
        addMenuItem("🔮 今日小运气", action: #selector(fortune), to: menu)
        addMenuItem("🐾 出去散个步", action: #selector(takeAWalk), to: menu)
        menu.addItem(.separator())
        addMenuItem("🫣 躲 5 分钟", action: #selector(hideForFiveMinutes), to: menu)
        addMenuItem("退出", action: #selector(quit), to: menu)
        return menu
    }

    func tapped(at point: NSPoint) {
        guard quietUntil == nil || Date() >= quietUntil! else {
            petView.showMessage("嘘…我在安静模式里打盹 😴", duration: 2.5)
            return
        }

        if point.y > 185 {
            let phrases = [
                "嘿嘿，再摸一下～",
                "摸头成功！好感度 +1",
                "头发不要摸乱啦！",
                "被你抓到啦 ♥︎",
                "再摸就要收费啦～"
            ]
            petView.showMessage(phrases.randomElement()!, duration: 3)
            petView.patReaction()
        } else {
            let phrases = [
                "痒痒痒！",
                "嘿！我会反击的哦！",
                "戳一下，快乐 +1",
                "我弹回来了！",
                "今天也元气满满！"
            ]
            petView.showMessage(phrases.randomElement()!, duration: 3)
            petView.bounce()
        }
        playSound(named: "Pop")
    }

    func doubleTapped() {
        petView.showMessage("快乐加载到 100%！", duration: 3)
        petView.party()
        playSound(named: "Glass")
    }

    func savePosition() {
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "petX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "petY")
    }

    @objc private func idleMoment() {
        if let quietUntil, Date() >= quietUntil {
            self.quietUntil = nil
            updateMenuStates()
        }
        guard panel.isVisible, !clickThrough, quietUntil == nil else {
            return
        }
        petView.showMessage(idlePhrases.randomElement()!, duration: 4)
        if Int.random(in: 0...2) == 0 {
            petView.bounce()
        }
    }

    @objc func feed() {
        let foods = ["🍪", "🍓", "🍡", "🥟", "🍰"]
        let food = foods.randomElement()!
        petView.showMessage("\(food) 嗷呜！这口算你的～", duration: 3.5)
        petView.feed(with: food)
        playSound(named: "Tink")
    }

    @objc func praise() {
        let phrases = [
            "你眼光真好！✨",
            "被夸得要飘起来了～",
            "嘿嘿，我也觉得我超可爱！",
            "这句我先收藏了 ♥︎"
        ]
        petView.showMessage(phrases.randomElement()!, duration: 3.5)
        petView.celebrate(symbols: ["♥︎", "✨", "✦"], count: 14)
        petView.wiggle()
    }

    @objc func fortune() {
        let fortunes = [
            "今日宜：大胆一点，运气会接住你。",
            "今日宜：喝水；忌：空腹硬撑。",
            "今日好运藏在下一次点击里 ✨",
            "今天会有一个小惊喜主动找你。",
            "幸运色：红色。幸运动作：伸懒腰。",
            "今日宜：把最难的事先做五分钟。"
        ]
        petView.showMessage(fortunes.randomElement()!, duration: 5)
        petView.celebrate(symbols: ["✦", "☀︎", "✨"], count: 12)
    }

    @objc func takeAWalk() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let targetX = CGFloat.random(
            in: visible.minX...(visible.maxX - panel.frame.width)
        )
        let targetY = CGFloat.random(
            in: visible.minY...(visible.maxY - panel.frame.height)
        )
        petView.showMessage("出发！换个地方摸鱼～", duration: 3)
        petView.walking = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
        } completionHandler: { [weak self] in
            self?.petView.walking = false
            self?.savePosition()
        }
    }

    @objc func hideForFiveMinutes() {
        panel.orderOut(nil)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.bringBack()
        }
    }

    @objc func bringBack() {
        constrainToVisibleScreen()
        panel.orderFrontRegardless()
        petView.showMessage("我回来啦！", duration: 3)
        petView.bounce()
    }

    @objc func saySomething() {
        panel.orderFrontRegardless()
        petView.showMessage(idlePhrases.randomElement()!, duration: 4)
        petView.wiggle()
    }

    @objc private func toggleClickThrough(_ sender: NSMenuItem) {
        clickThrough.toggle()
        panel.ignoresMouseEvents = clickThrough
        updateMenuStates()
        if clickThrough {
            petView.showMessage("穿透模式开启，从菜单栏把我叫回来～", duration: 4)
        } else {
            panel.orderFrontRegardless()
            petView.showMessage("又可以戳我啦！", duration: 3)
        }
    }

    @objc private func toggleQuiet(_ sender: NSMenuItem) {
        if let quietUntil, quietUntil > Date() {
            self.quietUntil = nil
            panel.orderFrontRegardless()
            petView.showMessage("睡醒啦！继续营业～", duration: 3)
        } else {
            quietUntil = Date().addingTimeInterval(600)
            petView.showMessage("安静模式开启，十分钟后见～", duration: 4)
        }
        updateMenuStates()
    }

    private func updateMenuStates() {
        guard let menu = statusItem.menu else { return }
        menu.item(withTag: 101)?.state = clickThrough ? .on : .off
        let isQuiet = quietUntil.map { $0 > Date() } ?? false
        menu.item(withTag: 102)?.state = isQuiet ? .on : .off
    }

    @objc private func screenLayoutChanged() {
        constrainToVisibleScreen()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    private func restorePosition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let defaults = UserDefaults.standard
        let hasSavedPosition = defaults.object(forKey: "petX") != nil
        let origin: NSPoint

        if hasSavedPosition {
            origin = NSPoint(
                x: defaults.double(forKey: "petX"),
                y: defaults.double(forKey: "petY")
            )
        } else {
            origin = NSPoint(
                x: visible.maxX - windowSize.width - 24,
                y: visible.minY + 20
            )
        }
        panel.setFrameOrigin(origin)
        constrainToVisibleScreen()
    }

    private func constrainToVisibleScreen() {
        let screen = panel.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, visible.minX), visible.maxX - panel.frame.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - panel.frame.height)
        panel.setFrameOrigin(origin)
        savePosition()
    }

    private func playSound(named name: String) {
        let path = "/System/Library/Sounds/\(name).aiff"
        NSSound(contentsOfFile: path, byReference: true)?.play()
    }
}

private struct PetParticle {
    let symbol: String
    var position: NSPoint
    var velocity: CGVector
    let bornAt: TimeInterval
    let lifetime: TimeInterval
    let size: CGFloat
}

final class PetView: NSView {
    weak var controller: PetController?
    var walking = false

    private let image: NSImage
    private var animationTimer: Timer?
    private var particles: [PetParticle] = []
    private var message: String?
    private var messageEndsAt: TimeInterval = 0
    private var phase: CGFloat = 0
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var bounceStartedAt: TimeInterval?
    private var spinStartedAt: TimeInterval?
    private var wiggleEndsAt: TimeInterval = 0
    private var patEndsAt: TimeInterval = 0
    private var dragStartMouse = NSPoint.zero
    private var dragStartWindow = NSPoint.zero
    private var dragged = false

    init(frame frameRect: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        animationTimer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        if let animationTimer {
            RunLoop.main.add(animationTimer, forMode: .common)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        animationTimer?.invalidate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawPet()
        drawParticles()
        drawBubble()
    }

    private func petRect() -> NSRect {
        let area = NSRect(x: 18, y: 8, width: bounds.width - 36, height: 352)
        let aspect = image.size.width / image.size.height
        let width = min(area.width, area.height * aspect)
        let height = width / aspect
        return NSRect(
            x: area.midX - width / 2,
            y: area.minY,
            width: width,
            height: height
        )
    }

    private func drawPet() {
        let now = ProcessInfo.processInfo.systemUptime
        var rect = petRect()
        let idleBob = sin(phase) * 3
        var verticalOffset = idleBob
        var rotation: CGFloat = 0
        var scale: CGFloat = 1

        if walking {
            verticalOffset += abs(sin(phase * 4)) * 9
            rotation += sin(phase * 4) * 4
        }

        if let start = bounceStartedAt {
            let progress = (now - start) / 0.85
            if progress < 1 {
                verticalOffset += CGFloat(abs(sin(progress * .pi * 3))) * 34 * CGFloat(1 - progress)
                scale += CGFloat(sin(progress * .pi)) * 0.06
            }
        }

        if let start = spinStartedAt {
            let progress = min(1, (now - start) / 0.9)
            let eased = 1 - pow(1 - progress, 3)
            rotation += CGFloat(eased * 360)
            scale += CGFloat(sin(progress * .pi)) * 0.12
        }

        if now < wiggleEndsAt {
            rotation += sin(CGFloat(now * 28)) * 7
        }

        if now < patEndsAt {
            scale += 0.035 + sin(CGFloat(now * 24)) * 0.018
            rect.size.height *= 0.97
        }

        rect.origin.y += verticalOffset
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.translateBy(x: rect.midX, y: rect.midY)
        context?.rotate(by: rotation * .pi / 180)
        context?.scaleBy(x: scale, y: scale)
        context?.translateBy(x: -rect.midX, y: -rect.midY)
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        context?.restoreGState()
    }

    private func drawBubble() {
        guard let message else { return }
        let bubbleRect = NSRect(x: 8, y: 350, width: bounds.width - 16, height: 70)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 18, yRadius: 18)
        NSColor.white.withAlphaComponent(0.96).setFill()
        bubble.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bubbleRect.midX - 10, y: bubbleRect.minY + 1))
        tail.line(to: NSPoint(x: bubbleRect.midX + 12, y: bubbleRect.minY + 1))
        tail.line(to: NSPoint(x: bubbleRect.midX + 2, y: bubbleRect.minY - 13))
        tail.close()
        NSColor.white.withAlphaComponent(0.96).setFill()
        tail.fill()

        NSGraphicsContext.current?.saveGraphicsState()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.14, blue: 0.13, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let textRect = bubbleRect.insetBy(dx: 16, dy: 12)
        (message as NSString).draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawParticles() {
        let now = ProcessInfo.processInfo.systemUptime
        for particle in particles {
            let age = now - particle.bornAt
            let opacity = max(0, 1 - age / particle.lifetime)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: particle.size),
                .foregroundColor: NSColor.white.withAlphaComponent(opacity)
            ]
            (particle.symbol as NSString).draw(
                at: particle.position,
                withAttributes: attributes
            )
        }
    }

    @objc private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(0.05, now - lastTick)
        lastTick = now
        phase += CGFloat(delta) * 2.4

        for index in particles.indices {
            particles[index].position.x += particles[index].velocity.dx * CGFloat(delta)
            particles[index].position.y += particles[index].velocity.dy * CGFloat(delta)
            particles[index].velocity.dy -= 24 * CGFloat(delta)
        }
        particles.removeAll { now - $0.bornAt > $0.lifetime }

        if message != nil && now >= messageEndsAt {
            message = nil
        }
        if let start = bounceStartedAt, now - start >= 0.85 {
            bounceStartedAt = nil
        }
        if let start = spinStartedAt, now - start >= 0.9 {
            spinStartedAt = nil
        }
        needsDisplay = true
    }

    func showMessage(_ text: String, duration: TimeInterval) {
        message = text
        messageEndsAt = ProcessInfo.processInfo.systemUptime + duration
        needsDisplay = true
    }

    func bounce() {
        bounceStartedAt = ProcessInfo.processInfo.systemUptime
    }

    func wiggle() {
        wiggleEndsAt = ProcessInfo.processInfo.systemUptime + 0.9
    }

    func patReaction() {
        patEndsAt = ProcessInfo.processInfo.systemUptime + 0.75
        celebrate(symbols: ["♥︎", "♥︎", "✨"], count: 8, origin: NSPoint(x: bounds.midX, y: 275))
    }

    func party() {
        spinStartedAt = ProcessInfo.processInfo.systemUptime
        celebrate(symbols: ["♥︎", "✨", "✦", "●"], count: 28)
    }

    func feed(with food: String) {
        celebrate(symbols: [food, "♥︎", "✨"], count: 12, origin: NSPoint(x: bounds.midX, y: 205))
        bounce()
    }

    func celebrate(
        symbols: [String],
        count: Int,
        origin: NSPoint? = nil
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        let center = origin ?? NSPoint(x: bounds.midX, y: 225)
        for _ in 0..<count {
            particles.append(
                PetParticle(
                    symbol: symbols.randomElement()!,
                    position: NSPoint(
                        x: center.x + CGFloat.random(in: -35...35),
                        y: center.y + CGFloat.random(in: -20...35)
                    ),
                    velocity: CGVector(
                        dx: CGFloat.random(in: -75...75),
                        dy: CGFloat.random(in: 60...150)
                    ),
                    bornAt: now,
                    lifetime: Double.random(in: 1.0...1.8),
                    size: CGFloat.random(in: 14...24)
                )
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            controller?.doubleTapped()
            return
        }
        dragStartMouse = NSEvent.mouseLocation
        dragStartWindow = window?.frame.origin ?? .zero
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let current = NSEvent.mouseLocation
        let deltaX = current.x - dragStartMouse.x
        let deltaY = current.y - dragStartMouse.y
        if hypot(deltaX, deltaY) > 3 {
            dragged = true
        }
        window.setFrameOrigin(
            NSPoint(x: dragStartWindow.x + deltaX, y: dragStartWindow.y + deltaY)
        )
    }

    override func mouseUp(with event: NSEvent) {
        if dragged {
            controller?.savePosition()
        } else if event.clickCount < 2 {
            controller?.tapped(at: convert(event.locationInWindow, from: nil))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = controller?.contextualMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
