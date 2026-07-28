import Foundation

private struct SceneCase {
    let name: String
    let app: String
    let bundle: String
    let title: String
    let text: String
    let idle: TimeInterval
    let active: TimeInterval
    let hour: Int
    let expected: PetScene
}

@main
enum AwarenessClassifierTests {
    static func main() {
        let cases: [SceneCase] = [
            SceneCase(name: "coding", app: "Codex", bundle: "com.openai.codex", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .coding),
            SceneCase(name: "claude coding", app: "Claude", bundle: "com.anthropic.claudefordesktop", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .coding),
            SceneCase(name: "debugging", app: "Xcode", bundle: "com.apple.dt.Xcode", title: "", text: "Build Failed fatal error", idle: 1, active: 30, hour: 14, expected: .debugging),
            SceneCase(name: "success", app: "Terminal", bundle: "com.apple.Terminal", title: "", text: "All tests passed 0 failures", idle: 1, active: 30, hour: 14, expected: .success),
            SceneCase(name: "spreadsheet", app: "Microsoft Excel", bundle: "com.microsoft.Excel", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .spreadsheet),
            SceneCase(name: "long work", app: "Microsoft Excel", bundle: "com.microsoft.Excel", title: "", text: "", idle: 1, active: 3_100, hour: 14, expected: .jailWork),
            SceneCase(name: "finance", app: "Bloomberg", bundle: "com.bloomberg", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .finance),
            SceneCase(name: "writing", app: "Microsoft Word", bundle: "com.microsoft.Word", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .writing),
            SceneCase(name: "reading", app: "Preview", bundle: "com.apple.Preview", title: "paper.pdf", text: "", idle: 1, active: 30, hour: 14, expected: .reading),
            SceneCase(name: "research", app: "Google Chrome", bundle: "com.google.Chrome", title: "Google Scholar", text: "research paper", idle: 1, active: 30, hour: 14, expected: .research),
            SceneCase(name: "meeting", app: "zoom.us", bundle: "us.zoom.xos", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .meeting),
            SceneCase(name: "messaging", app: "Slack", bundle: "com.tinyspeck.slackmacgap", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .messaging),
            SceneCase(name: "email", app: "Mail", bundle: "com.apple.mail", title: "Inbox", text: "", idle: 1, active: 30, hour: 14, expected: .email),
            SceneCase(name: "design", app: "Figma", bundle: "com.figma.Desktop", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .design),
            SceneCase(name: "video", app: "Google Chrome", bundle: "com.google.Chrome", title: "YouTube", text: "", idle: 1, active: 30, hour: 14, expected: .entertainment),
            SceneCase(name: "music", app: "Spotify", bundle: "com.spotify.client", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .music),
            SceneCase(name: "gaming", app: "Steam", bundle: "com.valvesoftware.steam", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .gaming),
            SceneCase(name: "shopping", app: "Safari", bundle: "com.apple.Safari", title: "淘宝", text: "购物车", idle: 1, active: 30, hour: 14, expected: .shopping),
            SceneCase(name: "browser", app: "Safari", bundle: "com.apple.Safari", title: "Example", text: "", idle: 1, active: 30, hour: 14, expected: .browsing),
            SceneCase(name: "break", app: "Finder", bundle: "com.apple.finder", title: "", text: "", idle: 1, active: 30, hour: 14, expected: .breakTime),
            SceneCase(name: "away priority", app: "Codex", bundle: "com.openai.codex", title: "", text: "", idle: 301, active: 30, hour: 14, expected: .away),
            SceneCase(name: "late coding stays coding", app: "Codex", bundle: "com.openai.codex", title: "", text: "", idle: 1, active: 30, hour: 23, expected: .coding),
            SceneCase(name: "late generic", app: "Finder", bundle: "com.apple.finder", title: "", text: "", idle: 1, active: 30, hour: 23, expected: .lateNight)
        ]

        var failures: [String] = []
        if PetScene.allCases.count != 23 {
            failures.append("scene count: expected 23, got \(PetScene.allCases.count)")
        }
        for item in cases {
            let result = AwarenessClassifier.classify(
                appName: item.app,
                bundleIdentifier: item.bundle,
                windowTitle: item.title,
                ocrText: item.text,
                idleSeconds: item.idle,
                activeDuration: item.active,
                hour: item.hour
            )
            if result != item.expected {
                failures.append("\(item.name): expected \(item.expected.rawValue), got \(result.rawValue)")
            }
        }

        if failures.isEmpty {
            print("Awareness classifier: \(cases.count) cases passed")
        } else {
            for failure in failures {
                fputs("FAIL: \(failure)\n", stderr)
            }
            exit(1)
        }
    }
}
