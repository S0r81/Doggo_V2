//
//  PeptideEditorView.swift
//  Doggo_V2
//
//  Create or edit a peptide profile and its schedule. All persistence goes
//  through the @ModelActor PeptideRepository (value-in/identifier-out), so the
//  form never inserts models into a relationship across contexts.
//

import SwiftUI
import SwiftData

struct PeptideEditorView: View {
    let container: AppContainer
    /// nil = create a new profile.
    var profileToEdit: PeptideProfile?
    /// Called after a successful save so the caller can resync reminders.
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    // Profile
    @State private var name = ""
    @State private var totalMg: Double = 5
    @State private var waterMl: Double = 2
    @State private var vialUnit: PeptideMeasurementUnit = .mg

    // Schedule
    @State private var targetDoseMcg: Double = 250
    @State private var doseUnit: PeptideMeasurementUnit = .mcg
    @State private var frequency: PeptideFrequency = .daily
    @State private var selectedWeekdays: Set<String> = []
    @State private var daysOn = 5
    @State private var daysOff = 2
    @State private var anchorDate = Date()
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var remindersEnabled = true

    @State private var isSaving = false

    private var accent: Color { Color.accent(for: userTheme) }

    private var liveCalc: PeptideCalculation {
        PeptideCalculator.calculate(
            vialAmount: totalMg,
            vialUnit: vialUnit,
            waterAddedMl: waterMl,
            doseAmount: targetDoseMcg,
            doseUnit: doseUnit
        )
    }

