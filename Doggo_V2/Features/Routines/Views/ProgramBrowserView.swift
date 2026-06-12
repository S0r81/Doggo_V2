//
//  ProgramBrowserView.swift
//  Doggo_V2
//
//  Browse and install the bundled training programs.
//

import SwiftUI
import SwiftData

struct ProgramBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \CustomProgram.createdAt, order: .reverse) private var customPrograms: [CustomProgram]

    @State private var selectedProgram: ProgramDefinition?
    @State private var editingCustomProgram: CustomProgram?
    @State private var showNewProgram = false

    private var orderedPrograms: [ProgramDefinition] {
        guard let profile = profiles.first else { return ProgramCatalog.all }
        return ProgramCatalog.recommended(
            experience: profile.experienceLevel,
            goal: profile.fitnessGoal
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    // MARK: - Your Programs
                    if !customPrograms.isEmpty {
                        Text("Your Programs")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(customPrograms) { program in
                            Button {
                                editingCustomProgram = program
                            } label: {
                                CustomProgramCard(program: program)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }

                        Text("Doggo Programs")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.sm)
                    }

                    ForEach(Array(orderedPrograms.enumerated()), id: \.element.id) { index, program in
                        Button {
                            selectedProgram = program
                        } label: {
                            ProgramCard(
                                program: program,
                                isRecommended: index == 0 && profiles.first != nil,
                                isInstalled: ProgramInstaller.isInstalled(program, context: modelContext)
                            )
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, Spacing.sm)
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProgram = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New program")
                }
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
            .sheet(item: $editingCustomProgram) { program in
                CustomProgramEditorView(programToEdit: program)
            }
            .sheet(isPresented: $showNewProgram) {
                CustomProgramEditorView(programToEdit: nil)
            }
        }
    }
}

// MARK: - Custom Program Card

struct CustomProgramCard: View {
    let program: CustomProgram

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(program.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Custom program")
            }

