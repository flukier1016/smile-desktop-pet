import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision

enum PetMotion {
    case calm
    case focus
    case busy
    case panic
    case dance
    case sleepy
    case celebrate
}

enum PetScene: String, CaseIterable {
    case companion
    case coding
    case debugging
    case success
    case spreadsheet
    case finance
    case jailWork
    case writing
    case reading
    case research
    case presentation
    case meeting
    case messaging
    case email
    case design
    case browsing
    case entertainment
    case music
    case gaming
    case shopping
    case breakTime
    case away
    case lateNight

    var title: String {
        switch self {
        case .companion: return "陪伴待机"
        case .coding: return "认真写代码"
        case .debugging: return "报错抢救中"
        case .success: return "胜利撒花"
        case .spreadsheet: return "表格苦工"
        case .finance: return "盯盘模式"
        case .jailWork: return "工位服刑"
        case .writing: return "奋笔疾书"
        case .reading: return "安静读书"
        case .research: return "资料侦探"
        case .presentation: return "汇报冲刺"
        case .meeting: return "开会静音"
        case .messaging: return "消息轰炸"
        case .email: return "邮件清零"
        case .design: return "灵感施工"
        case .browsing: return "网上冲浪"
        case .entertainment: return "快乐摸鱼"
        case .music: return "跟着摇摆"
        case .gaming: return "游戏助威"
        case .shopping: return "购物冷静期"
        case .breakTime: return "合法休息"
        case .away: return "等你回来"
        case .lateNight: return "深夜劝退"
        }
    }

    var emoji: String {
        switch self {
        case .companion: return "🌸"
        case .coding: return "💻"
        case .debugging: return "🚨"
        case .success: return "🎉"
        case .spreadsheet: return "📊"
        case .finance: return "📈"
        case .jailWork: return "⛓️"
        case .writing: return "✍️"
        case .reading: return "📖"
        case .research: return "🔎"
        case .presentation: return "🖥️"
        case .meeting: return "🎙️"
        case .messaging: return "💬"
        case .email: return "📨"
        case .design: return "🎨"
        case .browsing: return "🌐"
        case .entertainment: return "🍿"
        case .music: return "🎵"
        case .gaming: return "🎮"
        case .shopping: return "🛒"
        case .breakTime: return "☕"
        case .away: return "💤"
        case .lateNight: return "🌙"
        }
    }

