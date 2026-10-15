import AppKit
import QuartzCore

private final class PetParticleLayer: CALayer, CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        removeFromSuperlayer()
        CATransaction.commit()
    }
}

// Artwork is rasterized only when its content or display resolution changes.
// Core Animation moves the cached layers without calling AppKit draw per frame.
final class PetView: NSView {
    weak var controller: PetController?
    var onActivityChange: ((Bool) -> Void)?
    var walking = false {
        didSet { if oldValue != walking { updateMotion() } }
    }
    var isQuiet = false {
        didSet { if oldValue != isQuiet { updateMotion() } }
    }

    private let image: NSImage
    private let logicalSize = NSSize(width: 320, height: 430)
    private let stage = CALayer()
    private let backdrop = CALayer()
    private let motionLayer = CALayer()
    private let reactionLayer = CALayer()
    private let sprite = CALayer()
    private let decorations = CALayer()
    private let props = CALayer()
    private let particleContainer = CALayer()
    private let caption = CALayer()
    private var message: String?
    private var scene: PetScene = .companion
    private var messageTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var windowObserver: NSObjectProtocol?
    private var systemSuspended = false
    private var sessionSuspended = false
    private var screensSuspended = false
    private var active = false
    var isActive: Bool { active }
    private var reduceMotion = false
    private var lowPower = false
    private var rasterScale: CGFloat = 0
    private var glyphs: [String: CGImage] = [:]
    private var dragStartMouse = NSPoint.zero
    private var dragStartWindow = NSPoint.zero
    private var dragged = false

