#!/usr/bin/env swift

import Foundation

private let edits: [String: [(String, String)]] = [
    "desktop": [
        ("appearanceLightCodeThemeId", "\"rose-pine-dawn\""),
        ("appearanceDarkCodeThemeId", "\"rose-pine-moon\""),
        ("appearanceTheme", "\"dark\""),
        ("selected-avatar-id", "\"custom:xiaoxiao\""),
        ("avatar-overlay-mascot-width-px", "96")
    ],
    "desktop.appearanceLightChromeTheme": [
        ("accent", "\"#C4473D\""),
        ("contrast", "52"),
        ("ink", "\"#3A2B29\""),
        ("opaqueWindows", "false"),
        ("surface", "\"#FFF8EF\"")
    ],
    "desktop.appearanceLightChromeTheme.semanticColors": [
        ("diffAdded", "\"#2F8F78\""),
        ("diffRemoved", "\"#D95D4F\""),
        ("skill", "\"#3E8292\"")
    ],
    "desktop.appearanceDarkChromeTheme": [
        ("accent", "\"#E15A4F\""),
        ("contrast", "62"),
        ("ink", "\"#FFF8F0\""),
        ("opaqueWindows", "false"),
        ("surface", "\"#25211F\"")
    ],
    "desktop.appearanceDarkChromeTheme.semanticColors": [
        ("diffAdded", "\"#54B79D\""),
        ("diffRemoved", "\"#FF735F\""),
        ("skill", "\"#72AEB7\"")
    ]
]

private func sectionName(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("["),
          trimmed.hasSuffix("]"),
          !trimmed.hasPrefix("[[") else {
        return nil
    }
    return String(trimmed.dropFirst().dropLast())
}

private func keyName(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.hasPrefix("#"),
          let equals = trimmed.firstIndex(of: "=") else {
        return nil
    }
    return String(trimmed[..<equals]).trimmingCharacters(in: .whitespaces)
}

private func patch(_ source: String) -> String {
    let inputLines = source.split(
        separator: "\n",
        omittingEmptySubsequences: false
    ).map(String.init)
    var output: [String] = []
    var currentSection: String?
    var seenSections = Set<String>()
    var writtenKeys: [String: Set<String>] = [:]

    func appendMissingKeys(for section: String?) {
        guard let section, let sectionEdits = edits[section] else { return }
        let written = writtenKeys[section] ?? []
        for (key, value) in sectionEdits where !written.contains(key) {
            output.append("\(key) = \(value)")
        }
    }

    for line in inputLines {
        if let nextSection = sectionName(from: line) {
            appendMissingKeys(for: currentSection)
            currentSection = nextSection
            seenSections.insert(nextSection)
            output.append(line)
            continue
        }

        if let currentSection,
           let key = keyName(from: line),
           let replacement = edits[currentSection]?.first(where: { $0.0 == key }) {
            output.append("\(key) = \(replacement.1)")
            writtenKeys[currentSection, default: []].insert(key)
        } else {
            output.append(line)
        }
    }
    appendMissingKeys(for: currentSection)

    for section in edits.keys.sorted() where !seenSections.contains(section) {
        if output.last?.isEmpty == false {
            output.append("")
        }
        output.append("[\(section)]")
        for (key, value) in edits[section] ?? [] {
            output.append("\(key) = \(value)")
        }
    }

    return output.joined(separator: "\n")
        .trimmingCharacters(in: .newlines) + "\n"
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("Usage: apply_codex_skin.swift <config.toml>\n".utf8)
    )
    exit(2)
}

let configURL = URL(fileURLWithPath: CommandLine.arguments[1])
do {
    let attributes = try FileManager.default.attributesOfItem(
        atPath: configURL.path
    )
    let originalPermissions = attributes[.posixPermissions]
    let source = try String(contentsOf: configURL, encoding: .utf8)
    let updated = patch(source)
    try updated.write(to: configURL, atomically: true, encoding: .utf8)
    if let originalPermissions {
        try FileManager.default.setAttributes(
            [.posixPermissions: originalPermissions],
            ofItemAtPath: configURL.path
        )
    }
    print("Updated Codex appearance: \(configURL.path)")
} catch {
    FileHandle.standardError.write(
        Data("Failed to update Codex config: \(error.localizedDescription)\n".utf8)
    )
    exit(1)
}