    var accentColor: NSColor {
        switch self {
        case .debugging: return NSColor(calibratedRed: 0.93, green: 0.25, blue: 0.25, alpha: 1)
        case .success: return NSColor(calibratedRed: 0.16, green: 0.72, blue: 0.42, alpha: 1)
        case .coding: return NSColor(calibratedRed: 0.35, green: 0.53, blue: 0.95, alpha: 1)
        case .spreadsheet, .finance: return NSColor(calibratedRed: 0.12, green: 0.66, blue: 0.45, alpha: 1)
        case .jailWork: return NSColor(calibratedWhite: 0.31, alpha: 1)
        case .writing, .reading, .research: return NSColor(calibratedRed: 0.70, green: 0.47, blue: 0.24, alpha: 1)
        case .presentation, .meeting: return NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.88, alpha: 1)
        case .messaging, .email: return NSColor(calibratedRed: 0.19, green: 0.62, blue: 0.88, alpha: 1)
        case .design: return NSColor(calibratedRed: 0.94, green: 0.36, blue: 0.63, alpha: 1)
        case .entertainment, .music, .gaming: return NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.32, alpha: 1)
        case .shopping: return NSColor(calibratedRed: 0.93, green: 0.36, blue: 0.50, alpha: 1)
        case .away, .lateNight: return NSColor(calibratedRed: 0.31, green: 0.38, blue: 0.58, alpha: 1)
        case .companion, .browsing, .breakTime: return NSColor(calibratedRed: 0.90, green: 0.31, blue: 0.35, alpha: 1)
        }
    }

    var ambientSymbols: [String] {
        switch self {
        case .companion: return ["♥︎", "✦"]
        case .coding: return ["⌘", "{ }", "</>"]
        case .debugging: return ["!", "×", "⚠︎"]
        case .success: return ["✓", "★", "✦"]
        case .spreadsheet: return ["Σ", "%", "▦"]
        case .finance: return ["↗", "$", "¥"]
        case .jailWork: return ["...", "DDL", "⏱"]
        case .writing: return ["✎", "A", "…"]
        case .reading: return ["📚", "「」", "…"]
        case .research: return ["?", "⌕", "✦"]
        case .presentation: return ["▶", "◆", "01"]
        case .meeting: return ["🔇", "…", "✓"]
        case .messaging: return ["●", "99+", "…"]
        case .email: return ["@", "↩", "✓"]
        case .design: return ["◇", "✦", "◯"]
        case .browsing: return ["⌁", "www", "↗"]
        case .entertainment: return ["▶", "🍿", "✦"]
        case .music: return ["♪", "♫", "♬"]
        case .gaming: return ["+1", "★", "⚡"]
        case .shopping: return ["¥", "%", "♡"]
        case .breakTime: return ["☕", "～", "✦"]
        case .away: return ["z", "Z", "…"]
        case .lateNight: return ["☾", "z", "✦"]
        }
    }

    var motion: PetMotion {
        switch self {
        case .coding, .spreadsheet, .finance, .writing, .reading, .research, .presentation:
            return .focus
        case .debugging:
            return .panic
        case .success:
            return .celebrate
        case .jailWork, .meeting, .email:
            return .busy
        case .entertainment, .music, .gaming:
            return .dance
        case .away, .lateNight:
            return .sleepy
        default:
            return .calm
        }
    }

    var arrivalPhrases: [String] {
        switch self {
        case .companion: return ["我陪着你，慢慢来～", "桌面巡逻员已就位！"]
        case .coding: return ["代码护法上线，今天也要一次跑通！", "我盯着括号，你放心写。"]
        case .debugging: return ["别慌！报错只是代码在撒娇。", "红字出现，抢救小队集合！"]
        case .success: return ["通过啦！这不得撒个花？", "胜利！快乐加载到 100%！"]
        case .spreadsheet: return ["表格打开，灵魂自动网格化。", "这一格填完，还有下一格。"]
        case .finance: return ["盯盘开始，先稳住心跳。", "K 线可以动，纪律不能动。"]
        case .jailWork: return ["欢迎来到工位服刑现场。", "今日刑期：直到文件保存成功。"]
        case .writing: return ["灵感开机，先写出来再说。", "空白页别怕，我陪你填满。"]
        case .reading: return ["嘘，书虫模式启动。", "翻一页，脑袋升级一点点。"]
        case .research: return ["资料侦探出动，线索别想跑。", "让我看看这条引用靠不靠谱。"]
        case .presentation: return ["汇报模式！字少一点，重点大一点。", "下一页一定是全场最佳。"]
        case .meeting: return ["开会啦，我先替你静音。", "表情管理已上线，灵魂稍后回来。"]
        case .messaging: return ["消息好多，我帮你守住红点！", "先回最重要的，其他慢慢来。"]
        case .email: return ["收件箱清零行动开始。", "一封一封回，不和红点硬刚。"]
        case .design: return ["灵感施工中，闲人请绕行。", "这个颜色，有点东西！"]
        case .browsing: return ["网上冲浪，记得别漂太远。", "我只是查资料，真的。"]
        case .entertainment: return ["摸鱼雷达已锁定！", "这段看完就工作，对吧？"]
        case .music: return ["节拍来了，肩膀借我摇一下！", "今日桌面演唱会正式开场。"]
        case .gaming: return ["我负责加油，你负责别上头！", "胜负先放一边，操作要帅。"]
        case .shopping: return ["先加入购物车，冷静十分钟。", "买前问三遍：真的需要吗？"]
        case .breakTime: return ["合法休息开始，谁都不许催。", "喝口水，眼睛也放个假。"]
        case .away: return ["你先忙，我在这里打个盹。", "离开检测到，替你守桌面。"]
        case .lateNight: return ["这么晚还在忙？下班警报！", "月亮都打卡了，你怎么还没走？"]
        }
    }

    var idlePhrases: [String] {
        switch self {
        case .coding: return ["先跑测试，再宣布胜利。", "这行看起来很可疑，我盯住它了。", "保存了吗？我只是提醒一下。"]
        case .debugging: return ["从第一条报错开始看，别被红色吓到。", "复现、定位、修掉，三步走！"]
        case .success: return ["测试绿了，今天你就是版本之神。", "这个提交值得一块小蛋糕！"]
        case .spreadsheet: return ["合并单元格，职场危险动作。", "公式别拖错列，我看着呢。"]
        case .finance: return ["不追涨，不上头，先看风险。", "数字会说话，日期也要一起看。"]
        case .jailWork: return ["工位无期，咖啡缓刑。", "再坚持五分钟，然后真的休息。"]
        case .writing: return ["先完成，再完美。", "删掉一句废话，文章轻了一点。"]
        case .reading: return ["看到重点记一下，未来的你会感谢。", "读累了就眺望二十秒。"]
        case .research: return ["来源、日期、口径，一个都不能少。", "二手转述先放旁边，找原文！"]
        case .presentation: return ["一页只讲一个重点。", "字号再大点，后排也想活。"]
        case .meeting: return ["这段能不能变成一句行动项？", "会议纪要：谁、做什么、什么时候。"]
        case .messaging: return ["红点不是 KPI，先做重要的。", "能一句说清，就别发九段语音。"]
        case .email: return ["能归档的别让它继续住在收件箱。", "标题写清楚，未来少找十分钟。"]
        case .design: return ["对齐一下，世界和平。", "留白不是空，是呼吸。"]
        case .browsing: return ["第几个标签页了？", "查完这条就回来，我记住了。"]
        case .entertainment: return ["下一集按钮很危险。", "摸鱼可以，记得浮上来呼吸。"]
        case .music: return ["这首可以！桌面舞池继续。", "音量别太大，耳朵也要下班。"]
        case .gaming: return ["输了不气，赢了不飘。", "坐直一点，下一把更稳。"]
        case .shopping: return ["收藏不等于购买，钱包松了口气。", "先比价，再看退货规则。"]
        case .breakTime: return ["休息不是偷懒，是续航。", "肩膀放松，深呼吸一下。"]
        case .away: return ["Zzz…桌面一切正常。", "我替你守着，放心去吧。"]
        case .lateNight: return ["保存、提交、关电脑，一气呵成。", "明天的脑子会比现在好用。"]
        case .companion: return ["你工作，我负责可爱。", "喝水了吗？我看着你呢。"]
        }
    }

    static let workScenes: [PetScene] = [
        .coding, .debugging, .success, .spreadsheet, .finance,
        .jailWork, .writing, .research, .presentation
    ]

    static let communicationScenes: [PetScene] = [
        .meeting, .messaging, .email, .design, .reading
    ]

    static let lifeScenes: [PetScene] = [
        .browsing, .entertainment, .music, .gaming, .shopping,
        .breakTime, .away, .lateNight, .companion
    ]
}

