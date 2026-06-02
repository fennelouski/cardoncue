//
//  PersistenceHelper.swift
//  CardOnCue
//
//  Centralized SwiftData save that surfaces errors instead of silently
//  swallowing them via `try?`.
//

import Foundation
import SwiftData
import os

enum PersistenceHelper {
    private static let logger = Logger(subsystem: "app.cardoncue.CardOnCue", category: "Persistence")

    /// Saves the model context, logging any failure. Returns true on success.
    /// No-ops (and returns true) when there are no pending changes.
    @discardableResult
    @MainActor
    static func save(_ context: ModelContext, label: String = "") -> Bool {
        guard context.hasChanges else { return true }
        do {
            try context.save()
            return true
        } catch {
            logger.error("SwiftData save failed [\(label, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

/// Stable local owner identifier for cards. Data is already scoped to the
/// user's private CloudKit database; this is just a consistent owner tag that
/// survives relaunches (replaces the old hardcoded "local").
enum AppUser {
    private static let key = "localUserId"

    static var id: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
