//
//  CoachContextAssembler.swift
//  Doggo_V2
//
//  Serializes the user's "What Coach knows" items into one compact, deterministic
//  block for prompt injection. Pure and testable — no SwiftData, no UI.
//
//  Token discipline: an empty store yields "" (no headers, no wasted tokens, and
//  therefore no prompt drift for users who never set any context). Categories
//  with no items are skipped. Output order is fixed (by category, then by the
//  item's sortOrder/createdAt) so the same store always produces the same block.
//

import Foundation

nonisolated enum CoachContextAssembler {

    /// A compact, grouped block of the user's standing context, or "" if there
    /// is nothing to say.
    static func contextBlock(from items: [CoachContextItem]) -> String {
        guard !items.isEmpty else { return "" }

        var lines: [String] = []
        for category in CoachContextCategory.allCases {          // fixed order
            let entries = items
                .filter { $0.category == category }
                .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !entries.isEmpty else { continue }
            lines.append("\(category.promptHeading):")
            lines.append(contentsOf: entries.map { "- \($0)" })
        }

        guard !lines.isEmpty else { return "" }                  // all-whitespace items
        return """
        WHAT YOU KNOW ABOUT THIS USER (always honor these without being reminded):
        \(lines.joined(separator: "\n"))
        """
    }

    /// Count of non-empty items — drives the "Coach is using N notes" badge.
    static func activeCount(_ items: [CoachContextItem]) -> Int {
        items.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}