    init(frame frameRect: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        stage.name = "stage"
        stage.anchorPoint = .zero
        stage.bounds = NSRect(origin: .zero, size: logicalSize)
        layer?.addSublayer(stage)
        for (name, child) in [
            ("backdrop", backdrop), ("motion", motionLayer),
            ("decorations", decorations), ("props", props),
            ("particles", particleContainer), ("caption", caption)
        ] {
            child.name = name
            stage.addSublayer(child)
        }
        motionLayer.frame = petRect()
        reactionLayer.frame = motionLayer.bounds
        sprite.frame = reactionLayer.bounds
        motionLayer.addSublayer(reactionLayer)
        reactionLayer.addSublayer(sprite)
        sprite.minificationFilter = .trilinear
        decorations.frame = stage.bounds
        particleContainer.frame = stage.bounds
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("笑笑桌宠")
        setAccessibilityValue(scene.title)
        setAccessibilityHelp("按下可摸摸，双击可庆祝，拖动可换位置，右键打开互动菜单")
        setAccessibilityIdentifier("smile-desktop-pet")
        observeEnvironment()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        messageTimer?.invalidate()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
        windowObserver = nil
        if let window {
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window, queue: .main
            ) { [weak self] _ in self?.refreshActivity() }
        }
        needsLayout = true
        refreshActivity()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }

    override func viewDidHide() {
        super.viewDidHide()
        refreshActivity()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        refreshActivity()
    }

    override func layout() {
        super.layout()
        withoutAnimation {
            stage.position = .zero
            stage.setAffineTransform(CGAffineTransform(scaleX: displayScale, y: displayScale))
            let scale = max(0.5, displayScale * (window?.backingScaleFactor ?? 2))
            if abs(scale - rasterScale) > 0.001 {
                rasterScale = scale
                glyphs.removeAll(keepingCapacity: true)
                clearParticles()
                rebuildArtwork()
            }
        }
    }

    func refreshActivity() {
        let visible = window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false
        let newActive = visible && !isHiddenOrHasHiddenAncestor
            && !systemSuspended && !sessionSuspended && !screensSuspended
        let newReduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let newLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let changed = active != newActive || reduceMotion != newReduced || lowPower != newLowPower
        let activityChanged = active != newActive
        active = newActive
        reduceMotion = newReduced
        lowPower = newLowPower
        if changed {
            reactionLayer.removeAllAnimations()
            clearParticles()
            updateMotion()
        }
        if activityChanged { onActivityChange?(newActive) }
    }

    private func observeEnvironment() {
        let center = NSWorkspace.shared.notificationCenter
        for (name, action) in [
            (NSWorkspace.willSleepNotification, 0),
            (NSWorkspace.didWakeNotification, 1),
            (NSWorkspace.sessionDidResignActiveNotification, 2),
            (NSWorkspace.sessionDidBecomeActiveNotification, 3),
            (NSWorkspace.screensDidSleepNotification, 4),
            (NSWorkspace.screensDidWakeNotification, 5)
        ] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                guard let self else { return }
                switch action {
                case 0: self.systemSuspended = true
                case 1: self.systemSuspended = false
                case 2: self.sessionSuspended = true
                case 3: self.sessionSuspended = false
                case 4: self.screensSuspended = true
                default: self.screensSuspended = false
                }
                self.refreshActivity()
            })
        }
        observers.append(center.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refreshActivity() })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshActivity() })
    }

    private func petRect() -> NSRect {
        let area = NSRect(x: 18, y: 8, width: logicalSize.width - 36, height: 352)
        let aspect = image.size.width / max(1, image.size.height)
        let width = min(area.width, area.height * aspect)
        return NSRect(x: area.midX - width / 2, y: area.minY, width: width, height: width / aspect)
    }

    private func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    private func bitmap(in rect: NSRect, draw: () -> Void) -> CGImage? {
        let scale = max(0.5, rasterScale)
        guard let context = CGContext(
            data: nil, width: max(1, Int(ceil(rect.width * scale))),
            height: max(1, Int(ceil(rect.height * scale))), bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -rect.minX, y: -rect.minY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    private func render(_ target: CALayer, in rect: NSRect, draw: () -> Void) {
        target.frame = rect
        target.contentsScale = max(0.5, rasterScale)
        target.contents = bitmap(in: rect, draw: draw)
    }

    private func rebuildArtwork() {
        render(sprite, in: reactionLayer.bounds) {
            image.draw(in: reactionLayer.bounds, from: .zero, operation: .sourceOver,
                fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }
        rebuildSceneArtwork()
    }

    private func rebuildSceneArtwork() {
        render(backdrop, in: NSRect(x: 40, y: 9, width: 240, height: 58), draw: drawSceneBackdrop)
        decorations.sublayers?.forEach { $0.removeFromSuperlayer() }
        let positions = [NSPoint(x: 38, y: 246), NSPoint(x: 268, y: 225), NSPoint(x: 49, y: 116)]
        for (index, symbol) in scene.ambientSymbols.prefix(3).enumerated() {
            let size: CGFloat = symbol.count > 2 ? 13 : 19
            let glyph = makeGlyph(symbol, size: size, color: scene.accentColor.withAlphaComponent(0.82))
            glyph.position = NSPoint(x: positions[index].x, y: positions[index].y + glyph.bounds.height / 2)
            decorations.addSublayer(glyph)
        }
        props.contents = nil
        props.sublayers?.forEach { $0.removeFromSuperlayer() }
        if scene == .jailWork {
            render(props, in: NSRect(x: 40, y: 45, width: 240, height: 280), draw: drawJailBars)
        } else {
            let prop: String?
            switch scene {
            case .meeting: prop = "🔇"
            case .reading: prop = "📖"
            case .coding: prop = "⌨️"
            case .finance: prop = "📈"
            case .music: prop = "🎧"
            default: prop = nil
            }
            if let prop {
                let glyph = makeGlyph(prop, size: 28, color: .white)
                glyph.frame.origin = NSPoint(x: 236, y: 73)
                props.frame = stage.bounds
                props.addSublayer(glyph)
            }
        }
        updateCaption()
        updateMotion()
    }

    private func makeGlyph(_ symbol: String, size: CGFloat, color: NSColor) -> CALayer {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: color]
        let measured = (symbol as NSString).size(withAttributes: attributes)
        let bounds = NSRect(x: 0, y: 0, width: ceil(measured.width) + 8, height: ceil(measured.height) + 8)
        let key = "\(symbol)|\(size)|\(color.description)"
        if glyphs[key] == nil {
            if glyphs.count >= 128 { glyphs.removeAll(keepingCapacity: true) }
            glyphs[key] = bitmap(in: bounds) {
                (symbol as NSString).draw(at: NSPoint(x: 4, y: 4), withAttributes: attributes)
            }
        }
        let result = CALayer()
        result.bounds = bounds
        result.contentsScale = max(0.5, rasterScale)
        result.contents = glyphs[key]
        return result
    }

    private func updateMotion() {
        withoutAnimation {
            motionLayer.removeAllAnimations()
            motionLayer.transform = CATransform3DIdentity
            for child in (decorations.sublayers ?? []) + (props.sublayers ?? []) {
                child.removeAllAnimations()
            }
            guard active, !reduceMotion, !isQuiet, !lowPower else { return }
            let amplitude: CGFloat
            let frequency: Double
            let rotation: CGFloat
            let rotationFrequency: Double
            let hops: Bool
            switch scene.motion {
            case .calm: (amplitude, frequency, rotation, rotationFrequency, hops) = (3, 1, 0, 1, false)
            case .focus: (amplitude, frequency, rotation, rotationFrequency, hops) = (1.4, 0.62, 0, 1, false)
            case .busy: (amplitude, frequency, rotation, rotationFrequency, hops) = (2.2, 1.7, 0.8, 1.7, true)
            case .panic: (amplitude, frequency, rotation, rotationFrequency, hops) = (4, 4.5, 2.8, 6.5, true)
            case .dance: (amplitude, frequency, rotation, rotationFrequency, hops) = (8, 2.8, 4.5, 2.8, true)
            case .sleepy: (amplitude, frequency, rotation, rotationFrequency, hops) = (1.2, 0.35, 0, 1, false)
            case .celebrate: (amplitude, frequency, rotation, rotationFrequency, hops) = (7, 3.2, 3, 3.2, true)
            }
            oscillate(motionLayer, keyPath: "transform.translation.y", amplitude: walking ? 9 : amplitude,
                frequency: walking ? 4 : frequency, hops: walking || hops)
            if rotation > 0 || walking {
                oscillate(motionLayer, keyPath: "transform.rotation.z", amplitude: (walking ? 4 : rotation) * .pi / 180,
                    frequency: walking ? 4 : rotationFrequency)
            }
            for (index, child) in (decorations.sublayers ?? []).enumerated() {
                oscillate(child, keyPath: "transform.translation.y", amplitude: 7, frequency: 1.2, phase: Double(index) * 1.8)
            }
            for child in props.sublayers ?? [] {
                oscillate(child, keyPath: "transform.translation.y", amplitude: 3, frequency: 1.4)
            }
        }
    }

    private func oscillate(_ target: CALayer, keyPath: String, amplitude: CGFloat,
                           frequency: Double, phase: Double = 0, hops: Bool = false) {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = (0...48).map { index -> NSNumber in
            let value = sin(Double(index) / 48 * .pi * 2 + phase)
            return NSNumber(value: Double(amplitude) * (hops ? abs(value) : value))
        }
        animation.duration = .pi * 2 / (2.4 * frequency)
        animation.repeatCount = .infinity
        target.add(animation, forKey: keyPath)
    }

    private func updateCaption() {
        withoutAnimation {
            render(caption, in: NSRect(x: 0, y: 332, width: 320, height: 98)) {
                drawSceneBadge()
                drawBubble()
            }
        }
    }

    func showMessage(_ text: String, duration: TimeInterval) {
        messageTimer?.invalidate()
        if message != text {
            message = text
            updateCaption()
        }
        messageTimer = Timer(timeInterval: max(0.01, duration), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.message = nil
            self.messageTimer = nil
            self.updateCaption()
        }
        if let messageTimer { RunLoop.main.add(messageTimer, forMode: .common) }
    }

    func setScene(_ newScene: PetScene) {
        guard scene != newScene else { return }
        scene = newScene
        setAccessibilityValue(newScene.title)
        withoutAnimation { rebuildSceneArtwork() }
    }

    private func react(duration: TimeInterval, transform: (Double) -> CATransform3D) {
        guard active, !reduceMotion else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = (0...36).map { NSValue(caTransform3D: transform(Double($0) / 36)) }
        animation.duration = duration
        reactionLayer.add(animation, forKey: "reaction")
    }

    func bounce() {
        react(duration: 0.85) { progress in
            let scale = 1 + sin(progress * .pi) * 0.06
            let y = abs(sin(progress * .pi * 3)) * 34 * (1 - progress)
            return CATransform3DScale(CATransform3DMakeTranslation(0, y, 0), scale, scale, 1)
        }
    }

    func wiggle() {
        react(duration: 0.9) { progress in
            CATransform3DMakeRotation(sin(progress * .pi * 8) * 7 * .pi / 180 * (1 - progress), 0, 0, 1)
        }
    }

    func patReaction() {
        react(duration: 0.75) { progress in
            let scale = 1 + sin(progress * .pi) * 0.05
            return CATransform3DMakeScale(scale, 1 - sin(progress * .pi) * 0.03, 1)
        }
        celebrate(symbols: ["♥︎", "♥︎", "✨"], count: 8, origin: NSPoint(x: 160, y: 275))
    }

    func party() {
        react(duration: 0.9) { progress in
            let scale = 1 + sin(progress * .pi) * 0.12
            return CATransform3DScale(CATransform3DMakeRotation((1 - pow(1 - progress, 3)) * .pi * 2, 0, 0, 1), scale, scale, 1)
        }
        celebrate(symbols: ["♥︎", "✨", "✦", "●"], count: 28)
    }

    func feed(with food: String) {
        celebrate(symbols: [food, "♥︎", "✨"], count: 12, origin: NSPoint(x: 160, y: 205))
        bounce()
    }

    func celebrate(symbols: [String], count: Int, origin: NSPoint? = nil) {
        guard active, !reduceMotion, !symbols.isEmpty, count > 0 else { return }
        let limit = lowPower ? 16 : 64
        let count = min(count, limit)
        let existing = particleContainer.sublayers ?? []
        for child in existing.prefix(max(0, existing.count + count - limit)) {
            child.removeAllAnimations()
            child.removeFromSuperlayer()
        }
        let center = origin ?? NSPoint(x: 160, y: 225)
        withoutAnimation {
            for _ in 0..<count {
                let glyph = makeGlyph(symbols.randomElement()!, size: [CGFloat(16), 20, 24].randomElement()!, color: .white)
                let particle = PetParticleLayer()
                particle.bounds = glyph.bounds
                particle.contents = glyph.contents
                particle.contentsScale = glyph.contentsScale
                let start = NSPoint(x: center.x + CGFloat.random(in: -35...35), y: center.y + CGFloat.random(in: -20...35))
                let velocity = CGVector(dx: CGFloat.random(in: -75...75), dy: CGFloat.random(in: 60...150))
                let lifetime = Double.random(in: 1...1.8)
                particle.position = start
                particle.opacity = 0
                particleContainer.addSublayer(particle)
                let path = CAKeyframeAnimation(keyPath: "position")
                path.duration = lifetime
                path.values = (0...24).map { index -> NSValue in
                    let t = CGFloat(Double(index) / 24 * lifetime)
                    return NSValue(point: NSPoint(x: start.x + velocity.dx * t, y: start.y + velocity.dy * t - 12 * t * t))
                }
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.duration = lifetime
                fade.fromValue = 1
                fade.toValue = 0
                let group = CAAnimationGroup()
                group.animations = [path, fade]
                group.duration = lifetime
                group.delegate = particle
                particle.add(group, forKey: "burst")
            }
        }
    }

    private func clearParticles() {
        withoutAnimation {
            particleContainer.removeAllAnimations()
            for child in particleContainer.sublayers ?? [] {
                child.removeAllAnimations()
                child.removeFromSuperlayer()
            }
        }
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
