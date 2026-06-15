//
//  AIProgramGeneratorView.swift
//  Doggo_V2
//
//  Ask the selected AI provider for a complete multi-day program, then hold
//  the result as a fully editable draft — rename the program or any exercise,
//  tweak sets/reps, swipe-delete rows — before committing it to the database
//  as a CustomProgram under "Your Programs".
//
//  Nothing touches SwiftData until Save: edited names flow through the same
//  sanitize → exact match → canonical-key match → create pipeline in
//  GenerateProgramUseCase.save(), so a row renamed to a brand-new movement
//  gets its Exercise created automatically.
//

import SwiftUI
import SwiftData

struct AIProgramGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appContainer) private var container
    @Query private var profiles: [UserProfile]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var daysPerWeek = 4
    @State private var focus = ""
    @State private var isGenerating = false
    @State private var draftProgram: AIGeneratedProgram?
    @State private var errorMessage: String?
    @State private var saveResult: GenerateProgramUseCase.SaveResult?
    @State private var generationTask: Task<Void, Never>?

    private var useCase: GenerateProgramUseCase {
        GenerateProgramUseCase(client: container?.aiClient ?? AIClientRouter())
    }

    /// Canonical keys of everything already in the library, so the draft can
    /// flag which exercises a save would create. Recomputed as the user
    /// types, so renaming a row updates its NEW badge live.
    private var existingKeys: Set<String> {
        Set(exercises.map { GenerateProgramUseCase.canonicalKey($0.name) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    AILoadingView(
                        title: "Building your program…",
                        subtitle: "Designing \(daysPerWeek) days around your profile",
                        onCancel: cancelGeneration
                    )
                } else if let draftBinding = Binding($draftProgram) {
                    draftEditor(draftBinding)
                } else {
                    requestForm
                }
            }
            .navigationTitle(draftProgram == nil ? "AI Program" : "Review & Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        cancelGeneration()
                        dismiss()
                    }
                }
            }
            .alert("Generation Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Program Saved", isPresented: Binding(
                get: { saveResult != nil },
                set: { if !$0 { saveResult = nil } }
            )) {
                Button("Done") {
                    saveResult = nil
                    dismiss()
                }
            } message: {
                if let result = saveResult {
                    Text("Added \(result.routinesCreated) routines\(result.exercisesCreated > 0 ? " and \(result.exercisesCreated) new exercises" : ""). Find it under Your Programs.")
                }
            }
        }
    }

    // MARK: - Request Form

    private var requestForm: some View {
        Form {
            Section {
                Picker("Days per week", selection: $daysPerWeek) {
                    ForEach(2...6, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Training Days")
            }

            Section {
                TextField("e.g. Hypertrophy, big bench, bad knees…", text: $focus, axis: .vertical)
                    .lineLimit(1...3)
            } header: {
                Text("Focus (Optional)")
            } footer: {
                Text("Leave blank and the coach picks the best split for your profile.")
            }

            Section {
                Button {
                    generate()
                } label: {
                    Label("Generate Program", systemImage: "wand.and.stars")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.purple)
                .foregroundStyle(.white)
            } footer: {
                Text("Uses your selected AI provider from Settings.")
            }
        }
    }

    // MARK: - Editable Draft

    private func draftEditor(_ program: Binding<AIGeneratedProgram>) -> some View {
        List {
            Section {
                TextField("Program Name", text: program.name)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                TextField("Description", text: program.description, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...3)
            } header: {
                Text("Program")
            } footer: {
                Text("Everything below is editable. Swipe left on an exercise to remove it.")
            }

            ForEach(program.days) { $day in
                Section {
                    ForEach($day.exercises) { $plan in
                        exerciseRow($plan)
                    }
                    .onDelete { offsets in
                        $day.wrappedValue.exercises.remove(atOffsets: offsets)
                    }

                    if day.exercises.isEmpty {
                        Text("All exercises removed — this day won't be saved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    TextField("Day Name", text: $day.name)
                        .textInputAutocapitalization(.words)
                }
            }

            Section {
                Button {
                    saveDraft(program.wrappedValue)
                } label: {
                    Label("Save to Your Programs", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(canSave(program.wrappedValue) ? Color.purple : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .disabled(!canSave(program.wrappedValue))

                Button {
                    draftProgram = nil
                } label: {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Saving creates the routines and any new exercises, and bundles them as a program you can apply to your weekly schedule.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func exerciseRow(_ plan: Binding<AIGeneratedProgram.ExercisePlan>) -> some View {
        let isCardio = plan.wrappedValue.isCardio

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                if isCardio {
                    Image(systemName: plan.wrappedValue.resolvedTracking.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Exercise Name", text: plan.name)
                    .font(.subheadline.weight(.medium))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if !existingKeys.contains(GenerateProgramUseCase.canonicalKey(plan.wrappedValue.name)) {
                    Text("NEW")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: Spacing.md) {
                if !isCardio {
                    numberField("Sets", value: plan.sets)
                    Text("×")
                        .foregroundStyle(.tertiary)
                }
                numberField(isCardio ? "Min" : "Reps", value: plan.reps)

                Spacer()

                if let note = plan.wrappedValue.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func numberField(_ label: String, value: Binding<Int>) -> some View {
        HStack(spacing: Spacing.xs) {
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// A draft is saveable once it still has a name and at least one
    /// non-empty day — the use case skips emptied days on its own.
    private func canSave(_ program: AIGeneratedProgram) -> Bool {
        let hasName = !program.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasExercises = program.days.contains { day in
            day.exercises.contains {
                !GenerateProgramUseCase.sanitizeExerciseName($0.name).isEmpty
            }
        }
        return hasName && hasExercises
    }

    // MARK: - Actions

    private func generate() {
        isGenerating = true
        let useCase = self.useCase
        let days = daysPerWeek
        let focusText = focus
        let profile = profiles.first
        let available = exercises

        generationTask = Task {
            do {
                let program = try await useCase.generate(
                    daysPerWeek: days,
                    focus: focusText,
                    profile: profile,
                    availableExercises: available
                )
                guard !Task.isCancelled else { return }
                draftProgram = program
                HapticManager.shared.notification(type: .success)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    private func saveDraft(_ program: AIGeneratedProgram) {
        let result = useCase.save(program, context: modelContext)
        HapticManager.shared.notification(type: .success)
        saveResult = result
    }
}
