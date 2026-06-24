import SwiftUI
import SwiftData

/// 180-day cutoff for RoutineGeneratorView's history fetch, computed once at
/// first use. A file-scope constant (not a static member) so the @Query
/// `#Predicate` can capture it by value.
private let routineGenHistoryCutoff: Date =
    Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? .distantPast

struct RoutineGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Data Sources
    // Bounded to the last 180 days: the AI generation prompt only consumes
    // history.prefix(30), so this window cannot change the output, but it avoids
    // loading the full workout history just to build context on this screen.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.date >= routineGenHistoryCutoff },
        sort: \WorkoutSession.date, order: .reverse
    ) var history: [WorkoutSession]
    @Query var routines: [Routine]
    @Query(sort: \Exercise.name) var exercises: [Exercise] // Sorted for the swap picker
    @Query(sort: \AIGeneratedRoutine.date, order: .reverse) var savedGenerations: [AIGeneratedRoutine]
    @Query var profiles: [UserProfile]

    @AppStorage("cachedCoachAdvice") private var cachedAdvice: String = ""
    
    var initialSplit: String?
    
    // Options
    let splitOptions = ["Push", "Pull", "Legs", "Upper Body", "Lower Body", "Full Body", "Cardio", "Specific Muscle"]
    @State private var selectedSplit: String = "Push"
    
    let muscleOptions = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Abs", "Glutes", "Quads", "Hamstrings"]
    @State private var selectedMuscle: String = "Chest"
    
    // Constraints
    @State private var limitedEquipment: Bool = false
    @State private var includeCardio: Bool = false
    @State private var cardioDuration: Double = 20 // Default 20 mins
    @State private var duration: Double = 60
    @State private var exerciseCount: Int = 5
    
    // Outputs
    @State private var isGenerating = false
    @State private var generatedRoutineName: String = ""
    @State private var generatedCandidates: [GenItem] = []
    @State private var showHistorySheet = false
    @State private var errorMessage: String?
    
    // Swap Logic
    @State private var showSwapSheet = false
    @State private var itemIDToSwap: UUID?
    
    struct GenItem: Identifiable {
        let id = UUID()
        var name: String // Mutable for swapping
        let sets: Int
        let reps: String
        let note: String
        var isSelected: Bool = true
    }
    
    let container: AppContainer

    private var loadingSubtitle: String {
        var parts: [String] = []
        if let profile = profiles.first, profile.useCoachForRoutine, !cachedAdvice.isEmpty {
            parts.append("Applying coach's strategy")
        }
        if includeCardio || selectedSplit == "Cardio" {
            parts.append("Analyzing cardio history")
        }
        return parts.isEmpty ? "Tailored to your history and goals" : parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isGenerating {
                    AILoadingView(
                        title: "Constructing Routine…",
                        subtitle: loadingSubtitle
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                else if generatedCandidates.isEmpty {
                    inputForm
                }
                else {
                    selectionList
                }
            }
            .navigationTitle("AI Builder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if generatedCandidates.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showHistorySheet = true }) { Image(systemName: "clock.arrow.circlepath") }
                            .accessibilityLabel("Past generated routines")
                    }
                }
            }
            .sheet(isPresented: $showHistorySheet) {
                HistorySheet(savedGenerations: savedGenerations) { selectedDraft in loadDraft(selectedDraft) }
            }
            // SWAP SHEET
            .sheet(isPresented: $showSwapSheet) {
                ExerciseSwapPicker(exercises: exercises) { newExercise in
                    performSwap(newExercise: newExercise)
                }
            }
            // Smart Defaults
            .onChange(of: selectedSplit) { _, newValue in
                if newValue == "Cardio" {
                    exerciseCount = 1
                    includeCardio = false
                } else {
                    exerciseCount = 5
                }
            }
            .onChange(of: includeCardio) { _, newValue in
                if newValue && selectedSplit != "Cardio" { exerciseCount += 1 }
                else if !newValue && selectedSplit != "Cardio" && exerciseCount > 1 { exerciseCount -= 1 }
            }
            .onAppear {
                if let focus = initialSplit, !focus.isEmpty {
                    let clean = focus.trimmingCharacters(in: .whitespacesAndNewlines)
                    if splitOptions.contains(clean) { selectedSplit = clean }
                    else if let pm = splitOptions.first(where: { clean.localizedCaseInsensitiveContains($0) }) { selectedSplit = pm }
                    else if let mm = muscleOptions.first(where: { clean.localizedCaseInsensitiveContains($0) }) { selectedSplit = "Specific Muscle"; selectedMuscle = mm }
                }
            }
        }
    }
    
    var inputForm: some View {
        Form {
            Section("Workout Focus") {
                Picker("Split Type", selection: $selectedSplit) {
                    ForEach(splitOptions, id: \.self) { option in Text(option).tag(option) }
                }.pickerStyle(.menu)
                
                if selectedSplit == "Specific Muscle" {
                    Picker("Target Muscle", selection: $selectedMuscle) {
                        ForEach(muscleOptions, id: \.self) { muscle in Text(muscle).tag(muscle) }
                    }.pickerStyle(.wheel).frame(height: 100)
                }
            }
            
            Section("Constraints") {
                HStack {
                    Image(systemName: "clock").foregroundStyle(.blue)
                    Slider(value: $duration, in: 15...120, step: 15)
                    Text("\(Int(duration)) min").monospacedDigit()
                }
                
                Stepper(value: $exerciseCount, in: 1...12) {
                    HStack {
                        Image(systemName: "list.number").foregroundStyle(.purple)
                        Text("Exercises: \(exerciseCount)")
                    }
                }
                
                // CARDIO TOGGLE & DURATION
                if selectedSplit != "Cardio" {
                    Toggle(isOn: $includeCardio) {
                        Label("Include Cardio", systemImage: "figure.run")
                    }
                    
                    if includeCardio {
                        HStack {
                            Text("Cardio Duration")
                            Spacer()
                            Text("\(Int(cardioDuration)) min")
                                .foregroundStyle(.teal).bold()
                        }
                        Slider(value: $cardioDuration, in: 5...60, step: 5)
                            .tint(.teal)
                    }
                }
                
                Toggle(isOn: $limitedEquipment) {
                    Label("Limited Equipment", systemImage: "dumbbell")
                    Text("Dumbbells/Bodyweight only").font(.caption).foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button(action: generate) {
                    Label("Generate Routine", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity).font(.headline)
                }.listRowBackground(Color.blue).foregroundStyle(.white)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let profile = profiles.first, profile.useCoachForRoutine, !cachedAdvice.isEmpty {
                        Text("💡 AI will adapt reps/sets based on your latest Coach Report.").foregroundStyle(.orange)
                    }
                }
            }
        }
    }
    
    var selectionList: some View {
        List {
            Section("Routine Name") {
                TextField("Name", text: $generatedRoutineName).font(.headline)
            }
            Section {
                ForEach($generatedCandidates) { $item in // Use binding for toggling
                    // We need to find the index to bind
                    if let index = generatedCandidates.firstIndex(where: { $0.id == item.id }) {
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: { generatedCandidates[index].isSelected.toggle() }) {
                                Image(systemName: generatedCandidates[index].isSelected ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundStyle(generatedCandidates[index].isSelected ? .blue : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                    .strikethrough(!item.isSelected)
                                    .opacity(item.isSelected ? 1.0 : 0.5)
                                
                                HStack {
                                    Text("\(item.sets) sets x \(item.reps)")
                                        .font(.caption).bold()
                                        .padding(4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                    
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                .opacity(item.isSelected ? 1.0 : 0.5)
                            }
                            
                            Spacer()
                            
                            // SWAP BUTTON
                            Button(action: {
                                itemIDToSwap = item.id
                                showSwapSheet = true
                            }) {
                                Image(systemName: "arrow.2.squarepath")
                                    .foregroundStyle(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                                    .accessibilityLabel("Swap exercise")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: { Text("Select Exercises") }
            
            Button("Save Routine", action: saveRoutine)
                .buttonStyle(.borderedProminent)
                .disabled(generatedCandidates.filter{ $0.isSelected }.isEmpty)
        }
    }
    
    // MARK: - Logic
    
    func generate() {
        withAnimation { isGenerating = true }
        
        var finalFocus = selectedSplit
        if selectedSplit == "Specific Muscle" { finalFocus = "Target: \(selectedMuscle) Only" }
        if selectedSplit == "Cardio" { finalFocus = "Target: Cardio Only (No Strength)" }
        if limitedEquipment { finalFocus += " (Limited Equipment: Dumbbells/Bodyweight Only)" }
        
        let focusToSend = finalFocus
        let countToSend = exerciseCount
        
        var adviceToSend: String? = nil
        if let profile = profiles.first, profile.useCoachForRoutine {
            adviceToSend = cachedAdvice
        }
        
        Task {
            do {
                // NEW: Use split AI service
                let apiClient = container.aiClient
                let prompt = GeminiPromptBuilder.buildRoutinePrompt(
                    history: history,
                    availableExercises: exercises,
                    profile: profiles.first,
                    focus: focusToSend,
                    duration: Int(duration),
                    exerciseCount: countToSend,
                    includeCardio: includeCardio,
                    cardioDuration: Int(cardioDuration),
                    coachAdvice: adviceToSend
                )
                
                let rawResponse = try await apiClient.sendRequest(prompt: prompt)
                let (name, rawJSON, items) = try GeminiResponseParser.parseRoutine(rawResponse)
                
                await MainActor.run {
                    let draft = AIGeneratedRoutine(
                        focus: focusToSend,
                        duration: Int(duration),
                        routineName: name,
                        rawJSON: rawJSON
                    )
                    modelContext.insert(draft)
                    self.generatedRoutineName = name
                    self.generatedCandidates = items.map {
                        GenItem(name: $0.name, sets: $0.sets, reps: $0.reps, note: $0.note)
                    }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    func performSwap(newExercise: Exercise) {
        guard let id = itemIDToSwap, let index = generatedCandidates.firstIndex(where: { $0.id == id }) else { return }
        
        // Update the name
        generatedCandidates[index].name = newExercise.name
        showSwapSheet = false
    }
    
    // ... (Keep saveRoutine and loadDraft same as before) ...
    func saveRoutine() {
        let newRoutine = Routine(name: generatedRoutineName)
        modelContext.insert(newRoutine)
        let selectedItems = generatedCandidates.filter { $0.isSelected }
        for (index, item) in selectedItems.enumerated() {
            if let exerciseObj = exercises.first(where: { $0.name == item.name }) {
                let routineItem = RoutineItem(orderIndex: index, exercise: exerciseObj, note: item.note)
                routineItem.routine = newRoutine
                modelContext.insert(routineItem)
                let range = RepRange.parse(item.reps)
                for i in 0..<item.sets {
                    let template = RoutineSetTemplate(orderIndex: i, targetReps: range.lower, targetRepsUpper: range.upper)
                    template.routineItem = routineItem
                    modelContext.insert(template)
                }
            }
        }
        dismiss()
    }
    
    func loadDraft(_ draft: AIGeneratedRoutine) {
        showHistorySheet = false
        guard let data = draft.rawJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exercises = json["exercises"] as? [[String: Any]]
        else { return }
        self.generatedRoutineName = draft.routineName
        self.generatedCandidates = exercises.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            let sets = dict["sets"] as? Int ?? 3
            let reps = "\(dict["reps"] ?? "10")"
            let note = dict["note"] as? String ?? ""
            return GenItem(name: name, sets: sets, reps: reps, note: note)
        }
    }
}

// MARK: - Exercise Swap Picker Sheet
struct ExerciseSwapPicker: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button(action: {
                    onSelect(exercise)
                    dismiss()
                }) {
                    HStack {
                        Text(exercise.name).font(.headline)
                        Spacer()
                        Text(exercise.muscleGroup).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Swap Exercise")
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }
}

// (Keep HistorySheet struct)
struct HistorySheet: View {
    @Environment(\.dismiss) var dismiss
    let savedGenerations: [AIGeneratedRoutine]
    let onSelect: (AIGeneratedRoutine) -> Void
    var body: some View {
        NavigationStack {
            List(savedGenerations) { draft in
                Button(action: { onSelect(draft) }) {
                    VStack(alignment: .leading) {
                        Text(draft.routineName).font(.headline)
                        HStack {
                            Text(draft.focus).font(.caption).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
                            Text("\(draft.duration) min").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(draft.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.foregroundStyle(.primary)
            }
            .navigationTitle("Past Generations")
            .overlay { if savedGenerations.isEmpty { ContentUnavailableView("No History", systemImage: "clock") } }
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

