import AppKit
import QuartzCore

private final class WeakPet {
    weak var value: PetView?
    init(_ value: PetView?) { self.value = value }
}

@main
enum PetRenderingTests {
    static func pump(_ interval: TimeInterval = 0.08) {
        let deadline = Date().addingTimeInterval(interval)
        repeat {
            while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
            NSApp.updateWindows()
            RunLoop.main.run(until: min(deadline, Date().addingTimeInterval(0.01)))
        } while Date() < deadline
        CATransaction.flush()
    }

    static func child(_ name: String, in layer: CALayer) -> CALayer {
        guard let found = layer.sublayers?.first(where: { $0.name == name }) else {
            fatalError("Missing layer: \(name)")
        }
        return found
    }

    static func animationCount(_ layer: CALayer) -> Int {
        (layer.animationKeys()?.count ?? 0)
            + (layer.sublayers ?? []).reduce(0) { $0 + animationCount($1) }
    }

    static func describeAnimations(_ layer: CALayer) -> [String] {
        (layer.animationKeys() ?? []).map { "\(layer.name ?? "unnamed"): \($0)" }
            + (layer.sublayers ?? []).flatMap(describeAnimations)
    }

    private static func exercise() throws -> WeakPet {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let spritePath = CommandLine.arguments[1]
        let image = NSImage(contentsOfFile: spritePath)!
        let panel = NSPanel(contentRect: NSRect(x: 80, y: 80, width: 237, height: 318),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        var pet: PetView? = PetView(frame: NSRect(origin: .zero, size: panel.frame.size), image: image)
        let weakPet = WeakPet(pet)
        pet!.autoresizingMask = [.width, .height]
        panel.contentView = pet
        panel.orderFrontRegardless()
        pump()
        pet!.refreshActivity()
        pet!.layoutSubtreeIfNeeded()
        let stage = child("stage", in: pet!.layer!)
        let motion = child("motion", in: stage)
        let texture = motion.sublayers!.first!.sublayers!.first!
        let originalTexture = texture.contents as! CGImage
        let particles = child("particles", in: stage)
        let caption = child("caption", in: stage)
        precondition(originalTexture.width > 0)
        pet!.showMessage("同一句话不应重复生成位图", duration: 0.2)
        let firstCaption = caption.contents as! CGImage
        pet!.showMessage("同一句话不应重复生成位图", duration: 0.2)
        precondition(firstCaption === (caption.contents as! CGImage))
        for scene in PetScene.allCases {
            pet!.setScene(scene)
            precondition(originalTexture === (texture.contents as! CGImage), "Scene changes must reuse the sprite texture")
            precondition(pet!.accessibilityValue() as? String == scene.title)
        }
        pet!.setScene(.coding)
        precondition(child("props", in: stage).sublayers?.count == 1)
        pet!.setScene(.jailWork)
        precondition(child("props", in: stage).sublayers?.isEmpty != false, "Old props must disappear")
        pet!.setScene(.companion)
        pet!.celebrate(symbols: [], count: 20)
        pet!.celebrate(symbols: ["✨"], count: -1)
        pet!.celebrate(symbols: ["✨"], count: 1000)
        pet!.celebrate(symbols: ["♥︎"], count: 1000)
        precondition((particles.sublayers?.count ?? 0) <= 64, "Repeated interaction must have bounded particle memory")
        pump(0.25)
        precondition(firstCaption !== (caption.contents as! CGImage), "Caption must expire without a frame timer")

        let center = NSWorkspace.shared.notificationCenter
        center.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        pump()
        precondition(animationCount(stage) == 0, "Locked/asleep rendering must stop: \(describeAnimations(stage)); active=\(pet!.isActive)")
        center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        pump()
        precondition(animationCount(stage) == 0, "Session resume must wait for sleeping screens")
        center.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        pump()
        if panel.occlusionState.contains(.visible)
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            && !ProcessInfo.processInfo.isLowPowerModeEnabled {
            precondition(animationCount(stage) > 0, "Motion must resume after wake")
        }
        pet!.isQuiet = true
        precondition(animationCount(stage) == 0, "Quiet mode must stop ambient motion")
        pet!.isQuiet = false
        pet!.party()
        pump(2)
        precondition(particles.sublayers?.isEmpty != false, "Finished particle layers must be released")
        panel.orderOut(nil)
        pump()
        pet!.refreshActivity()
        precondition(animationCount(stage) == 0, "Hidden windows must have no animations")
        precondition(particles.sublayers?.isEmpty != false)

        // Save all 23 scenes at all three shipped sizes for visual inspection.
        if CommandLine.arguments.count > 2 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for scale in [CGFloat(0.60), 0.74, 1.0] {
                panel.setContentSize(NSSize(width: round(320 * scale), height: round(430 * scale)))
                pet!.needsLayout = true
                pet!.layoutSubtreeIfNeeded()
                for scene in PetScene.allCases {
                    pet!.setScene(scene)
                    let width = Int(pet!.bounds.width * 2)
                    let height = Int(pet!.bounds.height * 2)
                    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.scaleBy(x: 2, y: 2)
                    pet!.layer!.render(in: context)
                    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
                    try rep.representation(using: .png, properties: [:])!.write(
                        to: directory.appendingPathComponent("\(Int(scale * 100))-\(scene.rawValue).png"))
                }
            }
        }
        pet!.showMessage("释放视图时，计时器不能留下引用环", duration: 30)
        panel.contentView = nil
        pet = nil
        pump()
        panel.makeFirstResponder(nil)
        panel.close()
        return weakPet
    }

    static func main() throws {
        let weakPet = try autoreleasepool(invoking: exercise)
        pump()
        precondition(weakPet.value == nil, "View timers and observers must not retain a detached pet")
        print("Pet rendering: 23 scenes, cached textures, caption expiry, bounded particles, hide/wake, and cleanup passed")
    }
}
