import AppKit
import QuartzCore

private let appName = "笑笑桌宠"

#if !PET_TESTING
@main
#endif
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

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
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
        return saved.isFinite && saved > 0 ? CGFloat(min(1.10, max(0.55, saved))) : 0.74
    }()
    private var panel: PetPanel!
    private var petView: PetView!
    private var statusItem: NSStatusItem!
    private var idleTimer: Timer?
    private var hideTimer: Timer?
    private var quietTimer: Timer?
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenLayoutChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        awarenessEngine.start()
        showFirstRunCompanionWelcomeIfNeeded()
    }

    func stop() {
        idleTimer?.invalidate()
        hideTimer?.invalidate()
        quietTimer?.invalidate()
        awarenessEngine.stop()
        NotificationCenter.default.removeObserver(self)
    }

    private func updateBackgroundActivity(_ active: Bool) {
        awarenessEngine.setSuspended(!active)
        idleTimer?.invalidate()
        idleTimer = nil
        guard active, quietUntil == nil else { return }
        idleTimer = Timer(timeInterval: 11, repeats: true) { [weak self] _ in
            self?.idleMoment()
        }
        idleTimer?.tolerance = 1
        if let idleTimer { RunLoop.main.add(idleTimer, forMode: .common) }
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
        petView.onActivityChange = { [weak self] active in
            self?.updateBackgroundActivity(active)
        }
        awarenessEngine.onSnapshot = { [weak self] snapshot, _ in
            guard let self else { return }
            self.lastAwarenessSnapshot = snapshot
            self.updateMenuStates()
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
        hideTimer?.invalidate()
        panel.orderOut(nil)
        petView.refreshActivity()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.bringBack()
        }
    }

    @objc func bringBack() {
        hideTimer?.invalidate()
        hideTimer = nil
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
        petView.refreshActivity()
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
        quietTimer?.invalidate()
        quietTimer = nil
        if let quietUntil, quietUntil > Date() {
            self.quietUntil = nil
            panel.orderFrontRegardless()
            petView.showMessage("睡醒啦！继续营业～", duration: 3)
        } else {
            quietUntil = Date().addingTimeInterval(600)
            petView.showMessage("安静模式开启，十分钟后见～", duration: 4)
            quietTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.quietUntil = nil
                self.petView.isQuiet = false
                self.updateBackgroundActivity(self.petView.isActive)
                self.updateMenuStates()
            }
        }
        petView.isQuiet = quietUntil != nil
        updateBackgroundActivity(petView.isActive)
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
        if controlCenter?.isVisible == true {
            controlCenter?.update(makeControlCenterState())
        }
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
