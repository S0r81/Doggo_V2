//
//  PeptideRepository.swift
//  Doggo_V2
//
//  Background-safe persistence for the peptide tracker. Mirrors
//  WorkoutRepository: a @ModelActor with its own context. Every mutation
//  takes value types or a Sendable PersistentIdentifier and resolves the
//  model on THIS actor's context — a model created here never crosses into a
//  main-context relationship, which is the cross-context handoff that crashes.
//

import Foundation
import SwiftData

/// Sendable carrier for schedule edits across the actor boundary.
struct PeptideScheduleConfig: Sendable {
    var frequency: PeptideFrequency
    var targetDoseMcg: Double
    var doseUnit: PeptideMeasurementUnit
    var specificWeekdays: [String]
    var daysOn: Int
    var daysOff: Int
    var anchorDate: Date
    var reminderHour: Int
    var reminderMinute: Int
    var remindersEnabled: Bool

    init(
        frequency: PeptideFrequency = .daily,
        targetDoseMcg: Double = 0,
        doseUnit: PeptideMeasurementUnit = .mcg,
        specificWeekdays: [String] = [],
        daysOn: Int = 5,
        daysOff: Int = 2,
        anchorDate: Date = Date(),
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        remindersEnabled: Bool = true
    ) {
        self.frequency = frequency
        self.targetDoseMcg = targetDoseMcg
        self.doseUnit = doseUnit
        self.specificWeekdays = specificWeekdays
        self.daysOn = daysOn
        self.daysOff = daysOff
        self.anchorDate = anchorDate
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.remindersEnabled = remindersEnabled
    }
}

/// Mutations only — reads happen via @Query on the main context. Returning
/// models from the actor would hand background-context objects to the UI, the
/// exact cross-context leak this design avoids; every method here takes value
/// types or a Sendable PersistentIdentifier instead.
protocol PeptideRepositoryProtocol {
    @discardableResult
    func createProfile(name: String, totalMg: Double, waterAddedMl: Double, vialUnit: PeptideMeasurementUnit) async throws -> PersistentIdentifier
    func updateReconstitution(profileID: PersistentIdentifier, name: String, totalMg: Double, waterAddedMl: Double, vialUnit: PeptideMeasurementUnit) async throws
    func setActive(profileID: PersistentIdentifier, isActive: Bool) async throws
    func deleteProfile(id: PersistentIdentifier) async throws

    func setSchedule(profileID: PersistentIdentifier, config: PeptideScheduleConfig) async throws

    @discardableResult
    func logDose(profileID: PersistentIdentifier, doseMcg: Double, doseUnit: PeptideMeasurementUnit, date: Date, note: String?) async throws -> PersistentIdentifier
    func deleteLog(id: PersistentIdentifier) async throws
}

@ModelActor
actor PeptideRepository: PeptideRepositoryProtocol {

    // MARK: - Profiles

    @discardableResult
    func createProfile(name: String, totalMg: Double, waterAddedMl: Double, vialUnit: PeptideMeasurementUnit) async throws -> PersistentIdentifier {
        let profile = PeptideProfile(name: name, totalMg: totalMg, waterAddedMl: waterAddedMl, vialUnit: vialUnit)
        modelContext.insert(profile)
        try modelContext.save()
        return profile.persistentModelID
    }

    func updateReconstitution(profileID: PersistentIdentifier, name: String, totalMg: Double, waterAddedMl: Double, vialUnit: PeptideMeasurementUnit) async throws {
        guard let profile = self[profileID, as: PeptideProfile.self] else { return }
        profile.name = name
        profile.totalMg = totalMg
        profile.waterAddedMl = waterAddedMl
        profile.vialUnit = vialUnit
        try modelContext.save()
    }

    func setActive(profileID: PersistentIdentifier, isActive: Bool) async throws {
        guard let profile = self[profileID, as: PeptideProfile.self] else { return }
        profile.isActive = isActive
        try modelContext.save()
    }

    func deleteProfile(id: PersistentIdentifier) async throws {
        guard let profile = self[id, as: PeptideProfile.self] else { return }
        modelContext.delete(profile)   // cascades schedule + logs
        try modelContext.save()
    }

    // MARK: - Schedule

    func setSchedule(profileID: PersistentIdentifier, config: PeptideScheduleConfig) async throws {
        guard let profile = self[profileID, as: PeptideProfile.self] else { return }

        let schedule = profile.schedule ?? {
            let new = PeptideSchedule()
            modelContext.insert(new)
            new.profile = profile
            profile.schedule = new
            return new
        }()

        schedule.frequency = config.frequency
        schedule.targetDoseMcg = config.targetDoseMcg
        schedule.doseUnit = config.doseUnit
        schedule.specificWeekdays = config.specificWeekdays
        schedule.daysOn = config.daysOn
        schedule.daysOff = config.daysOff
        schedule.anchorDate = config.anchorDate
        schedule.reminderHour = config.reminderHour
        schedule.reminderMinute = config.reminderMinute
        schedule.remindersEnabled = config.remindersEnabled

        try modelContext.save()
    }

    // MARK: - Logs

    @discardableResult
    func logDose(profileID: PersistentIdentifier, doseMcg: Double, doseUnit: PeptideMeasurementUnit, date: Date, note: String?) async throws -> PersistentIdentifier {
        guard let profile = self[profileID, as: PeptideProfile.self] else {
            throw PeptideRepositoryError.profileNotFound
        }
        let log = PeptideLog(date: date, doseTakenMcg: doseMcg, doseUnit: doseUnit, note: note)
        modelContext.insert(log)
        log.profile = profile
        try modelContext.save()
        return log.persistentModelID
    }

    func deleteLog(id: PersistentIdentifier) async throws {
        guard let log = self[id, as: PeptideLog.self] else { return }
        modelContext.delete(log)
        try modelContext.save()
    }
}

enum PeptideRepositoryError: LocalizedError {
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .profileNotFound: return "That peptide profile no longer exists."
        }
    }
}
