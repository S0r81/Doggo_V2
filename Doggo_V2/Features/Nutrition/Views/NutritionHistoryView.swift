//
//  NutritionHistoryView.swift
//  Doggo_V2
//
//  The full weekly check-in history. Swipe to delete (cascade-safe, main
//  context); tap a row to correct its weight via NutritionRepository, which
//  re-derives the week's loss and syncs the Progress-tab BodyMeasurement.
//

import SwiftUI
import SwiftData

struct NutritionHistoryView: View {
    let profile: NutritionProfile
    let container: ModelContainer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    @State private var editingCheckIn: NutritionCheckIn?
    @State private var editWeightInput: Double = 0
    @State private var errorMessage: String?

    private var checkIns: [NutritionCheckIn] {
        profile.checkIns.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if checkIns.isEmpty {
                    ContentUnavailableView(
                        "No Check-Ins Yet",
                        systemImage: "calendar",
                        description: Text("Your weekly weigh-ins will appear here.")
                    )
                } else {
                    List {
                        ForEach(checkIns) { checkIn in
                            Button {
                                editWeightInput = displayWeight(checkIn.rollingAverageWeight)
                                editingCheckIn = checkIn
                            } label: {
                                row(checkIn)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Check-In History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Correct Weight", isPresented: Binding(
                get: { editingCheckIn != nil },
                set: { if !$0 { editingCheckIn = nil } }
            )) {
                TextField("Weight", value: $editWeightInput, format: .number)
                    .keyboardType(.decimalPad)
                Button("Save") { saveEdit() }
                Button("Cancel", role: .cancel) { editingCheckIn = nil }
            } message: {
                Text("Update the rolling-average weight for this week.")
            }
            .alert("Couldn’t Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func row(_ checkIn: NutritionCheckIn) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if checkIn.wasMacroAdjustmentApplied {
                    Label("Macros cut", systemImage: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f %@", displayWeight(checkIn.rollingAverageWeight), unitSystem.weightLabel))
                    .font(.headline).monospacedDigit()
                let lost = displayWeight(checkIn.actualWeightLost)
                Text(String(format: "%@%.1f %@", lost >= 0 ? "−" : "+", abs(lost), unitSystem.weightLabel))
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(lost >= 0 ? .green : .secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func displayWeight(_ kg: Double) -> Double {
        unitSystem == .imperial ? kg * UnitSystem.poundsPerKilogram : kg
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(checkIns[index])   // main-context model; safe
        }
        modelContext.saveLogging()
        HapticManager.shared.impact(style: .medium)
    }

    private func saveEdit() {
        guard let checkIn = editingCheckIn else { return }
        let newKg = unitSystem == .imperial ? editWeightInput / UnitSystem.poundsPerKilogram : editWeightInput
        guard newKg > 25 else { editingCheckIn = nil; return }
        let id = checkIn.persistentModelID
        let repository = NutritionRepository(modelContainer: container)
        editingCheckIn = nil
        Task {
            do {
                try await repository.updateHistoricalCheckIn(checkInID: id, newWeight: newKg)
                await MainActor.run { HapticManager.shared.notification(type: .success) }
            } catch {
                await MainActor.run {
                    HapticManager.shared.notification(type: .error)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
