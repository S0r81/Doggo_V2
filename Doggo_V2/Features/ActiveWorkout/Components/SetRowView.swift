//
//  SetRowView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var set: WorkoutSet
    var index: Int
    var onComplete: () -> Void
    let container: AppContainer
    // Keyboard focus is owned by ActiveWorkoutView so a single "Done" toolbar
    // can serve every row.
    var focus: FocusState<WorkoutSetField?>.Binding

    // Data for AI Context
    @Query var profiles: [UserProfile]

    // MARK: - "Ghost" Values
    // Loaded once on appear instead of a live @Query per row — with one query per set
    // row, large histories made the workout list increasingly expensive to render.
    @State private var lastSessionSets: [WorkoutSet] = []

    // UI State
    @AppStorage("useKeypadForSets") private var useKeypadForSets = false
    @State private var showWeightPicker = false
    @State private var showRepsPicker = false

    // AI State
    @State private var isSuggesting = false
    @State private var suggestionNote: String?

    // Logic to find the specific "Ghost" values (e.g. Set 1 vs Set 1)
    private var ghostValues: (weight: String, reps: String) {
        guard let ghost = ghostSet else { return ("-", "-") }
        return (String(Int(ghost.weight)), String(ghost.reps))
    }

    /// The matching set from the last session (same index, or its final set).
    private var ghostSet: WorkoutSet? {
        let sortedSets = lastSessionSets.sorted { $0.orderIndex < $1.orderIndex }
        if index - 1 < sortedSets.count {
            return sortedSets[index - 1]
        }
        return sortedSets.last
    }

    private func loadGhostValues() {
        guard lastSessionSets.isEmpty else { return }

        let exerciseID = set.exercise?.id
        let currentSessionID = set.workoutSession?.id

        // Completed sets for this exercise from *other* sessions, newest session first
        var descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> {
                $0.exercise?.id == exerciseID &&
                $0.isCompleted == true &&
                $0.workoutSession?.id != currentSessionID
            },
            sortBy: [SortDescriptor(\WorkoutSet.workoutSession?.date, order: .reverse)]
        )
        descriptor.fetchLimit = 30

        guard let recent = try? modelContext.fetch(descriptor),
              let lastSessionID = recent.first?.workoutSession?.id else { return }

        lastSessionSets = recent.filter { $0.workoutSession?.id == lastSessionID }
    }
    
    // Range Logic
    var weightOptions: [Double] {
        if set.unit == "kg" {
            return Array(stride(from: 0, through: 300, by: 1.0))
        } else {
            return Array(stride(from: 0, through: 600, by: 2.5))
        }
    }
    let repsOptions: [Int] = Array(0...100)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 1. Set Number
                Text("\(index)")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                
                // 2. Magic Wand
                if isSuggesting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 24, height: 24)
                } else {
                    Button(action: { getSmartSuggestion() }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.purple)
                            .frame(width: 24, height: 24)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Get AI weight suggestion")
                }
                
                // 3. Weight Input with Ghost Value
                HStack(spacing: 0) {
                    if useKeypadForSets {
                        TextField("Last: \(ghostValues.weight)", value: Binding(
                            get: { set.weight == 0 ? nil : set.weight },
                            set: { set.weight = $0 ?? 0 }
                        ), format: .number)
                        .focused(focus, equals: .weight(set.id))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(set.weight == 0 ? .caption : .title3)
                        .fontWeight(.bold)
                        .foregroundStyle(set.weight == 0 ? .secondary.opacity(0.6) : Color.accentColor)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button(action: { showWeightPicker = true }) {
                            if set.weight == 0 {
                                // SHOW GHOST VALUE
                                Text("Last: \(ghostValues.weight)")
                                    .font(.caption) // Smaller font for ghost
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("\(set.weight, format: .number)")
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .sheet(isPresented: $showWeightPicker) {
                            weightPickerSheet
                        }
                    }
                    
                    Menu {
                        Button("lbs") { set.unit = "lbs" }
                        Button("kg") { set.unit = "kg" }
                    } label: {
                        Text(set.unit)
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1)).cornerRadius(4)
                    }
                    .padding(.trailing, 6)
                }
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
                
                // 4. Reps Input with Ghost Value
                if useKeypadForSets {
                    VStack(spacing: 2) {
                        TextField("Last: \(ghostValues.reps)", value: Binding(
                            get: { set.reps == 0 ? nil : set.reps },
                            set: { set.reps = $0 ?? 0 }
                        ), format: .number)
                        .focused(focus, equals: .reps(set.id))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(set.reps == 0 ? .caption : .title3)
                        .fontWeight(.bold)
                        .foregroundStyle(set.reps == 0 ? .secondary.opacity(0.6) : Color.accentColor)
                        
                        Text("reps").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button(action: { showRepsPicker = true }) {
                        VStack(spacing: 2) {
                            if set.reps == 0 {
                                // SHOW GHOST VALUE
                                Text("Last: \(ghostValues.reps)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary.opacity(0.6))
                            } else {
                                Text("\(set.reps)")
                                    .font(.title3).fontWeight(.bold).foregroundStyle(Color.accentColor)
                            }
                            Text("reps").font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 60)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showRepsPicker) {
                        repsPickerSheet
                    }
                }
                
                // 5. Completion Checkbox
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    // One-tap "same as last time": completing an untouched set
                    // adopts the ghost values instead of logging 0 × 0.
                    if !set.isCompleted, set.weight == 0, set.reps == 0,
                       let ghost = ghostSet, ghost.weight > 0 || ghost.reps > 0 {
                        set.weight = ghost.weight
                        set.reps = ghost.reps
                    }
                    withAnimation(.snappy) { set.isCompleted.toggle() }
                    if set.isCompleted { onComplete() }
                }) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(set.isCompleted ? .green : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set.isCompleted ? "Set \(index) completed" : "Mark set \(index) complete")
            }
            .padding(.vertical, 4)
            
            // Suggestion Note (Toast)
            if let note = suggestionNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 50)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .onAppear { loadGhostValues() }
    }
    
    // MARK: - Picker Sheets
    var weightPickerSheet: some View {
        VStack {
            Text("Select Weight (\(set.unit))").font(.headline).padding(.top)
            Picker("Weight", selection: $set.weight) {
                ForEach(weightOptions, id: \.self) { w in
                    Text("\(w, format: .number)").tag(w)
                }
            }
            .pickerStyle(.wheel).labelsHidden()
        }
        .presentationDetents([.fraction(0.3)]).presentationDragIndicator(.visible)
    }
    
    var repsPickerSheet: some View {
        VStack {
            Text("Select Reps").font(.headline).padding(.top)
            Picker("Reps", selection: $set.reps) {
                ForEach(repsOptions, id: \.self) { r in
                    Text("\(r) reps").tag(r)
                }
            }
            .pickerStyle(.wheel).labelsHidden()
        }
        .presentationDetents([.fraction(0.3)]).presentationDragIndicator(.visible)
    }
    
    // MARK: - AI Logic
    private func getSmartSuggestion() {
        guard let exercise = set.exercise else { return }
        
        isSuggesting = true
        suggestionNote = nil
        
        Task {
            // 1. Fetch Context (Previous Best)
            var historyData: [HistoryContext] = []
            
            // Simple logic: Find the last best set for this exercise
            // (In a real app, you might want to move this context logic to a ViewModel/Service)
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            if let recentSessions = try? modelContext.fetch(descriptor) {
                for session in recentSessions.prefix(5) {
                    let sets = session.sets.filter { $0.exercise?.id == exercise.id }
                    if let best = sets.max(by: { $0.weight < $1.weight }) {
                        historyData.append(HistoryContext(date: session.date, weight: best.weight, reps: best.reps))
                    }
                }
            }
            
            // 2. Call Gemini
            do {
                let apiClient = container.aiClient
                let prompt = GeminiPromptBuilder.buildSetSuggestionPrompt(
                    exerciseName: exercise.name,
                    history: historyData,
                    goal: profiles.first?.fitnessGoal ?? "General Fitness"
                )
                let response = try await apiClient.sendRequest(prompt: prompt)
                let suggestion = try GeminiResponseParser.parseSetSuggestion(response)
                
                await MainActor.run {
                    withAnimation {
                        set.weight = suggestion.weight
                        set.reps = suggestion.reps
                        suggestionNote = "✨ Coach: \(suggestion.reasoning)"
                        isSuggesting = false
                    }
                    HapticManager.shared.notification(type: .success)
                }
            } catch {
                await MainActor.run {
                    suggestionNote = "⚠️ Couldn't reach coach."
                    isSuggesting = false
                }
            }
        }
    }
}
