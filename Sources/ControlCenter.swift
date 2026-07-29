import AppKit

private final class CompanionProgressBar: NSView {
    var progress: Double = 0 {
        didSet {
            progress = max(0, min(1, progress))
            needsDisplay = true
            setAccessibilityValue("\(Int(round(progress * 100)))%")
        }
    }

    var accentColor = NSColor.controlAccentColor {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("陪伴值升级进度")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let track = NSBezierPath(
            roundedRect: bounds,
            xRadius: bounds.height / 2,
            yRadius: bounds.height / 2
        )
        NSColor.separatorColor.withAlphaComponent(0.28).setFill()
        track.fill()

        let fillWidth = max(
            progress > 0 ? bounds.height : 0,
            bounds.width * CGFloat(progress)
        )
        guard fillWidth > 0 else { return }
        let fillRect = NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: min(bounds.width, fillWidth),
            height: bounds.height
        )
        let fill = NSBezierPath(
            roundedRect: fillRect,
            xRadius: bounds.height / 2,
            yRadius: bounds.height / 2
        )
        accentColor.setFill()
        fill.fill()
    }
}

struct ControlCenterState {
    let scene: PetScene
    let appName: String
    let source: String
    let awarenessEnabled: Bool
    let ocrEnabled: Bool
    let hasScreenPermission: Bool
    let isPaused: Bool
    let scale: CGFloat
    let ocrInterval: TimeInterval
    let companion: CompanionSnapshot
}

final class ControlCenterController: NSObject {
    var onAwarenessChanged: ((Bool) -> Void)?
    var onOCRChanged: ((Bool) -> Void)?
    var onScaleChanged: ((CGFloat) -> Void)?
    var onIntervalChanged: ((TimeInterval) -> Void)?
    var onRefresh: (() -> Void)?
    var onBringBack: (() -> Void)?
    var onPrivacy: (() -> Void)?
    var onPat: (() -> Void)?
    var onFeed: (() -> Void)?
    var onPraise: (() -> Void)?
    var onFortune: (() -> Void)?
    var onWalk: (() -> Void)?
    var onCelebrate: (() -> Void)?

    private var panel: NSPanel?

    private let sceneCard = NSView()
    private let sceneIconLabel = NSTextField(labelWithString: "🌸")
    private let sceneTitleLabel = NSTextField(labelWithString: "陪伴待机")
    private let sceneDetailLabel = NSTextField(labelWithString: "桌面 · 前台 App")
    private let statusPillLabel = NSTextField(labelWithString: "自动")

