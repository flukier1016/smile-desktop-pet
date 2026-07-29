import AppKit

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
}

final class ControlCenterController: NSObject {
    var onAwarenessChanged: ((Bool) -> Void)?
    var onOCRChanged: ((Bool) -> Void)?
    var onScaleChanged: ((CGFloat) -> Void)?
    var onIntervalChanged: ((TimeInterval) -> Void)?
    var onRefresh: (() -> Void)?
    var onBringBack: (() -> Void)?
    var onPrivacy: (() -> Void)?

    private var panel: NSPanel?

    private let sceneCard = NSView()
    private let sceneIconLabel = NSTextField(labelWithString: "🌸")
    private let sceneTitleLabel = NSTextField(labelWithString: "陪伴待机")
    private let sceneDetailLabel = NSTextField(labelWithString: "桌面 · 前台 App")
    private let statusPillLabel = NSTextField(labelWithString: "自动")
    private let awarenessToggle = NSButton(checkboxWithTitle: "自动感知场景", target: nil, action: nil)
    private let ocrToggle = NSButton(checkboxWithTitle: "本地屏幕 OCR", target: nil, action: nil)
    private let permissionLabel = NSTextField(labelWithString: "默认只读取前台 App 名称")
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

    func show(state: ControlCenterState) {
        if panel == nil {
            panel = buildPanel()
        }
        update(state)
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
        statusPillLabel.stringValue = state.isPaused ? "已暂停" : (state.awarenessEnabled ? "自动" : "手动")
        awarenessToggle.state = state.awarenessEnabled ? .on : .off
        ocrToggle.state = state.ocrEnabled ? .on : .off
        ocrToggle.isEnabled = state.awarenessEnabled
        intervalControl.isEnabled = state.awarenessEnabled && state.ocrEnabled

        if state.ocrEnabled && state.hasScreenPermission {
            permissionLabel.stringValue = "✓ 当前窗口在本机识别，不保存、不上传"
            permissionLabel.textColor = NSColor.systemGreen
        } else if state.ocrEnabled {
            permissionLabel.stringValue = "需要在系统设置中授予屏幕录制权限"
            permissionLabel.textColor = NSColor.systemOrange
        } else {
            permissionLabel.stringValue = "默认只读取前台 App 名称，无需屏幕权限"
            permissionLabel.textColor = NSColor.secondaryLabelColor
        }

        let accent = state.scene.accentColor
        sceneCard.layer?.backgroundColor = accent.withAlphaComponent(0.11).cgColor
        sceneCard.layer?.borderColor = accent.withAlphaComponent(0.30).cgColor
        statusPillLabel.layer?.backgroundColor = accent.withAlphaComponent(0.92).cgColor
        scaleControl.selectedSegment = nearestScaleSegment(state.scale)
        intervalControl.selectedSegment = nearestIntervalSegment(state.ocrInterval)
    }

    private func buildPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 456, height: 598),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "笑笑桌宠控制中心"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.backgroundColor = .clear

        let background = NSVisualEffectView()
        background.material = .sidebar
        background.blendingMode = .behindWindow
        background.state = .active
        panel.contentView = background

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: background.topAnchor, constant: 30),
            content.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -22)
        ])

        content.addArrangedSubview(makeHeader())
        content.addArrangedSubview(makeSceneCard())
        content.addArrangedSubview(makeSectionTitle("感知方式", subtitle: "按需开启，所有识别只在你的 Mac 上完成"))
        content.addArrangedSubview(makeAwarenessControls())
        content.addArrangedSubview(makeSectionTitle("桌宠大小", subtitle: "也可按住 Option 滚动微调"))
        configureSegmentedControl(scaleControl, action: #selector(scaleChanged(_:)))
        content.addArrangedSubview(scaleControl)
        content.addArrangedSubview(makeSectionTitle("OCR 节奏", subtitle: "越慢越省电，仅在 OCR 开启后生效"))
        configureSegmentedControl(intervalControl, action: #selector(intervalChanged(_:)))
        content.addArrangedSubview(intervalControl)
        content.addArrangedSubview(makeActionRow())
        content.addArrangedSubview(makePrivacyFooter())

        return panel
    }

    private func makeHeader() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 54),
            icon.heightAnchor.constraint(equalToConstant: 54)
        ])

        let title = NSTextField(labelWithString: "笑笑桌宠")
        title.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
        let subtitle = NSTextField(labelWithString: "Ambient Companion · v\(version)")
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
        NSLayoutConstraint.activate([
            sceneCard.widthAnchor.constraint(equalToConstant: 408),
            sceneCard.heightAnchor.constraint(equalToConstant: 104)
        ])

        sceneIconLabel.font = NSFont.systemFont(ofSize: 34)
        sceneIconLabel.alignment = .center
        sceneIconLabel.translatesAutoresizingMaskIntoConstraints = false

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
        statusPillLabel.translatesAutoresizingMaskIntoConstraints = false

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
            statusPillLabel.widthAnchor.constraint(equalToConstant: 54),
            statusPillLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
        return sceneCard
    }

    private func makeSectionTitle(_ title: String, subtitle: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .tertiaryLabelColor
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
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 408).isActive = true
        return stack
    }

    private func configureSegmentedControl(_ control: NSSegmentedControl, action: Selector) {
        control.segmentStyle = .rounded
        control.target = self
        control.action = action
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 408).isActive = true
        control.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    private func makeActionRow() -> NSView {
        let refresh = NSButton(title: "立即识别", target: self, action: #selector(refreshPressed))
        refresh.bezelStyle = .rounded
        refresh.toolTip = "立即重新判断当前场景"

        let bringBack = NSButton(title: "叫她回来", target: self, action: #selector(bringBackPressed))
        bringBack.bezelStyle = .rounded
        bringBack.toolTip = "把桌宠移回当前可见屏幕"

        let privacy = NSButton(title: "隐私说明", target: self, action: #selector(privacyPressed))
        privacy.bezelStyle = .rounded
        privacy.toolTip = "查看权限用途与本地处理方式"

        let stack = NSStackView(views: [refresh, bringBack, privacy])
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 408).isActive = true
        return stack
    }

    private func makePrivacyFooter() -> NSView {
        let footer = NSTextField(labelWithString: "● 100% 本地运行    无遥测    不上传屏幕内容")
        footer.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        footer.textColor = NSColor.systemGreen
        footer.alignment = .center
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.widthAnchor.constraint(equalToConstant: 408).isActive = true
        return footer
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
}
