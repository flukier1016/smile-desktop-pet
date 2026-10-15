import AppKit
import QuartzCore
import Darwin

// This runner only creates a view. It never starts awareness, requests capture
// permission, or reads/writes the companion's preferences.
@main
enum RenderBenchmark {
    static func cpuTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3,
              let image = NSImage(contentsOfFile: arguments[1]) else {
            fatalError("Usage: RenderBenchmark sprite.png companion|coding|party|hidden [seconds]")
        }
        let scenario = arguments[2]
        let duration = arguments.count > 3 ? Double(arguments[3]) ?? 6 : 6
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let panel = NSPanel(
            contentRect: NSRect(x: 80, y: 80, width: 237, height: 318),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = PetView(frame: NSRect(origin: .zero, size: panel.frame.size), image: image)
        panel.contentView = view
        view.setScene(scenario == "coding" ? .coding : .companion)
        panel.orderFrontRegardless()
        if scenario == "hidden" { panel.orderOut(nil) }
        var workload: Timer?
        if scenario == "party" {
            workload = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                view.party()
                view.showMessage("快乐加载到 100%！", duration: 2)
            }
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            let startCPU = cpuTime()
            let startWall = ProcessInfo.processInfo.systemUptime
            Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                let elapsed = ProcessInfo.processInfo.systemUptime - startWall
                let consumed = cpuTime() - startCPU
                var usage = rusage()
                getrusage(RUSAGE_SELF, &usage)
                let result: [String: Any] = [
                    "scenario": scenario,
                    "seconds": elapsed,
                    "cpu_seconds": consumed,
                    "cpu_percent_one_core": consumed / elapsed * 100,
                    "window_visible": panel.isVisible,
                    "window_occluded": !panel.occlusionState.contains(.visible),
                    "peak_resident_mib": Double(usage.ru_maxrss) / 1_048_576,
                    "animations": animationCount(view.layer)
                ]
                let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
                print(String(decoding: data, as: UTF8.self))
                workload?.invalidate()
                panel.orderOut(nil)
                application.stop(nil)
                application.postEvent(
                    NSEvent.otherEvent(with: .applicationDefined, location: .zero,
                        modifierFlags: [], timestamp: 0, windowNumber: 0,
                        context: nil, subtype: 0, data1: 0, data2: 0)!,
                    atStart: true
                )
            }
        }
        application.run()
    }

    static func animationCount(_ layer: CALayer?) -> Int {
        guard let layer else { return 0 }
        return (layer.animationKeys()?.count ?? 0)
            + (layer.sublayers ?? []).reduce(0) { $0 + animationCount($1) }
    }
}
