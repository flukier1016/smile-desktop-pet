import AppKit

@main
enum AwarenessLifecycleTests {
    static func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.03)) }

    static func main() {
        let suite = "smile-awareness-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "screenOCREnabled")
        var application: NSRunningApplication? = .current
        var permission = true
        var reads = 0
        var captures = 0
        var completions: [(AwarenessEngine.Recognition) -> Void] = []
        var snapshots: [AwarenessSnapshot] = []
        var scenes: [PetScene] = []
        let engine = AwarenessEngine(
            defaults: defaults,
            applicationProvider: { reads += 1; return application },
            permissionCheck: { permission }, idleTimeProvider: { 1 },
            recognizer: { _, completion in captures += 1; completions.append(completion) }
        )
        engine.onSnapshot = { snapshot, _ in snapshots.append(snapshot) }
        engine.onSceneChange = { scene, _ in scenes.append(scene) }
        engine.start()
        precondition(captures == 1 && snapshots.count == 1, "App classification must not wait for OCR")
        precondition(!snapshots.last!.usedOCR, "No OCR source may be claimed before a result")

        application = nil
        engine.refreshNow()
        precondition(snapshots.last!.appName == "桌面", "App changes must remain responsive during OCR")
        application = .current
        engine.refreshNow()
        precondition(captures == 1, "App switches must not queue extra captures")
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(captures == 2 && !snapshots.last!.usedOCR, "An old app's text must be rejected")
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(snapshots.last!.usedOCR && scenes.last == .research, "Current OCR must be delivered")

        engine.setOCRInterval(8)
        engine.pause(for: 600)
        let pausedCount = snapshots.count
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(snapshots.count == pausedCount, "Pause must reject pending OCR")
        engine.resumeAutomatic()
        engine.preview(.meeting)
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(scenes.last == .meeting, "Pending OCR must not override manual preview")

        engine.resumeAutomatic()
        engine.setOCREnabled(false)
        let disabledOCRCount = snapshots.count
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(snapshots.count == disabledOCRCount + 1 && !snapshots.last!.usedOCR)
        engine.setOCREnabled(true)
        engine.setEnabled(false)
        let disabledCount = snapshots.count
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(snapshots.count == disabledCount, "Disabled awareness must reject pending OCR")

        engine.setEnabled(true)
        permission = false
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(!snapshots.last!.usedOCR && !engine.hasScreenCapturePermission,
            "Revoking permission must clear cached OCR and its source label")
        permission = true
        engine.refreshNow()
        engine.setSuspended(true)
        let suspendedReads = reads
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        engine.refreshNow()
        precondition(reads == suspendedReads, "A hidden/locked pet must not read the foreground app")
        engine.setSuspended(false)
        precondition(!completions.isEmpty, "Wake must resume awareness")
        engine.stop()
        let stoppedReads = reads
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(reads == stoppedReads, "Stopped awareness must ignore callbacks")
        engine.start()
        precondition(!completions.isEmpty, "The engine must restart after stop")
        completions.removeFirst()(("Google Scholar", "research paper"))
        pump()
        precondition(snapshots.last!.usedOCR)
        engine.stop()
        print("Awareness lifecycle: delayed OCR, app switches, pause, preview, disable, permission revocation, hide/wake, and restart passed")
    }
}
