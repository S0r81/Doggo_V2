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
    
    // MARK: - "Ghost" Value Query
    // Fetches completed sets for this exercise from *other* sessions, sorted by date (newest first)
    @Query private var history: [WorkoutSet]
    
    // Data for AI Context
    @Query var profiles: [UserProfile]
    
    // UI State
    @State private var showWeightPicker = false
    @State private var showRepsPicker = false
    
    // AI State
    @State private var isSuggesting = false
    @State private var suggestionNote: String?
    
    init(set: WorkoutSet, index: Int, onComplete: @escaping () -> Void, container: AppContainer) {
        self.set = set
        self.index = index
        self.onComplete = onComplete
        self.container = container
        
        let exerciseID = set.exercise?.id
        let currentSessionID = set.workoutSession?.id
        
        // Initialize Query: Find completed sets for this exercise, excluding the current session
        self._history = Query(
            filter: #Predicate<WorkoutSet> {
                $0.exercise?.id == exerciseID &&
                $0.isCompleted == true &&
                $0.workoutSession?.id != currentSessionID
            },
            sort: [SortDescriptor(\WorkoutSet.workoutSession?.date, order: .reverse)]
        )
    }
    
    // Logic to find the specific "Ghost" values (e.g. Set 1 vs Set 1)
    private var ghostValues: (weight: String, reps: String) {
        // 1. Get the most recent session ID from history
        guard let lastSet = history.first, let lastSessionID = lastSet.workoutSession?.id else {
            return ("-", "-")
        }
        
        // 2. Filter to only that session
        let lastSessionSets = history.filter { $0.workoutSession?.id == lastSessionID }
        let sortedSets = lastSessionSets.sorted { $0.orderIndex < $1.orderIndex }
        
        // 3. Find the matching set index (or fallback to the last one)
        if index - 1 < sortedSets.count {
            let match = sortedSets[index - 1]
            return (String(Int(match.weight)), String(match.reps))
        } else if let last = sortedSets.last {
            return (String(Int(last.weight)), String(last.reps))
        }
        
        return ("-", "-")
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
                }
                
                // 3. Weight Input with Ghost Value
                HStack(spacing: 0) {
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
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .sheet(isPresented: $showWeightPicker) {
                        weightPickerSheet
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
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
                
                // 4. Reps Input with Ghost Value
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
                                .font(.title3).fontWeight(.bold).foregroundStyle(.blue)
                        }
                        Text("reps").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showRepsPicker) {
                    repsPickerSheet
                }
                
                // 5. Completion Checkbox
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    withAnimation(.snappy) { set.isCompleted.toggle() }
                    if set.isCompleted { onComplete() }
                }) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundStyle(set.isCompleted ? .green : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
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
                let apiClient = container.geminiClient
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