struct AwarenessSnapshot {
    let appName: String
    let bundleIdentifier: String
    let windowTitle: String
    let usedOCR: Bool
    let idleSeconds: TimeInterval
    let activeDuration: TimeInterval
    let capturedAt: Date

    var sourceLabel: String {
        usedOCR ? "前台 App＋本地 OCR" : "前台 App"
    }
}

enum AwarenessClassifier {
    static func classify(
        appName: String,
        bundleIdentifier: String,
        windowTitle: String,
        ocrText: String,
        idleSeconds: TimeInterval,
        activeDuration: TimeInterval,
        hour: Int
    ) -> PetScene {
        let app = "\(appName) \(bundleIdentifier)".lowercased()
        let visibleText = "\(windowTitle) \(ocrText)".lowercased()
        let all = "\(app) \(visibleText)"

        if idleSeconds >= 300 {
            return .away
        }

        let isLateNight = hour >= 23 || hour < 6

        let codingApp = containsAny(app, [
            "xcode", "visual studio code", "vscode", "cursor", "codex",
            "terminal", "iterm", "warp", "android studio", "intellij",
            "pycharm", "webstorm", "sublime", "zed", "github desktop",
            "claude", "chatgpt"
        ])

        if codingApp && containsAny(visibleText, [
            "build failed", "test failed", "tests failed", "fatal error",
            "uncaught exception", "traceback", "segmentation fault",
            "编译失败", "测试失败", "报错", "异常", "失败:"
        ]) {
            return .debugging
        }

        if codingApp && containsAny(visibleText, [
            "build succeeded", "tests passed", "test passed", "all tests passed",
            "0 failures", "successfully built", "部署成功", "构建成功", "测试通过"
        ]) {
            return .success
        }

        if containsAny(all, [
            "zoom.us", "microsoft teams", "facetime", "webex", "google meet",
            "腾讯会议", "飞书会议", "钉钉会议", "会议中", "meeting"
        ]) {
            return .meeting
        }

        if containsAny(all, [
            "bloomberg", "wind金融", "万得", "同花顺", "东方财富",
            "tradingview", "interactive brokers", "ibkr", "refinitiv",
            "富途", "老虎证券", "行情", "market data", "portfolio"
        ]) {
            return .finance
        }

        if containsAny(app, [
            "microsoft excel", "com.microsoft.excel", "numbers", "libreoffice calc"
        ]) {
            return activeDuration >= 50 * 60 ? .jailWork : .spreadsheet
        }

        if codingApp {
            return activeDuration >= 75 * 60 ? .jailWork : .coding
        }

        if containsAny(all, [
            "powerpoint", "keynote", "google slides", "演示文稿", "幻灯片"
        ]) {
            return .presentation
        }

        if containsAny(app, [
            "microsoft word", "com.microsoft.word", "pages", "ulysses",
            "obsidian", "typora", "bear", "notion"
        ]) {
            return activeDuration >= 60 * 60 ? .jailWork : .writing
        }

        if containsAny(app, [
            "preview", "books", "kindle", "calibre", "pdf expert", "adobe acrobat"
        ]) || containsAny(visibleText, [".pdf", "电子书", "阅读器"]) {
            return .reading
        }

        if containsAny(all, [
            "arxiv", "google scholar", "semantic scholar", "researchgate",
            "jstor", "ssrn", "知网", "万方", "论文", "research paper"
        ]) {
            return .research
        }

        if containsAny(app, [
            "figma", "sketch", "adobe photoshop", "illustrator",
            "affinity designer", "pixelmator", "canva"
        ]) {
            return .design
        }

        if containsAny(app, [
            "slack", "discord", "messages", "wechat", "微信", "telegram",
            "whatsapp", "line", "飞书", "lark", "钉钉"
        ]) {
            return .messaging
        }

        if containsAny(app, [
            "mail", "outlook", "thunderbird", "spark"
        ]) || containsAny(visibleText, ["gmail", "收件箱", "inbox"]) {
            return .email
        }

        if containsAny(all, [
            "spotify", "music.app", "apple music", "netease music",
            "网易云音乐", "qq音乐", "music.youtube"
        ]) {
            return .music
        }

        if containsAny(all, [
            "youtube", "bilibili", "netflix", "disney+", "youku",
            "优酷", "爱奇艺", "腾讯视频", "芒果tv", "twitch"
        ]) {
            return .entertainment
        }

        if containsAny(app, [
            "steam", "epic games", "battle.net", "minecraft",
            "league of legends", "genshin", "原神"
        ]) {
            return .gaming
        }

        if containsAny(all, [
            "taobao", "淘宝", "tmall", "天猫", "jd.com", "京东",
            "amazon", "拼多多", "小红书商城", "shopping cart", "购物车"
        ]) {
            return .shopping
        }

        if isLateNight {
            return .lateNight
        }

        if containsAny(app, [
            "safari", "google chrome", "arc", "firefox", "microsoft edge", "orion"
        ]) {
            return .browsing
        }

        if containsAny(app, [
            "calendar", "reminders", "things", "todoist", "omnifocus"
        ]) {
            return .jailWork
        }

        if containsAny(app, [
            "finder", "launchpad", "system settings", "系统设置"
        ]) {
            return .breakTime
        }

        return .companion
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

final class AwarenessEngine {
    private let defaults = UserDefaults.standard
    private let scanQueue = DispatchQueue(label: "com.local.smile-desktop-pet.awareness", qos: .utility)
    private var timer: Timer?
    private var isScanning = false
    private var lastOCRDate = Date.distantPast
    private var lastOCRText = ""
    private var lastExternalApplication: NSRunningApplication?
    private var lastBundleIdentifier = ""
    private var lastDeliveredBundleIdentifier = ""
    private var activeSince = Date()
    private var lastScene: PetScene = .companion
    private var lastSceneChange = Date.distantPast
    private var manualScene: PetScene?
    private var pausedUntil: Date?

    var onSceneChange: ((PetScene, AwarenessSnapshot) -> Void)?
    var onSnapshot: ((AwarenessSnapshot, PetScene) -> Void)?
    var onPermissionProblem: (() -> Void)?

    var isEnabled: Bool {
        let value = defaults.object(forKey: "awarenessEnabled")
        return value == nil ? true : defaults.bool(forKey: "awarenessEnabled")
    }

    var isOCREnabled: Bool {
        defaults.bool(forKey: "screenOCREnabled")
    }

    var ocrInterval: TimeInterval {
        let saved = defaults.double(forKey: "ocrInterval")
        return saved >= 5 ? saved : 15
    }

    var isPaused: Bool {
        pausedUntil.map { $0 > Date() } ?? false
    }

    var selectedManualScene: PetScene? {
        manualScene
    }

    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 4,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        refreshNow()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "awarenessEnabled")
        if enabled {
            pausedUntil = nil
            manualScene = nil
            lastScene = .companion
            lastSceneChange = .distantPast
            refreshNow()
        }
    }