            if !program.details.isEmpty {
                Text(program.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Label("\(program.routineIDs.count) days/week", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .cardSurface()
    }
}

// MARK: - Card

struct ProgramCard: View {
    let program: ProgramDefinition
    let isRecommended: Bool
    let isInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(program.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if isRecommended {
                    Text("FOR YOU")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                Spacer()

                if isInstalled {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }

            Text(program.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.sm) {
                Label("\(program.daysPerWeek) days/week", systemImage: "calendar")
                Label(program.level, systemImage: "figure.strengthtraining.traditional")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .cardSurface()
    }
}

// MARK: - Detail & Install

struct ProgramDetailView: View {
    let program: ProgramDefinition

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var replaceSchedule = false
    @State private var installResult: ProgramInstaller.Result?
    @State private var showUninstallConfirm = false
    @State private var uninstallMessage: String?

    private var isInstalled: Bool {
        ProgramInstaller.isInstalled(program, context: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(program.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LabeledContent("Frequency", value: "\(program.daysPerWeek) days/week")
                    LabeledContent("Level", value: program.level)
                    LabeledContent("Scheduled on", value: program.defaultWeekdays.map { String($0.prefix(3)) }.joined(separator: ", "))
                }

                ForEach(program.days, id: \.name) { day in
                    Section(day.name) {
                        ForEach(Array(day.items.enumerated()), id: \.offset) { _, item in
                            HStack {
                                if item.supersetGroup != nil {
                                    Capsule().fill(Color.pink).frame(width: 4)
                                }
                                Text(item.exercise)
                                Spacer()
                                Text("\(item.sets) × \(item.reps)")
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Replace current weekly schedule", isOn: $replaceSchedule)

                    Button {
                        let result = ProgramInstaller.install(
                            program,
                            replaceSchedule: replaceSchedule,
                            context: modelContext
                        )
                        HapticManager.shared.notification(type: .success)
                        installResult = result
                    } label: {
                        Label(
                            isInstalled ? "Install Again" : "Install Program",
                            systemImage: "square.and.arrow.down"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                } footer: {
                    Text(replaceSchedule
                         ? "Your existing weekly plan will be cleared and replaced."
                         : "Only empty days on your weekly plan will be filled.")
                }

                if isInstalled {
                    Section {
                        Button(role: .destructive) {
                            showUninstallConfirm = true
                        } label: {
                            Label("Uninstall Program", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text("Removes this program's routines and clears them from your weekly schedule. Your workout history is not affected.")
                    }
                }
            }
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Program Installed", isPresented: Binding(
                get: { installResult != nil },
                set: { if !$0 { installResult = nil } }
            )) {
                Button("Done") {
                    installResult = nil
                    dismiss()
                }
            } message: {
                if let result = installResult {
                    Text("Added \(result.routinesCreated) routines and scheduled \(result.daysScheduled) days. Find them on the Lift tab.")
                }
            }
            .confirmationDialog("Uninstall \(program.name)?", isPresented: $showUninstallConfirm, titleVisibility: .visible) {
                Button("Uninstall", role: .destructive) {
                    let removed = ProgramInstaller.uninstall(program, context: modelContext)
                    HapticManager.shared.impact(style: .medium)
                    uninstallMessage = "Removed \(removed) routine\(removed == 1 ? "" : "s") and cleared them from your schedule."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its routines are deleted, but every workout you logged stays in History.")
            }
            .alert("Program Uninstalled", isPresented: Binding(
                get: { uninstallMessage != nil },
                set: { if !$0 { uninstallMessage = nil } }
            )) {
                Button("Done") {
                    uninstallMessage = nil
                    dismiss()
                }
            } message: {
                Text(uninstallMessage ?? "")
            }
        }
    }
}

// MARK: - Custom Program Editor
// Create or edit a user program: pick your own routines, assign days,
// apply to the weekly schedule, or delete the bundle (routines survive).

struct CustomProgramEditorView: View {
    let programToEdit: CustomProgram?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Routine.name) private var allRoutines: [Routine]

    @State private var name = ""
    @State private var details = ""
    @State private var entries: [(routineID: String, day: String)] = []
    @State private var replaceSchedule = false
    @State private var showDeleteConfirm = false
    @State private var statusMessage: String?

    private var routinesByID: [String: Routine] {
        Dictionary(uniqueKeysWithValues: allRoutines.map { ($0.id.uuidString, $0) })
    }

    private var unusedRoutines: [Routine] {
        let used = Set(entries.map(\.routineID))
        return allRoutines.filter { !used.contains($0.id.uuidString) && !$0.isDeleted }
    }

    private var nextFreeDay: String {
        let used = Set(entries.map(\.day))
        return weekdayNames.first { !used.contains($0) } ?? "Monday"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Program") {
                    TextField("Name (e.g. My Summer Block)", text: $name)
                    TextField("Notes (optional)", text: $details, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    if entries.isEmpty {
                        Text("Add routines from your library to build the program.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(routinesByID[entry.routineID]?.name ?? "Missing Routine")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(routinesByID[entry.routineID] == nil ? .red : .primary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { entries[index].day },
                                set: { entries[index].day = $0 }
                            )) {
                                ForEach(weekdayNames, id: \.self) { Text(String($0.prefix(3))).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                    .onDelete { offsets in
                        entries.remove(atOffsets: offsets)
                    }

                    if !unusedRoutines.isEmpty {
                        Menu {
                            ForEach(unusedRoutines) { routine in
                                Button(routine.name) {
                                    entries.append((routine.id.uuidString, nextFreeDay))
                                }
                            }
                        } label: {
                            Label("Add Routine", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Routines & Days")
                } footer: {
                    Text("Two routines on the same day: the later one wins when applied.")
                }

                // Apply to schedule (saved programs only need Save first)
                Section {
                    Toggle("Replace current weekly schedule", isOn: $replaceSchedule)

                    Button {
                        applySchedule()
                    } label: {
                        Label("Apply to Weekly Schedule", systemImage: "calendar.badge.checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                    .disabled(entries.isEmpty)
                }

                if programToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Program", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text("Deletes only the program bundle — your routines stay in the library.")
                    }
                }
            }
            .navigationTitle(programToEdit == nil ? "New Program" : "Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || entries.isEmpty)
                }
            }
            .onAppear { loadIfEditing() }
            .alert("Delete Program?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let program = programToEdit {
                        modelContext.delete(program)
                        try? modelContext.save()
                    }
                    dismiss()
                }
            } message: {
                Text("Your routines and workout history are not affected.")
            }
            .alert("Schedule Applied", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) { statusMessage = nil }
            } message: {
                Text(statusMessage ?? "")
            }
        }
    }

    private func loadIfEditing() {
        guard let program = programToEdit, entries.isEmpty, name.isEmpty else { return }
        name = program.name
        details = program.details
        entries = zip(program.routineIDs, program.weekdays).map { ($0, $1) }
    }

    private func save() {
        let program = programToEdit ?? CustomProgram(name: name)
        program.name = name
        program.details = details
        program.routineIDs = entries.map(\.routineID)
        program.weekdays = entries.map(\.day)
        if programToEdit == nil {
            modelContext.insert(program)
        }
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
    }

    private func applySchedule() {
        guard let profile = profiles.first else { return }
        save() // persist the program alongside applying it

        if replaceSchedule {
            profile.weeklySchedule.removeAll()
        }

        var applied = 0
        for entry in entries where routinesByID[entry.routineID] != nil {
            profile.weeklySchedule[entry.day] = entry.routineID
            applied += 1
        }

        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        statusMessage = "Scheduled \(applied) day\(applied == 1 ? "" : "s"). Check the planner or the Workout tab."
    }
}
