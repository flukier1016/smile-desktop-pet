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
    private let baseWindowSize = NSSize(width: 320, height: 430)
    private let minimumScale: CGFloat = 0.55
    private let maximumScale: CGFloat = 1.10
    private var petScale: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "petScale")
        return saved > 0 ? CGFloat(saved) : 0.74
    }()
    private var panel: PetPanel!
    private var petView: PetView!
    private var statusItem: NSStatusItem!
    private var idleTimer: Timer?
    private var quietUntil: Date?
    private var clickThrough = false
    private var awarenessEngine: AwarenessEngine!
    private var controlCenter: ControlCenterController?
    private let companionStore = CompanionStore()
    private var currentScene: PetScene = .companion
    private var lastAwarenessSnapshot: AwarenessSnapshot?

    func start() {
        awarenessEngine = AwarenessEngine()
        makePanel()
        makeStatusItem()
        configureAwareness()
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

        awarenessEngine.start()
        showFirstRunCompanionWelcomeIfNeeded()
    }

    private func makePanel() {
        let windowSize = scaledWindowSize(for: petScale)
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
        petView.autoresizingMask = [.width, .height]
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
        addMenuItem("✨ 打开控制中心…", action: #selector(showControlCenter), to: menu)
        let companionItem = NSMenuItem(
            title: companionMenuTitle(),
            action: #selector(showControlCenter),
            keyEquivalent: ""
        )
        companionItem.target = self
        companionItem.tag = 401
        menu.addItem(companionItem)
        menu.addItem(.separator())
        addMenuItem("👋 叫她回来", action: #selector(bringBack), to: menu)
        addMenuItem("💬 让她说句话", action: #selector(saySomething), to: menu)
        addSizeSubmenu(to: menu)
        addAwarenessSubmenu(to: menu)
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

    private func companionMenuTitle() -> String {
        let progress = companionStore.snapshot()
        return "♥︎ Lv.\(progress.level) \(progress.levelTitle) · 今日 "
            + "\(progress.completedCareCount)/\(progress.careGoal)"
    }

    func contextualMenu() -> NSMenu {
        let menu = NSMenu()
        addMenuItem("✨ 打开控制中心…", action: #selector(showControlCenter), to: menu)
        let companionItem = NSMenuItem(
            title: companionMenuTitle(),
            action: #selector(showControlCenter),
            keyEquivalent: ""
        )
        companionItem.target = self
        companionItem.tag = 401
        menu.addItem(companionItem)
        menu.addItem(.separator())
        addMenuItem("🍪 喂她一口", action: #selector(feed), to: menu)
        addMenuItem("✨ 夸夸她", action: #selector(praise), to: menu)
        addMenuItem("🔮 今日小运气", action: #selector(fortune), to: menu)
        addMenuItem("🐾 出去散个步", action: #selector(takeAWalk), to: menu)
        addSizeSubmenu(to: menu)
        addAwarenessSubmenu(to: menu)
        menu.addItem(.separator())
        addMenuItem("🫣 躲 5 分钟", action: #selector(hideForFiveMinutes), to: menu)
        addMenuItem("退出", action: #selector(quit), to: menu)
        return menu
    }

    private func addSizeSubmenu(to menu: NSMenu) {
        let sizeItem = NSMenuItem(title: "↔️ 调整大小", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        let presets: [(String, Selector, Int, CGFloat)] = [
            ("迷你 60%", #selector(setMiniSize), 201, 0.60),
            ("标准 75%", #selector(setStandardSize), 202, 0.74),
            ("大只 100%", #selector(setLargeSize), 203, 1.00)
        ]

        for preset in presets {
            let item = NSMenuItem(title: preset.0, action: preset.1, keyEquivalent: "")
            item.target = self
            item.tag = preset.2
            item.state = abs(petScale - preset.3) < 0.025 ? .on : .off
            sizeMenu.addItem(item)
        }

        sizeMenu.addItem(.separator())
        let hint = NSMenuItem(title: "按住 Option 滚轮可微调", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        sizeMenu.addItem(hint)
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
    }

    private func addAwarenessSubmenu(to menu: NSMenu) {
        let awarenessItem = NSMenuItem(title: "🧠 场景感知", action: nil, keyEquivalent: "")
        let awarenessMenu = NSMenu()

        let enabledItem = NSMenuItem(
            title: "自动感知",
            action: #selector(toggleAwareness(_:)),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.tag = 301
        enabledItem.state = awarenessEngine.isEnabled ? .on : .off
        awarenessMenu.addItem(enabledItem)

        let ocrItem = NSMenuItem(
            title: "本地屏幕 OCR",
            action: #selector(toggleScreenOCR(_:)),
            keyEquivalent: ""
        )
        ocrItem.target = self
        ocrItem.tag = 302
        ocrItem.state = awarenessEngine.isOCREnabled ? .on : .off
        ocrItem.isEnabled = awarenessEngine.isEnabled
        awarenessMenu.addItem(ocrItem)

        let currentItem = NSMenuItem(
            title: "当前：\(currentScene.emoji) \(currentScene.title)",
            action: nil,
            keyEquivalent: ""
        )
        currentItem.tag = 305
        currentItem.isEnabled = false
        awarenessMenu.addItem(currentItem)

        let sourceItem = NSMenuItem(
            title: awarenessSourceMenuTitle(),
            action: nil,
            keyEquivalent: ""
        )
        sourceItem.tag = 306
        sourceItem.isEnabled = false
        awarenessMenu.addItem(sourceItem)

        awarenessMenu.addItem(.separator())
        addMenuItem("🔎 立即识别一次", action: #selector(refreshAwareness), to: awarenessMenu)

        let pauseTitle = awarenessEngine.isPaused || awarenessEngine.selectedManualScene != nil
            ? "▶️ 恢复自动切换"
            : "⏸ 暂停感知 30 分钟"
        let pauseItem = NSMenuItem(
            title: pauseTitle,
            action: #selector(toggleAwarenessPause),
            keyEquivalent: ""
        )
        pauseItem.target = self
        pauseItem.tag = 303
        pauseItem.isEnabled = awarenessEngine.isEnabled
        awarenessMenu.addItem(pauseItem)

        addOCRIntervalSubmenu(to: awarenessMenu)
        addManualSceneSubmenu(to: awarenessMenu)

        awarenessMenu.addItem(.separator())
        addMenuItem("🔒 隐私与屏幕权限…", action: #selector(showAwarenessPrivacy), to: awarenessMenu)

        awarenessItem.submenu = awarenessMenu
        menu.addItem(awarenessItem)
    }

    private func addOCRIntervalSubmenu(to menu: NSMenu) {
        let intervalItem = NSMenuItem(title: "⏱ OCR 识别间隔", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        let options: [(String, Selector, Int, TimeInterval)] = [
            ("灵敏 · 8 秒", #selector(setOCRIntervalFast), 311, 8),
            ("均衡 · 15 秒", #selector(setOCRIntervalBalanced), 312, 15),
            ("省电 · 30 秒", #selector(setOCRIntervalGentle), 313, 30)
        ]
        for option in options {
            let item = NSMenuItem(title: option.0, action: option.1, keyEquivalent: "")
            item.target = self
            item.tag = option.2
            item.state = abs(awarenessEngine.ocrInterval - option.3) < 0.5 ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)
    }

    private func addManualSceneSubmenu(to menu: NSMenu) {
        let previewItem = NSMenuItem(title: "🎭 手动预览状态", action: nil, keyEquivalent: "")
        let previewMenu = NSMenu()
        addSceneGroup("工作现场", scenes: PetScene.workScenes, to: previewMenu)
        addSceneGroup("沟通与创作", scenes: PetScene.communicationScenes, to: previewMenu)
        addSceneGroup("生活与摸鱼", scenes: PetScene.lifeScenes, to: previewMenu)
        previewItem.submenu = previewMenu
        menu.addItem(previewItem)
    }

    private func addSceneGroup(_ title: String, scenes: [PetScene], to menu: NSMenu) {
        let groupItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let groupMenu = NSMenu()
        for scene in scenes {
            let item = NSMenuItem(
                title: "\(scene.emoji) \(scene.title)",
                action: #selector(previewScene(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = scene.rawValue
            item.state = awarenessEngine.selectedManualScene == scene ? .on : .off
            groupMenu.addItem(item)
        }
        groupItem.submenu = groupMenu
        menu.addItem(groupItem)
    }

    func tapped(at point: NSPoint) {
        guard quietUntil == nil || Date() >= quietUntil! else {
            petView.showMessage("嘘…我在安静模式里打盹 😴", duration: 2.5)
            return
        }

        if point.y > 185 {
            pat()
        } else {
            let phrases = [
                "痒痒痒！",
                "嘿！我会反击的哦！",
                "戳一下，快乐 +1",
                "我弹回来了！",
                "今天也元气满满！"
            ]
            let update = recordCompanion(.poke)
            showInteractionMessage(
                phrases.randomElement()!,
                update: update,
                duration: 3
            )
            petView.bounce()
            playSound(named: "Pop")
        }
    }

    func doubleTapped() {
        let update = recordCompanion(.celebrate)
        showInteractionMessage(
            "快乐加载到 100%！",
            update: update,
            duration: 3
        )
        petView.party()
        playSound(named: "Glass")
    }

    func savePosition() {
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "petX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "petY")
    }

    func adjustScale(by scrollDelta: CGFloat) {
        let step = max(-0.08, min(0.08, scrollDelta * 0.012))
        guard abs(step) > 0.001 else { return }
        applyScale(petScale + step)
    }

    @objc private func setMiniSize() {
        applyScale(0.60)
    }

    @objc private func setStandardSize() {
        applyScale(0.74)
    }

    @objc private func setLargeSize() {
        applyScale(1.00)
    }

    private func applyScale(_ requestedScale: CGFloat) {
        let newScale = min(max(requestedScale, minimumScale), maximumScale)
        guard abs(newScale - petScale) > 0.001 else { return }

        let oldFrame = panel.frame
        petScale = newScale
        let newSize = scaledWindowSize(for: newScale)
        let newOrigin = NSPoint(
            x: oldFrame.midX - newSize.width / 2,
            y: oldFrame.midY - newSize.height / 2
        )
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
        UserDefaults.standard.set(Double(newScale), forKey: "petScale")
        constrainToVisibleScreen()
        updateMenuStates()
        petView.showMessage("现在是 \(Int(round(newScale * 100)))% 大小～", duration: 1.6)
    }

    private func scaledWindowSize(for scale: CGFloat) -> NSSize {
        NSSize(
            width: round(baseWindowSize.width * scale),
            height: round(baseWindowSize.height * scale)
        )
    }

    private func configureAwareness() {
        awarenessEngine.onSnapshot = { [weak self] snapshot, _ in
            self?.lastAwarenessSnapshot = snapshot
            self?.updateMenuStates()
        }
        awarenessEngine.onSceneChange = { [weak self] scene, snapshot in
            self?.applyScene(scene, snapshot: snapshot)
        }
    }

    private func applyScene(_ scene: PetScene, snapshot: AwarenessSnapshot?) {
        guard currentScene != scene else { return }
        currentScene = scene
        petView.setScene(scene)
        statusItem.button?.toolTip = "\(appName) · \(scene.title)"
        updateMenuStates()

        guard quietUntil == nil || Date() >= quietUntil! else { return }
        panel.orderFrontRegardless()
        petView.showMessage(scene.arrivalPhrases.randomElement()!, duration: 4.5)
        switch scene.motion {
        case .panic:
            petView.wiggle()
            petView.celebrate(symbols: ["!", "⚠︎", "×"], count: 10)
        case .celebrate:
            petView.party()
        case .dance:
            petView.wiggle()
        case .busy:
            petView.bounce()
        default:
            break
        }
    }

    private func awarenessSourceMenuTitle() -> String {
        guard awarenessEngine != nil else { return "来源：尚未识别" }
        if awarenessEngine.isOCREnabled && !awarenessEngine.hasScreenCapturePermission {
            return "来源：OCR 等待屏幕权限"
        }
        guard let snapshot = lastAwarenessSnapshot else {
            return awarenessEngine.isOCREnabled ? "来源：等待本地 OCR" : "来源：前台 App"
        }
        let app = snapshot.appName.isEmpty ? "桌面" : snapshot.appName
        return "来源：\(snapshot.sourceLabel) · \(app)"
    }

    @objc private func toggleAwareness(_ sender: NSMenuItem) {
        setAwarenessEnabled(!awarenessEngine.isEnabled)
    }

    private func setAwarenessEnabled(_ enabled: Bool) {
        guard awarenessEngine.isEnabled != enabled else {
            updateMenuStates()
            return
        }
        awarenessEngine.setEnabled(enabled)
        if enabled {
            petView.showMessage("自动感知启动，我会看场景变状态～", duration: 4)
        } else {
            currentScene = .companion
            petView.setScene(.companion)
            petView.showMessage("自动感知已关闭，我只负责陪你。", duration: 4)
        }
        updateMenuStates()
    }

    @objc private func toggleScreenOCR(_ sender: NSMenuItem) {
        setScreenOCREnabled(!awarenessEngine.isOCREnabled)
    }

    private func setScreenOCREnabled(_ enabled: Bool) {
        guard awarenessEngine.isOCREnabled != enabled else {
            updateMenuStates()
            return
        }
        if !enabled {
            awarenessEngine.setOCREnabled(false)
            petView.showMessage("屏幕 OCR 已关闭，只看前台 App。", duration: 4)
            updateMenuStates()
            return
        }

        if awarenessEngine.requestScreenCapturePermission() {
            awarenessEngine.setOCREnabled(true)
            petView.showMessage("本地 OCR 开启，只识别当前窗口，不保存截图。", duration: 5)
        } else {
            awarenessEngine.setOCREnabled(false)
            showScreenPermissionHelp()
        }
        updateMenuStates()
    }

    @objc private func showControlCenter() {
        presentControlCenter(preferCompanionPage: false)
    }

    private func presentControlCenter(preferCompanionPage: Bool) {
        if controlCenter == nil {
            let controller = ControlCenterController()
            controller.onAwarenessChanged = { [weak self] enabled in
                self?.setAwarenessEnabled(enabled)
            }
            controller.onOCRChanged = { [weak self] enabled in
                self?.setScreenOCREnabled(enabled)
            }
            controller.onScaleChanged = { [weak self] scale in
                self?.applyScale(scale)
            }
            controller.onIntervalChanged = { [weak self] interval in
                self?.setOCRInterval(interval)
            }
            controller.onRefresh = { [weak self] in
                self?.refreshAwareness()
            }
            controller.onBringBack = { [weak self] in
                self?.bringBack()
            }
            controller.onPrivacy = { [weak self] in
                self?.showAwarenessPrivacy()
            }
            controller.onPat = { [weak self] in
                self?.pat()
            }
            controller.onFeed = { [weak self] in
                self?.feed()
            }
            controller.onPraise = { [weak self] in
                self?.praise()
            }
            controller.onFortune = { [weak self] in
                self?.fortune()
            }
            controller.onWalk = { [weak self] in
                self?.takeAWalk()
            }
            controller.onCelebrate = { [weak self] in
                self?.doubleTapped()
            }
            controlCenter = controller
        }
        controlCenter?.show(
            state: makeControlCenterState(),
            preferCompanionPage: preferCompanionPage
        )
    }

    private func makeControlCenterState() -> ControlCenterState {
        let snapshot = lastAwarenessSnapshot
        let foregroundApp = snapshot.flatMap {
            $0.appName.isEmpty ? nil : $0.appName
        } ?? "等待识别"
        let source: String
        if awarenessEngine.isOCREnabled && !awarenessEngine.hasScreenCapturePermission {
            source = "OCR 等待权限"
        } else if let snapshot {
            source = snapshot.sourceLabel
        } else {
            source = awarenessEngine.isOCREnabled ? "等待本地 OCR" : "前台 App"
        }
        return ControlCenterState(
            scene: currentScene,
            appName: foregroundApp,
            source: source,
            awarenessEnabled: awarenessEngine.isEnabled,
            ocrEnabled: awarenessEngine.isOCREnabled,
            hasScreenPermission: awarenessEngine.hasScreenCapturePermission,
            isPaused: awarenessEngine.isPaused || awarenessEngine.selectedManualScene != nil,
            scale: petScale,
            ocrInterval: awarenessEngine.ocrInterval,
            companion: companionStore.snapshot()
        )
    }

    private func showFirstRunCompanionWelcomeIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "didShowCompanionWelcomeV140"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.presentControlCenter(preferCompanionPage: true)
            self.petView.showMessage(
                "以后每天来摸摸、喂食、夸夸、抽签，我会慢慢长大～",
                duration: 6
            )
            self.petView.celebrate(symbols: ["♥︎", "✨", "🌸"], count: 16)
        }
    }

    @objc private func refreshAwareness() {
        awarenessEngine.refreshNow()
        petView.showMessage("正在看看你现在忙什么…", duration: 2.5)
    }

    @objc private func toggleAwarenessPause() {
        if awarenessEngine.isPaused || awarenessEngine.selectedManualScene != nil {
            awarenessEngine.resumeAutomatic()
            petView.showMessage("自动切换恢复啦！", duration: 3)
        } else {
            awarenessEngine.pause(for: 30 * 60)
            petView.showMessage("暂停感知 30 分钟，当前状态先不动。", duration: 4)
        }
        updateMenuStates()
    }

    @objc private func setOCRIntervalFast() {
        setOCRInterval(8)
    }

    @objc private func setOCRIntervalBalanced() {
        setOCRInterval(15)
    }

    @objc private func setOCRIntervalGentle() {
        setOCRInterval(30)
    }

    private func setOCRInterval(_ interval: TimeInterval) {
        awarenessEngine.setOCRInterval(interval)
        petView.showMessage("OCR 识别间隔：\(Int(interval)) 秒。", duration: 3)
        updateMenuStates()
    }

    @objc private func previewScene(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let scene = PetScene(rawValue: rawValue) else {
            return
        }
        awarenessEngine.preview(scene)
        updateMenuStates()
    }

    @objc private func showAwarenessPrivacy() {
        let alert = NSAlert()
        alert.messageText = "场景感知与隐私"
        alert.informativeText = """
        默认模式只读取当前前台 App 的名称，不需要屏幕权限。

        开启“本地屏幕 OCR”后，笑笑桌宠只截取当前前台窗口，在本机内存中识别文字；不保存截图、不写入识别文字、不联网、不上传。

        你可以随时从菜单关闭 OCR，或在系统设置中撤销屏幕录制权限。
        """
        alert.addButton(withTitle: "知道了")
        alert.addButton(withTitle: "打开屏幕权限设置")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            openScreenPermissionSettings()
        }
    }

    private func showScreenPermissionHelp() {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = """
        本地 OCR 需要 macOS 的“屏幕与系统音频录制”权限。识别只在本机完成，不保存或上传画面。

        授权后若没有立即生效，请退出并重新打开笑笑桌宠。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "暂不开启")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenPermissionSettings()
        }
    }

    private func openScreenPermissionSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func idleMoment() {
        if let quietUntil, Date() >= quietUntil {
            self.quietUntil = nil
            updateMenuStates()
        }
        guard panel.isVisible, !clickThrough, quietUntil == nil else {
            return
        }
        petView.showMessage(currentScene.idlePhrases.randomElement()!, duration: 4)
        if Int.random(in: 0...2) == 0 {
            petView.bounce()
        }
    }

    @objc func pat() {
        let phrases = [
            "嘿嘿，再摸一下～",
            "摸头成功！陪伴值上升。",
            "头发不要摸乱啦！",
            "被你抓到啦 ♥︎",
            "今日份摸摸收到～"
        ]
        let update = recordCompanion(.pat)
        showInteractionMessage(
            phrases.randomElement()!,
            update: update,
            duration: 3.6
        )
        petView.patReaction()
        playSound(named: "Pop")
    }

    @objc func feed() {
        let foods = ["🍪", "🍓", "🍡", "🥟", "🍰"]
        let food = foods.randomElement()!
        let update = recordCompanion(.feed)
        showInteractionMessage(
            "\(food) 嗷呜！这口算你的～",
            update: update,
            duration: 3.8
        )
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
        let update = recordCompanion(.praise)
        showInteractionMessage(
            phrases.randomElement()!,
            update: update,
            duration: 3.8
        )
        petView.celebrate(symbols: ["♥︎", "✨", "✦"], count: 14)
        petView.wiggle()
    }

    @objc func fortune() {
        let update = recordCompanion(.fortune)
        showInteractionMessage(
            CompanionDailyContent.fortune(),
            update: update,
            duration: 6
        )
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
        let update = recordCompanion(.walk)
        showInteractionMessage(
            "出发！换个地方摸鱼～",
            update: update,
            duration: 3.5
        )
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

    @discardableResult
    private func recordCompanion(_ action: CompanionAction) -> CompanionUpdate {
        let update = companionStore.record(action)
        updateMenuStates()
        return update
    }

    private func showInteractionMessage(
        _ regularMessage: String,
        update: CompanionUpdate,
        duration: TimeInterval
    ) {
        if update.didLevelUp {
            petView.showMessage(
                "升级啦！Lv.\(update.after.level) · \(update.after.levelTitle) ✨",
                duration: 5
            )
            petView.party()
        } else if update.didCompleteDailyCare {
            petView.showMessage(
                "今日照顾全部完成！连续 \(update.after.streak) 天 🔥",
                duration: 5
            )
            petView.party()
        } else if update.isFirstCareToday {
            petView.showMessage(
                "\(regularMessage)  今日 \(update.after.completedCareCount)"
                    + "/\(update.after.careGoal) ✓",
                duration: duration
            )
        } else {
            petView.showMessage(regularMessage, duration: duration)
        }
    }

    @objc func hideForFiveMinutes() {
        panel.orderOut(nil)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.bringBack()
        }
    }

    @objc func bringBack() {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main
        if let visible = targetScreen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: visible.maxX - panel.frame.width - 24,
                y: visible.minY + 20
            ))
            savePosition()
        } else {
            constrainToVisibleScreen()
        }
        panel.orderFrontRegardless()
        petView.showMessage("我回来啦！", duration: 3)
        petView.bounce()
    }

    @objc func saySomething() {
        panel.orderFrontRegardless()
        petView.showMessage(currentScene.idlePhrases.randomElement()!, duration: 4)
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
        findMenuItem(tag: 101, in: menu)?.state = clickThrough ? .on : .off
        let isQuiet = quietUntil.map { $0 > Date() } ?? false
        findMenuItem(tag: 102, in: menu)?.state = isQuiet ? .on : .off
        findMenuItem(tag: 201, in: menu)?.state = abs(petScale - 0.60) < 0.025 ? .on : .off
        findMenuItem(tag: 202, in: menu)?.state = abs(petScale - 0.74) < 0.025 ? .on : .off
        findMenuItem(tag: 203, in: menu)?.state = abs(petScale - 1.00) < 0.025 ? .on : .off
        findMenuItem(tag: 301, in: menu)?.state = awarenessEngine.isEnabled ? .on : .off
        findMenuItem(tag: 302, in: menu)?.state = awarenessEngine.isOCREnabled ? .on : .off
        findMenuItem(tag: 302, in: menu)?.isEnabled = awarenessEngine.isEnabled
        findMenuItem(tag: 305, in: menu)?.title = "当前：\(currentScene.emoji) \(currentScene.title)"
        findMenuItem(tag: 306, in: menu)?.title = awarenessSourceMenuTitle()
        let isOverridden = awarenessEngine.isPaused || awarenessEngine.selectedManualScene != nil
        findMenuItem(tag: 303, in: menu)?.title = isOverridden
            ? "▶️ 恢复自动切换"
            : "⏸ 暂停感知 30 分钟"
        findMenuItem(tag: 311, in: menu)?.state = abs(awarenessEngine.ocrInterval - 8) < 0.5 ? .on : .off
        findMenuItem(tag: 312, in: menu)?.state = abs(awarenessEngine.ocrInterval - 15) < 0.5 ? .on : .off
        findMenuItem(tag: 313, in: menu)?.state = abs(awarenessEngine.ocrInterval - 30) < 0.5 ? .on : .off
        findMenuItem(tag: 401, in: menu)?.title = companionMenuTitle()
        controlCenter?.update(makeControlCenterState())
    }

    private func findMenuItem(tag: Int, in menu: NSMenu) -> NSMenuItem? {
        for item in menu.items {
            if item.tag == tag {
                return item
            }
            if let submenu = item.submenu,
               let match = findMenuItem(tag: tag, in: submenu) {
                return match
            }
        }
        return nil
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
                x: visible.maxX - panel.frame.width - 24,
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
    private let logicalSize = NSSize(width: 320, height: 430)
    private var animationTimer: Timer?
    private var particles: [PetParticle] = []
    private var message: String?
    private var messageEndsAt: TimeInterval = 0
    private var scene: PetScene = .companion
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
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("笑笑桌宠")
        setAccessibilityValue(scene.title)
        setAccessibilityHelp(
            "按下可摸摸，双击可庆祝，拖动可换位置，右键打开互动菜单"
        )
        setAccessibilityIdentifier("smile-desktop-pet")

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
        guard displayScale > 0 else { return }
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.scaleBy(x: displayScale, y: displayScale)
        drawSceneBackdrop()
        drawPet()
        drawSceneDecorations()
        drawParticles()
        drawSceneBadge()
        drawBubble()
        context?.restoreGState()
    }

    private func petRect() -> NSRect {
        let area = NSRect(x: 18, y: 8, width: logicalSize.width - 36, height: 352)
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
        var verticalOffset: CGFloat
        var rotation: CGFloat = 0
        var scale: CGFloat = 1

        switch scene.motion {
        case .calm:
            verticalOffset = sin(phase) * 3
        case .focus:
            verticalOffset = sin(phase * 0.62) * 1.4
            scale -= 0.008
        case .busy:
            verticalOffset = abs(sin(phase * 1.7)) * 2.2
            rotation += sin(phase * 1.7) * 0.8
        case .panic:
            verticalOffset = abs(sin(phase * 4.5)) * 4
            rotation += sin(phase * 6.5) * 2.8
        case .dance:
            verticalOffset = abs(sin(phase * 2.8)) * 8
            rotation += sin(phase * 2.8) * 4.5
        case .sleepy:
            verticalOffset = sin(phase * 0.35) * 1.2
            rotation -= 1.2
            scale -= 0.015
        case .celebrate:
            verticalOffset = abs(sin(phase * 3.2)) * 7
            rotation += sin(phase * 3.2) * 3
        }

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

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            verticalOffset = 0
            rotation = 0
            scale = 1
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

    private func drawSceneBackdrop() {
        let glowRect = NSRect(x: 43, y: 12, width: 234, height: 52)
        let glow = NSBezierPath(ovalIn: glowRect)
        scene.accentColor.withAlphaComponent(0.16).setFill()
        glow.fill()

        let innerRect = glowRect.insetBy(dx: 28, dy: 10)
        scene.accentColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(ovalIn: innerRect).fill()
    }

    private func drawSceneDecorations() {
        let symbols = scene.ambientSymbols
        let positions = [
            NSPoint(x: 38, y: 246),
            NSPoint(x: 268, y: 225),
            NSPoint(x: 49, y: 116)
        ]

        for index in 0..<min(symbols.count, positions.count) {
            let floatOffset = sin(phase * 1.2 + CGFloat(index) * 1.8) * 7
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(
                    ofSize: symbols[index].count > 2 ? 13 : 19,
                    weight: .bold
                ),
                .foregroundColor: scene.accentColor.withAlphaComponent(0.82)
            ]
            let value = symbols[index] as NSString
            let size = value.size(withAttributes: attributes)
            value.draw(
                at: NSPoint(
                    x: positions[index].x - size.width / 2,
                    y: positions[index].y + floatOffset
                ),
                withAttributes: attributes
            )
        }

        if scene == .jailWork {
            drawJailBars()
        } else if scene == .meeting {
            drawCornerProp("🔇")
        } else if scene == .reading {
            drawCornerProp("📖")
        } else if scene == .coding {
            drawCornerProp("⌨️")
        } else if scene == .finance {
            drawCornerProp("📈")
        } else if scene == .music {
            drawCornerProp("🎧")
        }
    }

    private func drawJailBars() {
        let barColor = NSColor(calibratedWhite: 0.19, alpha: 0.19)
        barColor.setStroke()
        for x in stride(from: CGFloat(58), through: CGFloat(262), by: 34) {
            let bar = NSBezierPath()
            bar.lineWidth = 5
            bar.lineCapStyle = .round
            bar.move(to: NSPoint(x: x, y: 55))
            bar.line(to: NSPoint(x: x, y: 315))
            bar.stroke()
        }
        for y in [CGFloat(88), CGFloat(289)] {
            let rail = NSBezierPath()
            rail.lineWidth = 7
            rail.move(to: NSPoint(x: 48, y: y))
            rail.line(to: NSPoint(x: 272, y: y))
            rail.stroke()
        }
    }

    private func drawCornerProp(_ prop: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28),
            .foregroundColor: NSColor.white
        ]
        (prop as NSString).draw(
            at: NSPoint(x: 236, y: 73 + sin(phase * 1.4) * 3),
            withAttributes: attributes
        )
    }

    private func drawSceneBadge() {
        guard message == nil else { return }
        let badgeRect = NSRect(x: 69, y: 376, width: 182, height: 32)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 16, yRadius: 16)
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 7
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        let highlight = scene.accentColor.blended(
            withFraction: 0.22,
            of: .white
        ) ?? scene.accentColor
        NSGradient(
            starting: highlight.withAlphaComponent(0.97),
            ending: scene.accentColor.withAlphaComponent(0.97)
        )?.draw(in: badge, angle: 0)
        NSColor.white.withAlphaComponent(0.32).setStroke()
        badge.lineWidth = 1
        badge.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSGraphicsContext.current?.saveGraphicsState()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        ("\(scene.emoji) \(scene.title)" as NSString).draw(
            with: badgeRect.insetBy(dx: 8, dy: 7),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawBubble() {
        guard let message else { return }
        let bubbleRect = NSRect(x: 8, y: 350, width: logicalSize.width - 16, height: 70)
        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 20, yRadius: 20)
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        NSGradient(
            starting: NSColor.white.withAlphaComponent(0.98),
            ending: NSColor(calibratedRed: 1.0, green: 0.965, blue: 0.93, alpha: 0.98)
        )?.draw(in: bubble, angle: -90)
        scene.accentColor.withAlphaComponent(0.24).setStroke()
        bubble.lineWidth = 1.2
        bubble.stroke()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bubbleRect.midX - 10, y: bubbleRect.minY + 1))
        tail.line(to: NSPoint(x: bubbleRect.midX + 12, y: bubbleRect.minY + 1))
        tail.line(to: NSPoint(x: bubbleRect.midX + 2, y: bubbleRect.minY - 13))
        tail.close()
        NSColor(calibratedRed: 1.0, green: 0.965, blue: 0.93, alpha: 0.98).setFill()
        tail.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        let iconRect = NSRect(x: bubbleRect.minX + 14, y: bubbleRect.midY - 18, width: 36, height: 36)
        scene.accentColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: iconRect, xRadius: 12, yRadius: 12).fill()
        let iconParagraph = NSMutableParagraphStyle()
        iconParagraph.alignment = .center
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .paragraphStyle: iconParagraph
        ]
        (scene.emoji as NSString).draw(
            with: iconRect.insetBy(dx: 2, dy: 7),
            options: [.usesLineFragmentOrigin],
            attributes: iconAttributes
        )

        NSGraphicsContext.current?.saveGraphicsState()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.14, blue: 0.13, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let textRect = NSRect(
            x: iconRect.maxX + 10,
            y: bubbleRect.minY + 11,
            width: bubbleRect.maxX - iconRect.maxX - 22,
            height: bubbleRect.height - 22
        )
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

    func setScene(_ newScene: PetScene) {
        scene = newScene
        setAccessibilityValue(newScene.title)
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
        celebrate(symbols: ["♥︎", "♥︎", "✨"], count: 8, origin: NSPoint(x: logicalSize.width / 2, y: 275))
    }

    func party() {
        spinStartedAt = ProcessInfo.processInfo.systemUptime
        celebrate(symbols: ["♥︎", "✨", "✦", "●"], count: 28)
    }

    func feed(with food: String) {
        celebrate(symbols: [food, "♥︎", "✨"], count: 12, origin: NSPoint(x: logicalSize.width / 2, y: 205))
        bounce()
    }

    func celebrate(
        symbols: [String],
        count: Int,
        origin: NSPoint? = nil
    ) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let center = origin ?? NSPoint(x: logicalSize.width / 2, y: 225)
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
            let actualPoint = convert(event.locationInWindow, from: nil)
            controller?.tapped(
                at: NSPoint(
                    x: actualPoint.x / displayScale,
                    y: actualPoint.y / displayScale
                )
            )
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            controller?.adjustScale(by: event.scrollingDeltaY)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = controller?.contextualMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func accessibilityPerformPress() -> Bool {
        controller?.pat()
        return true
    }

    private var displayScale: CGFloat {
        min(bounds.width / logicalSize.width, bounds.height / logicalSize.height)
    }
}