    func setOCREnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "screenOCREnabled")
        lastOCRDate = .distantPast
        if !enabled {
            lastOCRText = ""
        }
        refreshNow()
    }

    func setOCRInterval(_ interval: TimeInterval) {
        defaults.set(interval, forKey: "ocrInterval")
        lastOCRDate = .distantPast
        refreshNow()
    }

    func pause(for duration: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(duration)
    }

    func resumeAutomatic() {
        pausedUntil = nil
        manualScene = nil
        refreshNow()
    }

    func preview(_ scene: PetScene) {
        manualScene = scene
        pausedUntil = nil
        let snapshot = baseSnapshot(usedOCR: false)
        deliver(scene: scene, snapshot: snapshot, force: true)
    }

    func requestScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }

    func refreshNow() {
        guard isEnabled, !isPaused else { return }
        if let manualScene {
            let snapshot = baseSnapshot(usedOCR: false)
            deliver(scene: manualScene, snapshot: snapshot, force: false)
            return
        }
        scan()
    }

    @objc private func timerFired() {
        if let pausedUntil, pausedUntil <= Date() {
            self.pausedUntil = nil
        }
        refreshNow()
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true

        let application = externalFrontmostApplication()
        updateActiveDuration(for: application?.bundleIdentifier ?? application?.localizedName ?? "")
        let appName = application?.localizedName ?? "桌面"
        let bundleID = application?.bundleIdentifier ?? ""
        let activeDuration = Date().timeIntervalSince(activeSince)
        let idleSeconds = secondsSinceLastInput()
        let shouldUseOCR = isOCREnabled && hasScreenCapturePermission
            && Date().timeIntervalSince(lastOCRDate) >= ocrInterval

        guard shouldUseOCR, let pid = application?.processIdentifier else {
            let snapshot = AwarenessSnapshot(
                appName: appName,
                bundleIdentifier: bundleID,
                windowTitle: "",
                usedOCR: isOCREnabled && hasScreenCapturePermission,
                idleSeconds: idleSeconds,
                activeDuration: activeDuration,
                capturedAt: Date()
            )
            finishScan(snapshot: snapshot, ocrText: lastOCRText)
            return
        }

        lastOCRDate = Date()
        recognizeFrontWindow(processIdentifier: pid) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.lastOCRText = result.text
                let snapshot = AwarenessSnapshot(
                    appName: appName,
                    bundleIdentifier: bundleID,
                    windowTitle: result.title,
                    usedOCR: true,
                    idleSeconds: idleSeconds,
                    activeDuration: activeDuration,
                    capturedAt: Date()
                )
                self.finishScan(snapshot: snapshot, ocrText: result.text)
            }
        }
    }

    private func finishScan(snapshot: AwarenessSnapshot, ocrText: String) {
        let hour = Calendar.current.component(.hour, from: snapshot.capturedAt)
        let scene = AwarenessClassifier.classify(
            appName: snapshot.appName,
            bundleIdentifier: snapshot.bundleIdentifier,
            windowTitle: snapshot.windowTitle,
            ocrText: ocrText,
            idleSeconds: snapshot.idleSeconds,
            activeDuration: snapshot.activeDuration,
            hour: hour
        )
        isScanning = false
        deliver(scene: scene, snapshot: snapshot, force: false)
    }

    private func deliver(scene: PetScene, snapshot: AwarenessSnapshot, force: Bool) {
        onSnapshot?(snapshot, scene)
        let appChanged = snapshot.bundleIdentifier != lastDeliveredBundleIdentifier
        lastDeliveredBundleIdentifier = snapshot.bundleIdentifier
        let holdSpecialScene = [.debugging, .success].contains(lastScene)
            && Date().timeIntervalSince(lastSceneChange) < 16
            && !appChanged
        guard force || scene != lastScene else { return }
        guard force || !holdSpecialScene else { return }

        lastScene = scene
        lastSceneChange = Date()
        onSceneChange?(scene, snapshot)
    }

    private func externalFrontmostApplication() -> NSRunningApplication? {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalApplication = current
        }
        return lastExternalApplication ?? current
    }

    private func updateActiveDuration(for identifier: String) {
        guard identifier != lastBundleIdentifier else { return }
        lastBundleIdentifier = identifier
        activeSince = Date()
        lastOCRText = ""
        lastOCRDate = .distantPast
    }

    private func baseSnapshot(usedOCR: Bool) -> AwarenessSnapshot {
        let application = externalFrontmostApplication()
        return AwarenessSnapshot(
            appName: application?.localizedName ?? "桌面",
            bundleIdentifier: application?.bundleIdentifier ?? "",
            windowTitle: "",
            usedOCR: usedOCR,
            idleSeconds: secondsSinceLastInput(),
            activeDuration: Date().timeIntervalSince(activeSince),
            capturedAt: Date()
        )
    }

    private func secondsSinceLastInput() -> TimeInterval {
        let eventTypes: [CGEventType] = [
            .keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved,
            .leftMouseDragged, .rightMouseDragged, .scrollWheel
        ]
        return eventTypes
            .map {
                CGEventSource.secondsSinceLastEventType(
                    .combinedSessionState,
                    eventType: $0
                )
            }
            .min() ?? 0
    }

    private func recognizeFrontWindow(
        processIdentifier: pid_t,
        completion: @escaping ((title: String, text: String)) -> Void
    ) {
        if #available(macOS 14.0, *) {
            recognizeFrontWindowWithScreenCaptureKit(
                processIdentifier: processIdentifier,
                completion: completion
            )
        } else {
            scanQueue.async { [weak self] in
                guard let self,
                      let window = self.frontWindow(processIdentifier: processIdentifier),
                      let image = CGWindowListCreateImage(
                        .null,
                        .optionIncludingWindow,
                        window.id,
                        [.bestResolution, .boundsIgnoreFraming]
                      ) else {
                    completion(("", ""))
                    return
                }
                completion(self.recognizeText(in: image, title: window.title))
            }
        }
    }

    @available(macOS 14.0, *)
    private func recognizeFrontWindowWithScreenCaptureKit(
        processIdentifier: pid_t,
        completion: @escaping ((title: String, text: String)) -> Void
    ) {
        SCShareableContent.getExcludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        ) { [weak self] content, _ in
            guard let self, let content else {
                completion(("", ""))
                return
            }

            let candidates = content.windows.filter {
                $0.owningApplication?.processID == processIdentifier
                    && $0.windowLayer == 0
                    && $0.frame.width >= 160
                    && $0.frame.height >= 120
            }
            guard let window = candidates.first(where: { $0.isActive })
                    ?? candidates.max(by: {
                        $0.frame.width * $0.frame.height
                            < $1.frame.width * $1.frame.height
                    }) else {
                completion(("", ""))
                return
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            let longestSide = max(window.frame.width, window.frame.height)
            let pixelScale = min(2.0, 1800.0 / max(1, longestSide))
            configuration.width = max(1, Int(window.frame.width * pixelScale))
            configuration.height = max(1, Int(window.frame.height * pixelScale))
            configuration.scalesToFit = true
            configuration.showsCursor = false
            configuration.capturesAudio = false

            SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) { [weak self] image, _ in
                guard let self, let image else {
                    completion((window.title ?? "", ""))
                    return
                }
                self.scanQueue.async {
                    completion(
                        self.recognizeText(
                            in: image,
                            title: window.title ?? ""
                        )
                    )
                }
            }
        }
    }

    private func recognizeText(
        in image: CGImage,
        title: String
    ) -> (title: String, text: String) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.012

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            let text = observations
                .prefix(100)
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
            return (title, text)
        } catch {
            return (title, "")
        }
    }

    private func frontWindow(processIdentifier: pid_t) -> (id: CGWindowID, title: String)? {
        guard let rows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for row in rows {
            guard (row[kCGWindowOwnerPID as String] as? Int) == Int(processIdentifier),
                  (row[kCGWindowLayer as String] as? Int) == 0,
                  let number = row[kCGWindowNumber as String] as? Int,
                  let bounds = row[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  width >= 160,
                  height >= 120 else {
                continue
            }
            return (
                CGWindowID(number),
                row[kCGWindowName as String] as? String ?? ""
            )
        }
        return nil
    }
}
