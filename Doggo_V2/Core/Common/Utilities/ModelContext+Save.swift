//
//  ModelContext+Save.swift
//  Doggo_V2
//
//  Silent `try?` saves were scattered across the app — a failed write would
//  vanish and the user would lose data with no signal anywhere. saveLogging
//  logs failures (and no-ops when there's nothing to write), so data-loss bugs
//  are at least visible in the console / Console.app.
//

import SwiftData
import OSLog

extension ModelContext {
    private static let logger = Logger(subsystem: "com.guavi.Doggo-V2", category: "persistence")

    /// Saves pending changes, logging any failure instead of swallowing it.
    /// Skips the round-trip entirely when there are no changes.
    func saveLogging(_ operation: String = #function, file: String = #fileID) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            Self.logger.error("SwiftData save failed in \(operation, privacy: .public) [\(file, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
        }
    }
}