    private let pageControl = NSSegmentedControl(
        labels: ["♥︎ 陪伴", "⚙︎ 设置"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let pageHost = NSView()
    private var companionPage: NSView?
    private var settingsPage: NSView?

    private let companionCard = NSView()
    private let levelTitleLabel = NSTextField(labelWithString: "Lv.1 · 初见搭子")
    private let experienceLabel = NSTextField(labelWithString: "陪伴值 0 / 40")
    private let streakLabel = NSTextField(labelWithString: "🌱 今天开始")
    private let progressBar = CompanionProgressBar()
    private let careLabel = NSTextField(labelWithString: "○ 摸摸  ○ 喂食  ○ 夸夸  ○ 抽签")
    private let companionHintLabel = NSTextField(
        wrappingLabelWithString: "每天完成四件小事，连续照顾会点亮火苗。"
    )

    private let awarenessToggle = NSButton(
        checkboxWithTitle: "自动感知场景",
        target: nil,
        action: nil
    )
    private let ocrToggle = NSButton(
        checkboxWithTitle: "本地屏幕 OCR",
        target: nil,
        action: nil
    )
    private let permissionLabel = NSTextField(
        labelWithString: "默认只读取前台 App 名称"
    )
    private let scaleControl = NSSegmentedControl(
        labels: ["迷你 60%", "标准 75%", "大只 100%"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let intervalControl = NSSegmentedControl(
        labels: ["灵敏 8s", "均衡 15s", "省电 30s"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    func show(state: ControlCenterState, preferCompanionPage: Bool = false) {
        if panel == nil {
            panel = buildPanel()
        }
        update(state)
        if preferCompanionPage {
            pageControl.selectedSegment = 0
            updateVisiblePage()
        }
        NSApp.activate(ignoringOtherApps: true)
        if let panel {
            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: {
                NSMouseInRect(mouseLocation, $0.frame, false)
            }) ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(
                    x: visible.midX - panel.frame.width / 2,
                    y: visible.midY - panel.frame.height / 2
                ))
            } else {
                panel.center()
            }
        }
        panel?.makeKeyAndOrderFront(nil)
    }

    func update(_ state: ControlCenterState) {
        guard panel != nil else { return }

        sceneIconLabel.stringValue = state.scene.emoji
        sceneTitleLabel.stringValue = state.scene.title
        sceneDetailLabel.stringValue = "\(state.appName) · \(state.source)"
        statusPillLabel.stringValue = state.isPaused
            ? "已暂停"
            : (state.awarenessEnabled ? "自动" : "手动")
        sceneCard.setAccessibilityLabel("当前场景")
        sceneCard.setAccessibilityValue(
            "\(state.scene.title)，\(state.appName)，\(state.source)"
        )

        awarenessToggle.state = state.awarenessEnabled ? .on : .off
        ocrToggle.state = state.ocrEnabled ? .on : .off
        ocrToggle.isEnabled = state.awarenessEnabled
        intervalControl.isEnabled = state.awarenessEnabled && state.ocrEnabled

        if state.ocrEnabled && state.hasScreenPermission {
            permissionLabel.stringValue = "✓ 当前窗口在本机识别，不保存、不上传"
            permissionLabel.textColor = NSColor(
                calibratedRed: 0.08,
                green: 0.43,
                blue: 0.29,
                alpha: 1
            )
        } else if state.ocrEnabled {
            permissionLabel.stringValue = "需要在系统设置中授予屏幕录制权限"
            permissionLabel.textColor = NSColor(
                calibratedRed: 0.68,
                green: 0.35,
                blue: 0.03,
                alpha: 1
            )
        } else {
            permissionLabel.stringValue = "默认只读取前台 App 名称，无需屏幕权限"
            permissionLabel.textColor = NSColor.secondaryLabelColor
        }

        let accent = state.scene.accentColor
        sceneCard.layer?.backgroundColor = accent.withAlphaComponent(0.10).cgColor
        sceneCard.layer?.borderColor = accent.withAlphaComponent(0.34).cgColor
        statusPillLabel.layer?.backgroundColor = NSColor(
            calibratedWhite: 0.18,
            alpha: 0.94
        ).cgColor
        statusPillLabel.layer?.borderColor = accent.withAlphaComponent(0.75).cgColor
        companionCard.layer?.borderColor = accent.withAlphaComponent(0.30).cgColor
        progressBar.accentColor = accent

        scaleControl.selectedSegment = nearestScaleSegment(state.scale)
        intervalControl.selectedSegment = nearestIntervalSegment(state.ocrInterval)
        updateCompanion(state.companion)
    }

    private func buildPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 456, height: 646),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "笑笑桌宠控制中心"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.setAccessibilityLabel("笑笑桌宠控制中心")

        let background = NSVisualEffectView()
        background.material = .sidebar
        background.blendingMode = .behindWindow
        background.state = .active
        panel.contentView = background

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: background.topAnchor, constant: 30),
            content.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -20)
        ])

        content.addArrangedSubview(makeHeader())
        content.addArrangedSubview(makeSceneCard())

        pageControl.segmentStyle = .rounded
        pageControl.selectedSegment = 0
        pageControl.target = self
        pageControl.action = #selector(pageChanged(_:))
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.widthAnchor.constraint(equalToConstant: 408).isActive = true
        pageControl.heightAnchor.constraint(equalToConstant: 32).isActive = true
        pageControl.setAccessibilityLabel("控制中心页面")
        content.addArrangedSubview(pageControl)

        pageHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageHost.widthAnchor.constraint(equalToConstant: 408),
            pageHost.heightAnchor.constraint(equalToConstant: 300)
        ])
        companionPage = makeCompanionPage()
        settingsPage = makeSettingsPage()
        if let companionPage, let settingsPage {
            pageHost.addSubview(companionPage)
            pageHost.addSubview(settingsPage)
            for page in [companionPage, settingsPage] {
                page.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    page.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor),
                    page.trailingAnchor.constraint(equalTo: pageHost.trailingAnchor),
                    page.topAnchor.constraint(equalTo: pageHost.topAnchor),
                    page.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor)
                ])
            }
        }
        content.addArrangedSubview(pageHost)
        content.addArrangedSubview(makePrivacyFooter())
        updateVisiblePage()
        panel.initialFirstResponder = pageControl

        return panel
    }

    private func makeHeader() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setAccessibilityLabel("笑笑桌宠图标")
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 54),
            icon.heightAnchor.constraint(equalToConstant: 54)
        ])

        let title = NSTextField(labelWithString: "笑笑桌宠")
        title.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "开发版"
        let subtitle = NSTextField(
            labelWithString: "Ambient Companion · v\(version) · 会在桌面长大"
        )
        subtitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitle.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3

        let header = NSStackView(views: [icon, labels])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 13
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: 408).isActive = true
        return header
    }

    private func makeSceneCard() -> NSView {
        sceneCard.wantsLayer = true
        sceneCard.layer?.cornerRadius = 18
        sceneCard.layer?.cornerCurve = .continuous
        sceneCard.layer?.borderWidth = 1
        sceneCard.translatesAutoresizingMaskIntoConstraints = false
        sceneCard.setAccessibilityElement(true)
        sceneCard.setAccessibilityRole(.group)
        NSLayoutConstraint.activate([
            sceneCard.widthAnchor.constraint(equalToConstant: 408),
            sceneCard.heightAnchor.constraint(equalToConstant: 94)
        ])

        sceneIconLabel.font = NSFont.systemFont(ofSize: 32)
        sceneIconLabel.alignment = .center
        sceneIconLabel.translatesAutoresizingMaskIntoConstraints = false
        sceneIconLabel.setAccessibilityElement(false)

        sceneTitleLabel.font = NSFont.systemFont(ofSize: 19, weight: .bold)
        sceneDetailLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        sceneDetailLabel.textColor = .secondaryLabelColor
        sceneDetailLabel.lineBreakMode = .byTruncatingMiddle

        let labels = NSStackView(views: [sceneTitleLabel, sceneDetailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 4
        labels.translatesAutoresizingMaskIntoConstraints = false

        statusPillLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        statusPillLabel.textColor = .white
        statusPillLabel.alignment = .center
        statusPillLabel.wantsLayer = true
        statusPillLabel.layer?.cornerRadius = 10
        statusPillLabel.layer?.cornerCurve = .continuous
        statusPillLabel.layer?.borderWidth = 1
        statusPillLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPillLabel.setAccessibilityLabel("感知状态")

        sceneCard.addSubview(sceneIconLabel)
        sceneCard.addSubview(labels)
        sceneCard.addSubview(statusPillLabel)
        NSLayoutConstraint.activate([
            sceneIconLabel.leadingAnchor.constraint(equalTo: sceneCard.leadingAnchor, constant: 18),
            sceneIconLabel.centerYAnchor.constraint(equalTo: sceneCard.centerYAnchor),
            sceneIconLabel.widthAnchor.constraint(equalToConstant: 48),
            labels.leadingAnchor.constraint(equalTo: sceneIconLabel.trailingAnchor, constant: 14),
            labels.centerYAnchor.constraint(equalTo: sceneCard.centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: statusPillLabel.leadingAnchor, constant: -10),
            statusPillLabel.trailingAnchor.constraint(equalTo: sceneCard.trailingAnchor, constant: -16),
            statusPillLabel.centerYAnchor.constraint(equalTo: sceneCard.centerYAnchor),
            statusPillLabel.widthAnchor.constraint(equalToConstant: 58),
            statusPillLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        return sceneCard
    }

    private func makeCompanionPage() -> NSView {
        let page = NSView()

        companionCard.wantsLayer = true
        companionCard.layer?.cornerRadius = 16
        companionCard.layer?.cornerCurve = .continuous
        companionCard.layer?.borderWidth = 1
        companionCard.layer?.backgroundColor = NSColor(
            calibratedRed: 1.0,
            green: 0.965,
            blue: 0.91,
            alpha: 0.72
        ).cgColor
        companionCard.translatesAutoresizingMaskIntoConstraints = false
        companionCard.setAccessibilityElement(true)
        companionCard.setAccessibilityRole(.group)
        companionCard.setAccessibilityLabel("陪伴进度")

        levelTitleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        levelTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        experienceLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 11,
            weight: .medium
        )
        experienceLabel.textColor = .secondaryLabelColor
        experienceLabel.translatesAutoresizingMaskIntoConstraints = false

        streakLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        streakLabel.alignment = .center
        streakLabel.wantsLayer = true
        streakLabel.layer?.backgroundColor = NSColor(
            calibratedRed: 0.86,
            green: 0.20,
            blue: 0.16,
            alpha: 0.10
        ).cgColor
        streakLabel.layer?.cornerRadius = 10
        streakLabel.translatesAutoresizingMaskIntoConstraints = false

        progressBar.translatesAutoresizingMaskIntoConstraints = false

        careLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        careLabel.textColor = NSColor(
            calibratedRed: 0.37,
            green: 0.22,
            blue: 0.20,
            alpha: 1
        )
        careLabel.lineBreakMode = .byClipping
        careLabel.translatesAutoresizingMaskIntoConstraints = false

        companionCard.addSubview(levelTitleLabel)
        companionCard.addSubview(experienceLabel)
        companionCard.addSubview(streakLabel)
        companionCard.addSubview(progressBar)
        companionCard.addSubview(careLabel)
        NSLayoutConstraint.activate([
            companionCard.heightAnchor.constraint(equalToConstant: 108),
            levelTitleLabel.leadingAnchor.constraint(equalTo: companionCard.leadingAnchor, constant: 16),
            levelTitleLabel.topAnchor.constraint(equalTo: companionCard.topAnchor, constant: 14),
            streakLabel.trailingAnchor.constraint(equalTo: companionCard.trailingAnchor, constant: -14),
            streakLabel.centerYAnchor.constraint(equalTo: levelTitleLabel.centerYAnchor),
            streakLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 86),
            streakLabel.heightAnchor.constraint(equalToConstant: 22),
            experienceLabel.leadingAnchor.constraint(equalTo: levelTitleLabel.leadingAnchor),
            experienceLabel.topAnchor.constraint(equalTo: levelTitleLabel.bottomAnchor, constant: 3),
            progressBar.leadingAnchor.constraint(equalTo: companionCard.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: companionCard.trailingAnchor, constant: -16),
            progressBar.topAnchor.constraint(equalTo: experienceLabel.bottomAnchor, constant: 8),
            progressBar.heightAnchor.constraint(equalToConstant: 7),
            careLabel.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            careLabel.trailingAnchor.constraint(equalTo: progressBar.trailingAnchor),
            careLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8)
        ])

        let actionGrid = NSGridView(views: [
            [
                makeCompanionButton("🫳 摸摸", action: #selector(patPressed)),
                makeCompanionButton("🍪 喂食", action: #selector(feedPressed))
            ],
            [
                makeCompanionButton("✨ 夸夸", action: #selector(praisePressed)),
                makeCompanionButton("🔮 今日签", action: #selector(fortunePressed))
            ],
            [
                makeCompanionButton("🐾 散步", action: #selector(walkPressed)),
                makeCompanionButton("🎉 庆祝", action: #selector(celebratePressed))
            ]
        ])
        actionGrid.rowSpacing = 8
        actionGrid.columnSpacing = 10
        actionGrid.translatesAutoresizingMaskIntoConstraints = false
        for row in 0..<3 {
            actionGrid.row(at: row).height = 44
        }
        for column in 0..<2 {
            actionGrid.column(at: column).width = 199
        }

        companionHintLabel.font = NSFont.systemFont(ofSize: 11)
        companionHintLabel.textColor = .secondaryLabelColor
        companionHintLabel.alignment = .center
        companionHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [companionCard, actionGrid, companionHintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            stack.topAnchor.constraint(equalTo: page.topAnchor),
            companionCard.widthAnchor.constraint(equalToConstant: 408),
            actionGrid.widthAnchor.constraint(equalToConstant: 408),
            companionHintLabel.widthAnchor.constraint(equalToConstant: 408)
        ])
        return page
    }

    private func makeCompanionButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.toolTip = "立即与笑笑互动"
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 199),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        button.setAccessibilityLabel(title.replacingOccurrences(
            of: #"^[^\s]+\s"#,
            with: "",
            options: .regularExpression
        ))
        return button
    }

    private func makeSettingsPage() -> NSView {
        let page = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 11
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            stack.topAnchor.constraint(equalTo: page.topAnchor)
        ])

        stack.addArrangedSubview(makeSectionTitle(
            "感知方式",
            subtitle: "按需开启，所有识别只在你的 Mac 上完成"
        ))
        stack.addArrangedSubview(makeAwarenessControls())
        stack.addArrangedSubview(makeSectionTitle(
            "桌宠大小",
            subtitle: "也可按住 Option 滚动微调"
        ))
        configureSegmentedControl(scaleControl, action: #selector(scaleChanged(_:)))
        stack.addArrangedSubview(scaleControl)
        stack.addArrangedSubview(makeSectionTitle(
            "OCR 节奏",
            subtitle: "越慢越省电，仅在 OCR 开启后生效"
        ))
        configureSegmentedControl(intervalControl, action: #selector(intervalChanged(_:)))
        stack.addArrangedSubview(intervalControl)
        stack.addArrangedSubview(makeActionRow())
        return page
    }

    private func makeSectionTitle(_ title: String, subtitle: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    private func makeAwarenessControls() -> NSView {
        awarenessToggle.target = self
        awarenessToggle.action = #selector(awarenessChanged(_:))
        awarenessToggle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        awarenessToggle.toolTip = "根据前台 App 和可选本地 OCR 自动切换状态"

        ocrToggle.target = self
        ocrToggle.action = #selector(ocrChanged(_:))
        ocrToggle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        ocrToggle.toolTip = "只识别当前前台窗口，不保存画面或文字"

        let toggles = NSStackView(views: [awarenessToggle, ocrToggle])
        toggles.orientation = .horizontal
        toggles.alignment = .centerY
        toggles.distribution = .fillEqually

        permissionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let stack = NSStackView(views: [toggles, permissionLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 408).isActive = true
        return stack
    }

    private func configureSegmentedControl(
        _ control: NSSegmentedControl,
        action: Selector
    ) {
        control.segmentStyle = .rounded
        control.target = self
        control.action = action
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 408).isActive = true
        control.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func makeActionRow() -> NSView {
        let refresh = NSButton(
            title: "立即识别",
            target: self,
            action: #selector(refreshPressed)
        )
        refresh.bezelStyle = .rounded
        refresh.toolTip = "立即重新判断当前场景"

        let bringBack = NSButton(
            title: "叫她回来",
            target: self,
            action: #selector(bringBackPressed)
        )
        bringBack.bezelStyle = .rounded
        bringBack.toolTip = "把桌宠移回当前可见屏幕"

        let privacy = NSButton(
            title: "隐私说明",
            target: self,
            action: #selector(privacyPressed)
        )
        privacy.bezelStyle = .rounded
        privacy.toolTip = "查看权限用途与本地处理方式"

        let stack = NSStackView(views: [refresh, bringBack, privacy])
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 408).isActive = true
        stack.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return stack
    }

    private func makePrivacyFooter() -> NSView {
        let footer = NSTextField(
            labelWithString: "● 100% 本地运行    无遥测    不上传屏幕内容"
        )
        footer.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        footer.textColor = NSColor.labelColor
        footer.alignment = .center
        footer.toolTip = "场景识别和陪伴进度都只保存在这台 Mac"
        footer.setAccessibilityLabel(
            "百分之百本地运行，无遥测，不上传屏幕内容"
        )
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.widthAnchor.constraint(equalToConstant: 408).isActive = true
        return footer
    }

    private func updateCompanion(_ companion: CompanionSnapshot) {
        levelTitleLabel.stringValue = "Lv.\(companion.level) · \(companion.levelTitle)"
        if let needed = companion.experienceForNextLevel {
            experienceLabel.stringValue =
                "陪伴值 \(companion.experienceInLevel) / \(needed)"
        } else {
            experienceLabel.stringValue =
                "陪伴值 \(companion.totalExperience) · 已满级"
        }
        progressBar.progress = companion.levelProgress
        streakLabel.stringValue = companion.streak > 0
            ? "🔥 连续 \(companion.streak) 天"
            : "🌱 今天开始"

        careLabel.stringValue = CompanionCareItem.allCases.map { item in
            let marker = companion.completedCareItems.contains(item) ? "✓" : "○"
            return "\(marker) \(item.title)"
        }.joined(separator: "   ")
        careLabel.setAccessibilityLabel(
            "今日照顾完成 \(companion.completedCareCount) 项，共 \(companion.careGoal) 项"
        )
        companionCard.setAccessibilityValue(
            "等级 \(companion.level)，\(companion.levelTitle)，"
                + "今日照顾 \(companion.completedCareCount) / \(companion.careGoal)，"
                + "连续 \(companion.streak) 天"
        )
        companionHintLabel.stringValue = companion.isDailyCareComplete
            ? "今日照顾完成！明天再来，连续天数会继续增加。"
            : "每天完成四件小事，连续照顾会点亮火苗。"
    }

    private func nearestScaleSegment(_ scale: CGFloat) -> Int {
        let values: [CGFloat] = [0.60, 0.74, 1.00]
        return values.indices.min(by: {
            abs(values[$0] - scale) < abs(values[$1] - scale)
        }) ?? 1
    }

    private func nearestIntervalSegment(_ interval: TimeInterval) -> Int {
        let values: [TimeInterval] = [8, 15, 30]
        return values.indices.min(by: {
            abs(values[$0] - interval) < abs(values[$1] - interval)
        }) ?? 1
    }

    private func updateVisiblePage() {
        let showsCompanion = pageControl.selectedSegment != 1
        companionPage?.isHidden = !showsCompanion
        settingsPage?.isHidden = showsCompanion
    }

    @objc private func pageChanged(_ sender: NSSegmentedControl) {
        updateVisiblePage()
    }

    @objc private func awarenessChanged(_ sender: NSButton) {
        onAwarenessChanged?(sender.state == .on)
    }

    @objc private func ocrChanged(_ sender: NSButton) {
        onOCRChanged?(sender.state == .on)
    }

    @objc private func scaleChanged(_ sender: NSSegmentedControl) {
        let values: [CGFloat] = [0.60, 0.74, 1.00]
        guard values.indices.contains(sender.selectedSegment) else { return }
        onScaleChanged?(values[sender.selectedSegment])
    }

    @objc private func intervalChanged(_ sender: NSSegmentedControl) {
        let values: [TimeInterval] = [8, 15, 30]
        guard values.indices.contains(sender.selectedSegment) else { return }
        onIntervalChanged?(values[sender.selectedSegment])
    }

    @objc private func refreshPressed() {
        onRefresh?()
    }

    @objc private func bringBackPressed() {
        onBringBack?()
    }

    @objc private func privacyPressed() {
        onPrivacy?()
    }

    @objc private func patPressed() {
        onPat?()
    }

    @objc private func feedPressed() {
        onFeed?()
    }

    @objc private func praisePressed() {
        onPraise?()
    }

    @objc private func fortunePressed() {
        onFortune?()
    }

    @objc private func walkPressed() {
        onWalk?()
    }

    @objc private func celebratePressed() {
        onCelebrate?()
    }
}
