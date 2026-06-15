//
//  ProfileSettingsView.swift
//  Doggo
//
//  Created by Sorest on 1/14/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProfileSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appContainer) private var appContainer
    @Bindable var profile: UserProfile

    @State private var weightLbs: Int = 150
    @State private var heightInches: Int = 70

    @AppStorage("useKeypadForSets") private var useKeypadForSets = false

    // MARK: - Import / Export State
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date, order: .reverse
    ) private var allHistory: [WorkoutSession]

    @State private var showFileImporter = false
    @State private var isParsingImport = false
    @State private var parsedImport: [CSVImporter.ImportedSession] = []
    @State private var showImportSummary = false
    @State private var importStatusMessage: String?

    let goals = ["Build Muscle", "Lose Fat", "Strength", "Endurance", "General Health"]
    let levels = ["Beginner", "Intermediate", "Advanced"]
    let activities = ["Sedentary", "Lightly Active", "Active", "Very Active (Athlete)"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Header (Same as before)
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue)
                            Text(profile.name).font(.title2).bold()
                            Text(profile.experienceLevel)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                }.listRowBackground(Color.clear)
                
                // AI Context
                Section(header: Text("AI Coach Context")) {
                    Picker("Current Goal", selection: $profile.fitnessGoal) {
                        ForEach(goals, id: \.self) { Text($0) }
                    }
                    Picker("Activity Level", selection: $profile.activityLevel) {
                        ForEach(activities, id: \.self) { Text($0) }
                    }
                    Picker("Experience", selection: $profile.experienceLevel) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                }
                
                // NEW: AI Integration Section
                Section(header: Text("Coach Integration"), footer: Text("When enabled, the AI will use your recent Coach Reports to adjust your weekly schedule and workout sets/reps.")) {
                    Toggle(isOn: $profile.useCoachForSchedule) {
                        Label("Optimize Weekly Planner", systemImage: "calendar")
                    }
                    Toggle(isOn: $profile.useCoachForRoutine) {
                        Label("Optimize Workouts", systemImage: "dumbbell")
                    }
                }
                
                // Split Strategy
                Section(header: Text("Training Strategy")) {
                    Picker("Preferred Split", selection: Binding(
                        get: { WorkoutSplit(rawValue: profile.splitPreference) ?? .flexible },
                        set: { profile.splitPreference = $0.rawValue }
                    )) {
                        ForEach(WorkoutSplit.allCases, id: \.self) { split in
                            Text(split.rawValue).tag(split)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        let currentSplit = WorkoutSplit(rawValue: profile.splitPreference) ?? .flexible
                        Text(currentSplit.description).font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 4)
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WHY IT WORKS:").font(.caption).bold().foregroundStyle(.green)
                            Text(currentSplit.pros).font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONSIDERATIONS:").font(.caption).bold().foregroundStyle(.orange)
                            Text(currentSplit.cons).font(.caption)
                        }
                    }.padding(.vertical, 8)
                }
                
                // NEW: App Preferences
                Section(header: Text("App Preferences")) {
                    Toggle(isOn: $useKeypadForSets) {
                        Label("Use Keypad for Sets", systemImage: "number.square")
                    }
                }

                // MARK: - Data (native share & import)
                Section {
                    ShareLink(
                        item: WorkoutBackupFile(makeCSV: { DataExporter.csvString(from: allHistory) }),
                        preview: SharePreview("Doggo Workout Backup", image: Image(systemName: "dumbbell.fill"))
                    ) {
                        Label("Export Backup (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(allHistory.isEmpty)

                    Button {
                        showFileImporter = true
                    } label: {
                        if isParsingImport {
                            HStack {
                                Label("Reading file…", systemImage: "square.and.arrow.down")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Import from CSV", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(isParsingImport)
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export shares a CSV backup via AirDrop, Messages, or Files. Import restores a backup — duplicates are detected and skipped.")
                }
                
                // Physical Stats
                Section("Physical Stats") {
                    Stepper("Age: \(profile.age)", value: $profile.age, in: 12...100)
                    HStack {
                        Text("Weight (lbs)")
                        Spacer()
                        TextField("Lbs", value: $weightLbs, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .onChange(of: weightLbs) { _, newValue in profile.weightKG = Double(newValue) * UnitSystem.kilogramsPerPound }
                    }
                    HStack {
                        Text("Height (in)")
                        Spacer()
                        TextField("Inches", value: $heightInches, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .onChange(of: heightInches) { _, newValue in profile.heightCM = Double(newValue) * 2.54 }
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar { Button("Done") { dismiss() } }
            .onAppear {
                weightLbs = Int(profile.weightKG * UnitSystem.poundsPerKilogram)
                heightInches = Int(profile.heightCM / 2.54)
            }
            // MARK: - Import Pipeline
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                parsePickedFile(url)
            }
            .sheet(isPresented: $showImportSummary) {
                ImportSummarySheet(sessions: parsedImport) {
                    runImport()
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Import", isPresented: Binding(
                get: { importStatusMessage != nil },
                set: { if !$0 { importStatusMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importStatusMessage = nil }
            } message: {
                Text(importStatusMessage ?? "")
            }
        }
    }

    // MARK: - Import Logic

    private func parsePickedFile(_ url: URL) {
        isParsingImport = true
        Task {
            do {
                let sessions = try await CSVImporter.parse(fileURL: url)
                await MainActor.run {
                    parsedImport = sessions
                    isParsingImport = false
                    showImportSummary = true
                }
            } catch {
                await MainActor.run {
                    isParsingImport = false
                    importStatusMessage = error.localizedDescription
                }
            }
        }
    }

    private func runImport() {
        guard let container = appContainer else {
            importStatusMessage = "Import unavailable — please relaunch the app."
            return
        }
        let sessions = parsedImport

        Task {
            do {
                // Runs entirely on the repository's background ModelActor
                let result = try await container.workoutRepository.importSessions(sessions)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    importStatusMessage = result.skippedDuplicates > 0
                        ? "Imported \(result.importedSessions) workouts. Skipped \(result.skippedDuplicates) duplicates."
                        : "Imported \(result.importedSessions) workouts."
                    parsedImport = []
                }
            } catch {
                await MainActor.run {
                    importStatusMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