    /// IU vials must be dosed in IU; switching the vial unit keeps the dose
    /// unit in a compatible family.
    private var vialUnitBinding: Binding<PeptideMeasurementUnit> {
        Binding(
            get: { vialUnit },
            set: { newValue in
                vialUnit = newValue
                if newValue == .iu { doseUnit = .iu }
                else if doseUnit == .iu { doseUnit = .mcg }
            }
        )
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && totalMg > 0 && waterMl > 0 && targetDoseMcg > 0
            && liveCalc.unitsCompatible
            && (frequency != .specificDays || !selectedWeekdays.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                vialSection
                doseSection
                scheduleSection
                reminderSection
            }
            .navigationTitle(profileToEdit == nil ? "New Peptide" : "Edit Peptide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                        .bold()
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    // MARK: - Sections

    private var vialSection: some View {
        Section("Peptide") {
            TextField("Name (e.g. BPC-157)", text: $name)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            valueRow("Vial Amount", value: $totalMg) {
                unitMenu(vialUnitBinding, options: [.mg, .iu])
            }
            valueRow("Water Added", value: $waterMl) {
                Text("ml")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .leading)
                    .fixedSize()
            }
        }
    }

    private var doseSection: some View {
        Section {
            valueRow("Target Dose", value: $targetDoseMcg) {
                unitMenu($doseUnit, options: [.mcg, .mg, .iu])
            }
        } header: {
            Text("Dose")
        } footer: {
            if liveCalc.isValid {
                Label("Pull to \(liveCalc.roundedUnits) units · \(liveCalc.dosesPerVial) doses per vial",
                      systemImage: "syringe")
                    .foregroundStyle(accent)
            } else if totalMg > 0 && waterMl > 0 && targetDoseMcg > 0 && !liveCalc.unitsCompatible {
                Label("\(vialUnit.label.uppercased()) vials can only be dosed in the same unit family.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Frequency", selection: $frequency) {
                ForEach(PeptideFrequency.allCases) { freq in
                    Label(freq.label, systemImage: freq.icon).tag(freq)
                }
            }

            switch frequency {
            case .daily:
                EmptyView()

            case .specificDays:
                weekdayPicker

            case .cycle:
                Stepper("Days On: \(daysOn)", value: $daysOn, in: 1...30)
                Stepper("Days Off: \(daysOff)", value: $daysOff, in: 0...30)
                DatePicker("Cycle Start", selection: $anchorDate, displayedComponents: .date)
            }
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Inject on")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Two rows of day chips.
            FlowChips(items: weekdayNames, selected: selectedWeekdays, accent: accent) { day in
                if selectedWeekdays.contains(day) { selectedWeekdays.remove(day) }
                else { selectedWeekdays.insert(day) }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var reminderSection: some View {
        Section {
            Toggle("Dose Reminders", isOn: $remindersEnabled)
            if remindersEnabled {
                DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
            }

            if profileToEdit != nil {
                Button(role: .destructive) {
                    deleteProfile()
                } label: {
                    Label("Delete Peptide", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        } footer: {
            Text("Reminders fire as a local notification at the chosen time on each dose day.")
        }
    }

    private func valueRow<Trailing: View>(
        _ title: String,
        value: Binding<Double>,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
            // Number expands and right-aligns so it sits flush against its unit.
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            // Unit holds its natural width — never squished by the field.
            trailing()
                .layoutPriority(1)
        }
    }

    private func unitMenu(_ selection: Binding<PeptideMeasurementUnit>, options: [PeptideMeasurementUnit]) -> some View {
        Picker("", selection: selection) {
            ForEach(options) { Text($0.label).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(accent)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard let profile = profileToEdit else { return }
        name = profile.name
        totalMg = profile.totalMg
        waterMl = profile.waterAddedMl
        vialUnit = profile.vialUnit

        if let schedule = profile.schedule {
            targetDoseMcg = schedule.targetDoseMcg
            doseUnit = schedule.doseUnit
            frequency = schedule.frequency
            selectedWeekdays = Set(schedule.specificWeekdays)
            daysOn = schedule.daysOn
            daysOff = schedule.daysOff
            anchorDate = schedule.anchorDate
            reminderTime = Calendar.current.date(
                bySettingHour: schedule.reminderHour,
                minute: schedule.reminderMinute,
                second: 0,
                of: Date()
            ) ?? reminderTime
            remindersEnabled = schedule.remindersEnabled
        }
    }

    private func save() {
        isSaving = true
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let config = PeptideScheduleConfig(
            frequency: frequency,
            targetDoseMcg: targetDoseMcg,
            doseUnit: doseUnit,
            specificWeekdays: weekdayNames.filter { selectedWeekdays.contains($0) }, // keep canonical order
            daysOn: daysOn,
            daysOff: daysOff,
            anchorDate: anchorDate,
            reminderHour: comps.hour ?? 8,
            reminderMinute: comps.minute ?? 0,
            remindersEnabled: remindersEnabled
        )
        let repo = container.peptideRepository
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let mg = totalMg, water = waterMl
        let unit = vialUnit
        let existingID = profileToEdit?.persistentModelID

        Task {
            do {
                let id: PersistentIdentifier
                if let existingID {
                    try await repo.updateReconstitution(profileID: existingID, name: cleanName, totalMg: mg, waterAddedMl: water, vialUnit: unit)
                    id = existingID
                } else {
                    id = try await repo.createProfile(name: cleanName, totalMg: mg, waterAddedMl: water, vialUnit: unit)
                }
                try await repo.setSchedule(profileID: id, config: config)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func deleteProfile() {
        guard let id = profileToEdit?.persistentModelID else { return }
        let repo = container.peptideRepository
        Task {
            try? await repo.deleteProfile(id: id)
            await MainActor.run {
                HapticManager.shared.impact(style: .medium)
                onSaved()
                dismiss()
            }
        }
    }
}

// MARK: - Day Chips

/// Wrapping row of selectable chips. Used for weekday selection.
struct FlowChips: View {
    let items: [String]
    let selected: Set<String>
    var accent: Color
    let onTap: (String) -> Void

    var body: some View {
        // Two fixed rows keeps it simple and avoids a layout dependency.
        let columns = [GridItem(.adaptive(minimum: 64), spacing: Spacing.sm)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
            ForEach(items, id: \.self) { item in
                let isOn = selected.contains(item)
                Button {
                    onTap(item)
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text(item.prefix(3))
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(isOn ? accent : Color.primary.opacity(0.06),
                                    in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
