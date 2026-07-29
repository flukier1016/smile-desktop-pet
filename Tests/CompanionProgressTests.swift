import Foundation

private enum TestFailure: Error {
    case failed(String)
}

@main
enum CompanionProgressTests {
    static func main() throws {
        let suiteName = "SmilePet.CompanionProgressTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure.failed("Unable to create isolated UserDefaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayOne = Date(timeIntervalSince1970: 1_767_225_600)
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let dayFour = calendar.date(byAdding: .day, value: 3, to: dayOne)!
        let store = CompanionStore(defaults: defaults, calendar: calendar)

        let firstPat = store.record(.pat, at: dayOne)
        try expect(firstPat.isFirstCareToday, "first pat should count for daily care")
        try expect(firstPat.after.completedCareCount == 1, "daily care should be 1/4")
        try expect(firstPat.after.totalExperience == 5, "first daily action should include bonus")

        let secondPat = store.record(.pat, at: dayOne)
        try expect(!secondPat.isFirstCareToday, "repeated pat must not duplicate daily care")
        try expect(secondPat.after.completedCareCount == 1, "daily care must stay 1/4")
        try expect(secondPat.after.totalExperience == 8, "repeated action should still award base XP")

        _ = store.record(.feed, at: dayOne)
        _ = store.record(.praise, at: dayOne)
        let firstCompletion = store.record(.fortune, at: dayOne)
        try expect(firstCompletion.didCompleteDailyCare, "four unique care actions should complete the day")
        try expect(firstCompletion.after.isDailyCareComplete, "daily care completion should persist")
        try expect(firstCompletion.after.streak == 1, "first completed day should start streak")

        let nextMorning = store.snapshot(at: dayTwo)
        try expect(nextMorning.completedCareCount == 0, "daily care should reset on a new day")
        try expect(nextMorning.streak == 1, "streak should remain until the next completion")

        _ = store.record(.pat, at: dayTwo)
        _ = store.record(.feed, at: dayTwo)
        _ = store.record(.praise, at: dayTwo)
        let secondCompletion = store.record(.fortune, at: dayTwo)
        try expect(secondCompletion.after.streak == 2, "consecutive completion should extend streak")

        _ = store.record(.pat, at: dayFour)
        _ = store.record(.feed, at: dayFour)
        _ = store.record(.praise, at: dayFour)
        let brokenStreak = store.record(.fortune, at: dayFour)
        try expect(brokenStreak.after.streak == 1, "skipping a day should reset streak")

        let beforeWalkLevel = brokenStreak.after.level
        var latest = brokenStreak.after
        for _ in 0..<50 {
            latest = store.record(.walk, at: dayFour).after
        }
        try expect(latest.level > beforeWalkLevel, "experience should unlock higher levels")
        try expect(latest.levelProgress >= 0 && latest.levelProgress <= 1, "level progress must be bounded")

        let fortuneOne = CompanionDailyContent.fortune(for: dayOne, calendar: calendar)
        let fortuneAgain = CompanionDailyContent.fortune(for: dayOne, calendar: calendar)
        let fortuneNextDay = CompanionDailyContent.fortune(for: dayTwo, calendar: calendar)
        try expect(fortuneOne == fortuneAgain, "fortune must be stable within one day")
        try expect(fortuneOne != fortuneNextDay, "fortune should rotate on the next day")

        print("Companion progress: 14 cases passed")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        if !condition() {
            throw TestFailure.failed(message)
        }
    }
}
