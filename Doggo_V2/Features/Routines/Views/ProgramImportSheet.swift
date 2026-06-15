//
//  ProgramImportSheet.swift
//  Doggo_V2
//
//  Half-sheet preview shown when a doggov2:// program link is opened. Lets the
//  user see what they're about to import before it touches the database, then
//  inserts it via the background ProgramImportRepository on confirmation.
//

import SwiftUI
import SwiftData

struct ProgramImportSheet: View {
    let shared: SharedProgram
    /// The app's container — used to spin up the background import actor.
    let container: ModelContainer

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    @State private var isImporting = false
    @State private var result: ProgramImportSummary?
    @State private var errorMessage: String?

    private var accent: Color { Color.accent(for: userTheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    headerCard
                    daysList
                    importButton
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Import Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Program Imported", isPresented: Binding(
                get: { result != nil },
                set: { if !$0 { result = nil } }
            )) {
                Button("Done") {
                    result = nil
                    dismiss()
                }
            } message: {
                if let result {
                    Text("Added “\(result.programName)” with \(result.routinesCreated) routines\(result.exercisesCreated > 0 ? " and \(result.exercisesCreated) new exercises" : ""). Find it under Your Programs.")
                }
            }
            .alert("Import Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 44))
                .foregroundStyle(accent)

            Text(shared.name.isEmpty ? "Shared Program" : shared.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !shared.details.isEmpty {
                Text(shared.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Spacing.sm) {
                summaryChip("\(shared.dayCount) Days/Week", icon: "calendar")
                summaryChip("\(shared.exerciseCount) Exercises", icon: "dumbbell")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .cardSurface(shadowed: true)
    }

    private func summaryChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(accent.opacity(0.12), in: Capsule())
            .foregroundStyle(accent)
    }

    // MARK: - Days

    private var daysList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(shared.days.enumerated()), id: \.offset) { _, day in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(day.routineName)
                            .font(.headline)
                        Spacer()
                        if let weekday = day.weekday, !weekday.isEmpty {
                            Text(String(weekday.prefix(3)))
                                .font(.caption.bold())
                                .foregroundStyle(accent)
                        }
                    }
                    Text(day.items.map(\.name).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .cardSurface()
            }
        }
    }

    // MARK: - Import

    private var importButton: some View {
        Button(action: performImport) {
            HStack(spacing: Spacing.sm) {
                if isImporting { ProgressView().tint(.white) }
                Text(isImporting ? "Importing…" : "Import to Your Programs")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .disabled(isImporting)
    }

    private func performImport() {
        isImporting = true
        let repository = ProgramImportRepository(modelContainer: container)
        let program = shared
        Task {
            do {
                let summary = try await repository.importShared(program)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isImporting = false
                    result = summary
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
