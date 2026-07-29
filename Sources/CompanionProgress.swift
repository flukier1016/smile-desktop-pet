import Foundation

enum CompanionCareItem: String, CaseIterable, Hashable {
    case pat
    case feed
    case praise
    case fortune

    var title: String {
        switch self {
        case .pat: return "摸摸"
        case .feed: return "喂食"
        case .praise: return "夸夸"
        case .fortune: return "抽签"
        }
    }

    var emoji: String {
        switch self {
        case .pat: return "🫳"
        case .feed: return "🍪"
        case .praise: return "✨"
        case .fortune: return "🔮"
        }
    }
}

enum CompanionAction: String {
    case pat
    case poke
    case feed
    case praise
    case fortune
    case walk
    case celebrate

    var experience: Int {
        switch self {
        case .pat: return 3
        case .poke: return 1
        case .feed: return 5
        case .praise: return 4
        case .fortune: return 3
        case .walk: return 6
        case .celebrate: return 4
        }
    }

    var careItem: CompanionCareItem? {
        switch self {
        case .pat: return .pat
        case .feed: return .feed
        case .praise: return .praise
        case .fortune: return .fortune
        case .poke, .walk, .celebrate: return nil
        }
    }
}

struct CompanionSnapshot {
    let totalExperience: Int
    let totalInteractions: Int
    let level: Int
    let levelTitle: String
    let levelProgress: Double
    let experienceInLevel: Int
    let experienceForNextLevel: Int?
    let completedCareItems: Set<CompanionCareItem>
    let careGoal: Int
    let streak: Int

    var completedCareCount: Int {
        completedCareItems.count
    }

    var isDailyCareComplete: Bool {
        completedCareCount >= careGoal
    }
}

struct CompanionUpdate {
    let action: CompanionAction
    let before: CompanionSnapshot
    let after: CompanionSnapshot
    let isFirstCareToday: Bool
    let didCompleteDailyCare: Bool
    let didLevelUp: Bool
}

final class CompanionStore {
    private enum Key {
        static let dayStamp = "companion.dayStamp"
        static let dailyCare = "companion.dailyCare"
        static let dailyAwarded = "companion.dailyAwarded"
        static let totalExperience = "companion.totalExperience"
        static let totalInteractions = "companion.totalInteractions"
        static let streak = "companion.streak"
        static let lastCompletedDay = "companion.lastCompletedDay"
    }

    private static let levelThresholds = [0, 40, 100, 180, 280]
    private static let levelTitles = [
        "初见搭子",
        "熟悉同桌",
        "默契拍档",
        "桌面知己",
        "灵魂工友"
    ]

    private let defaults: UserDefaults
    private var calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func snapshot(at date: Date = Date()) -> CompanionSnapshot {
        rollOverIfNeeded(at: date)
        return makeSnapshot()
    }

    @discardableResult
    func record(
        _ action: CompanionAction,
        at date: Date = Date()
    ) -> CompanionUpdate {
        rollOverIfNeeded(at: date)
        let before = makeSnapshot()
        var careItems = storedCareItems()
        let isFirstCare = action.careItem.map { !careItems.contains($0) } ?? false

        if let careItem = action.careItem {
            careItems.insert(careItem)
            defaults.set(careItems.map(\.rawValue).sorted(), forKey: Key.dailyCare)
        }

        var awardedExperience = action.experience
        if isFirstCare {
            awardedExperience += 2
        }

        let completedNow = careItems.count == CompanionCareItem.allCases.count
            && !defaults.bool(forKey: Key.dailyAwarded)
        if completedNow {
            awardedExperience += 20
            defaults.set(true, forKey: Key.dailyAwarded)
            updateStreak(at: date)
        }

        defaults.set(
            defaults.integer(forKey: Key.totalExperience) + awardedExperience,
            forKey: Key.totalExperience
        )
        defaults.set(
            defaults.integer(forKey: Key.totalInteractions) + 1,
            forKey: Key.totalInteractions
        )

        let after = makeSnapshot()
        return CompanionUpdate(
            action: action,
            before: before,
            after: after,
            isFirstCareToday: isFirstCare,
            didCompleteDailyCare: completedNow,
            didLevelUp: after.level > before.level
        )
    }

    private func rollOverIfNeeded(at date: Date) {
        let stamp = dayStamp(for: date)
        guard defaults.string(forKey: Key.dayStamp) != stamp else { return }
        defaults.set(stamp, forKey: Key.dayStamp)
        defaults.set([], forKey: Key.dailyCare)
        defaults.set(false, forKey: Key.dailyAwarded)
    }

    private func storedCareItems() -> Set<CompanionCareItem> {
        let values = defaults.stringArray(forKey: Key.dailyCare) ?? []
        return Set(values.compactMap(CompanionCareItem.init(rawValue:)))
    }

    private func makeSnapshot() -> CompanionSnapshot {
        let totalExperience = defaults.integer(forKey: Key.totalExperience)
        let levelIndex = Self.levelThresholds.lastIndex(where: {
            totalExperience >= $0
        }) ?? 0
        let isMaximumLevel = levelIndex == Self.levelThresholds.count - 1
        let currentThreshold = Self.levelThresholds[levelIndex]
        let nextThreshold = isMaximumLevel
            ? nil
            : Self.levelThresholds[levelIndex + 1]
        let progress: Double
        if let nextThreshold {
            progress = Double(totalExperience - currentThreshold)
                / Double(nextThreshold - currentThreshold)
        } else {
            progress = 1
        }

        return CompanionSnapshot(
            totalExperience: totalExperience,
            totalInteractions: defaults.integer(forKey: Key.totalInteractions),
            level: levelIndex + 1,
            levelTitle: Self.levelTitles[levelIndex],
            levelProgress: max(0, min(1, progress)),
            experienceInLevel: totalExperience - currentThreshold,
            experienceForNextLevel: nextThreshold.map { $0 - currentThreshold },
            completedCareItems: storedCareItems(),
            careGoal: CompanionCareItem.allCases.count,
            streak: defaults.integer(forKey: Key.streak)
        )
    }

    private func updateStreak(at date: Date) {
        let previousStreak = defaults.integer(forKey: Key.streak)
        let newStreak: Int
        if let lastCompleted = defaults.object(forKey: Key.lastCompletedDay) as? Date,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
           calendar.isDate(lastCompleted, inSameDayAs: yesterday) {
            newStreak = max(1, previousStreak + 1)
        } else {
            newStreak = 1
        }
        defaults.set(newStreak, forKey: Key.streak)
        defaults.set(date, forKey: Key.lastCompletedDay)
    }

    private func dayStamp(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum CompanionDailyContent {
    private static let fortunes = [
        "大吉 · 先做最难的五分钟，后面会越来越顺。",
        "小吉 · 今天的好运藏在一次勇敢发送里。",
        "元气 · 喝水、伸懒腰，然后漂亮地拿下一件事。",
        "灵感 · 先记下那个怪点子，它可能比想象中有用。",
        "稳稳 · 不追赶别人，按自己的节奏完成就很好。",
        "惊喜 · 一个小小的好消息正在向你靠近。",
        "清醒 · 收藏不等于购买，保存也不等于提交。",
        "顺利 · 今天适合把拖了很久的小事一口气清掉。"
    ]

    static func fortune(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = (components.year ?? 0) * 372
            + (components.month ?? 0) * 31
            + (components.day ?? 0)
        return fortunes[abs(seed) % fortunes.count]
    }
}
