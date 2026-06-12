import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    
    @State private var isEditing = false
    @State private var showExerciseList = false
    @State private var showDurationPicker = false
    
    // Local state
    @State private var durationMinutes: Int = 0
    @State private var collapsedExercises: Set<UUID> = []
    
    // Delete confirmation
    @State private var exerciseToDelete: Exercise?
    @State private var showDeleteConfirmation = false
    
    // Local copy for ordering
    @State private var orderedExercises: [Exercise] = []
    
    var body: some View {
        List {
            sessionSummarySection
            sessionNotesSection
            
            // MARK: - EXERCISE SECTIONS
            ForEach(orderedExercises) { exercise in
                Section {
                    // 1. The Sets (Only show if expanded)
                    if !collapsedExercises.contains(exercise.id) {
                        let relevantSets = getSets(for: exercise)
                        
                        ForEach(relevantSets) { set in
                            HistorySetRowView(
                                set: set,
                                isEditing: isEditing,
                                exerciseType: exercise.type,
                                onDelete: { deleteSet(set) }
                            )
                        }
                    }
                    
                    // 2. Add Set Button (Only when editing)
                    if isEditing && !collapsedExercises.contains(exercise.id) {
                        Button {
                            addSet(to: exercise)
                        } label: {
                            Label("Add Set", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    // 3. The Section Header
                    ExerciseSectionHeader(
                        exercise: exercise,
                        summary: headerSummary(for: exercise),
                        isEditing: isEditing,
                        isCollapsed: collapsedExercises.contains(exercise.id),
                        onToggleCollapse: { toggleCollapse(for: exercise) },
                        onMoveUp: { moveExercise(exercise, direction: -1) },
                        onMoveDown: { moveExercise(exercise, direction: 1) },
                        onDelete: {
                            exerciseToDelete = exercise
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            
            // 4. Add Exercise Button at the bottom
            if isEditing {
                Section {
                    Button {
                        showExerciseList = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        // SMOOTH ANIMATION MAGIC:
        .animation(.default, value: collapsedExercises)
        .navigationTitle(isEditing ? "Editing..." : session.name)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .onAppear {
            durationMinutes = Int(session.duration / 60)
            refreshExercises()
        }
        .onChange(of: isEditing) { _, newValue in
            if newValue {
                refreshExercises()
                // Auto-expand all when editing starts for easier access
                collapsedExercises.removeAll()
            }
        }
        .onChange(of: session.sets.count) { _, _ in
            refreshExercises()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation { isEditing.toggle() }
                }
                .fontWeight(isEditing ? .bold : .regular)
            }
            ToolbarItem(placement: .keyboard) {
                HStack { Spacer(); Button("Done") { hideKeyboard() } }
            }
        }
        .sheet(isPresented: $showExerciseList) {
            ExerciseListView(currentSession: session) { selectedExercise in
                addSet(to: selectedExercise)
                refreshExercises()
            }
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(minutes: $durationMinutes) {
                session.duration = TimeInterval(durationMinutes * 60)
            }
            .presentationDetents([.height(280)])
        }
        .alert("Delete Exercise?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { exerciseToDelete = nil }
            Button("Delete", role: .destructive) {
                if let ex = exerciseToDelete { deleteExercise(ex) }
            }
        } message: {
            if let ex = exerciseToDelete {
                Text("Delete \(ex.name) and all its sets?")
            }
        }
    }
    
    // MARK: - Sections
    private var sessionSummarySection: some View {
        Section {
            if isEditing {
                DatePicker("Date", selection: $session.date, displayedComponents: [.date, .hourAndMinute])
                TextField("Name", text: $session.name).foregroundStyle(.blue)
                Button { showDurationPicker = true } label: {
                    HStack {
                        Text("Duration").foregroundStyle(.primary)
                        Spacer()
                        Text("\(durationMinutes) min").foregroundStyle(.blue)
                    }
                }
            } else {
                LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: formatDuration(session.duration))
                LabeledContent("Name", value: session.name)
            }
        }
    }
    
    private var sessionNotesSection: some View {
        Section("Notes") {
            if isEditing {
                TextField("Add notes...", text: Binding(
                    get: { session.notes ?? "" },
                    set: { session.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical).lineLimit(3...6)
            } else {
                Text(session.notes ?? "No notes").foregroundStyle(session.notes == nil ? .tertiary : .primary)
            }
        }
    }
    
    // MARK: - Helpers
    private func refreshExercises() {
        orderedExercises = getExercises(from: session)
    }
    
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
        var unique: [Exercise] = []
        for set in sortedSets {
            if let ex = set.exercise, !unique.contains(where: { $0.id == ex.id }) {
                unique.append(ex)
            }
        }
        return unique
    }
    
    private func getSets(for exercise: Exercise) -> [WorkoutSet] {
        session.sets.filter { $0.exercise == exercise }.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// "3 sets" for strength; "30:00 • 3.2 mi" for cardio sessions.
    private func headerSummary(for exercise: Exercise) -> String {
        let sets = getSets(for: exercise)
        guard exercise.isCardio else { return "\(sets.count) sets" }
        return CardioFormatter.summary(for: sets.first)
    }
    
    private func toggleCollapse(for exercise: Exercise) {
        withAnimation {
            if collapsedExercises.contains(exercise.id) {
                collapsedExercises.remove(exercise.id)
            } else {
                collapsedExercises.insert(exercise.id)
            }
        }
    }
    
    // Updated Move Logic for Sections
    private func moveExercise(_ exercise: Exercise, direction: Int) {
        guard let index = orderedExercises.firstIndex(of: exercise) else { return }
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < orderedExercises.count else { return }
        
        withAnimation {
            orderedExercises.swapAt(index, newIndex)
        }
        
        // Re-index all sets in the session to match the new exercise order
        var globalSetIndex = 0
        for ex in orderedExercises {
            let sets = getSets(for: ex)
            for set in sets {
                set.orderIndex = globalSetIndex
                globalSetIndex += 1
            }
        }
    }
    
    private func addSet(to exercise: Exercise) {
        let maxIndex = session.sets.map { $0.orderIndex }.max() ?? 0
        let unit = UserDefaults.standard.string(forKey: "unitSystem") == "metric" ? "kg" : "lbs"
        let newSet = WorkoutSet(weight: 0, reps: 0, orderIndex: maxIndex + 1, unit: unit)
        newSet.exercise = exercise
        newSet.workoutSession = session
        
        // Auto-assign unit if Stairmaster
        if exercise.name.localizedCaseInsensitiveContains("Stair") {
            newSet.unit = "steps"
        }
        
        modelContext.insert(newSet)
        collapsedExercises.remove(exercise.id)
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        withAnimation { modelContext.delete(set) }
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        withAnimation {
            let sets = session.sets.filter { $0.exercise == exercise }
            sets.forEach { modelContext.delete($0) }
            orderedExercises.removeAll { $0.id == exercise.id }
        }
        exerciseToDelete = nil
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        return mins >= 60 ? "\(mins / 60) hr \(mins % 60) min" : "\(mins) min"
    }
}

// MARK: - New Header View
struct ExerciseSectionHeader: View {
    let exercise: Exercise
    let summary: String
    let isEditing: Bool
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil) // Fixes automatic capitalization in headers
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .textCase(nil)
            }
            
            Spacer()
            
            if isEditing {
                // Reorder Arrows
                HStack(spacing: 0) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up").padding(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down").padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.blue)
                .padding(.trailing, 8)
                
                // Delete
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(.plain)
            } else {
                // Collapse Arrow
                Button(action: onToggleCollapse) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.blue)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Duration Picker Sheet
struct DurationPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var minutes: Int
    var onSave: () -> Void
    
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Workout Duration")
                    .font(.headline)
                    .padding(.top)
                
                HStack(spacing: 0) {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(0..<6) { hour in
                            Text("\(hour) hr").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    .clipped()
                    
                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(0..<60) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    .clipped()
                }
                .frame(height: 150)
                
                Spacer()
            }
            .onAppear {
                selectedHours = minutes / 60
                selectedMinutes = minutes % 60
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        minutes = (selectedHours * 60) + selectedMinutes
                        onSave()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - UPDATED History Set Row View
struct HistorySetRowView: View {
    @Bindable var set: WorkoutSet
    var isEditing: Bool
    var exerciseType: String
    var onDelete: () -> Void
    
    private var setIndex: Int {
        guard let session = set.workoutSession else { return 0 }
        let setsForExercise = session.sets
            .filter { $0.exercise == set.exercise }
            .sorted { $0.orderIndex < $1.orderIndex }
        return (setsForExercise.firstIndex(of: set) ?? 0) + 1
    }
    
    // Logic to detect steps-based sets (Stairmaster, Walking)
    private var isStepsBased: Bool {
        return set.unit == "steps" || (set.exercise?.name.localizedCaseInsensitiveContains("Stair") ?? false)
    }
    
    var body: some View {
        HStack {
            // Cardio is a single continuous session, not "Set 1"
            Text(isStepsBased || exerciseType == "Cardio" ? "Session" : "Set \(setIndex)")
                .foregroundStyle(.secondary)
                .frame(minWidth: 45, alignment: .leading)

            if isEditing {
                editableContent
            } else {
                displayContent
            }
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private var editableContent: some View {
        // MARK: - THREE STATES OF EDITING
        
        if isStepsBased {
            // 1. Steps + Duration (Stairmaster)
            HStack {
                TextField("Count", value: Binding(
                    get: { set.steps ?? 0 },
                    set: { set.steps = $0 }
                ), format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)

                Text(set.unit).font(.caption) // steps / floors / laps
                
                Spacer()
                
                TextField("Min", value: Binding(
                    get: { set.duration ?? 0 },
                    set: { set.duration = $0 }
                ), format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 60)
                
                Text("min").font(.caption)
            }
            
        } else if exerciseType == "Cardio" {
            // 2. Distance + Duration (Running/Cycling)
            HStack {
                TextField("Dist", value: Binding(
                    get: { set.distance ?? 0 },
                    set: { set.distance = $0 }
                ), format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 70)
                
                Button(set.unit) {
                    set.unit = (set.unit == "mi") ? "km" : "mi"
                }
                .font(.caption)
                .buttonStyle(.bordered)
                
                Spacer()
                
                TextField("Time", value: Binding(
                    get: { set.duration ?? 0 },
                    set: { set.duration = $0 }
                ), format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 60)
                
                Text("min").font(.caption)
            }
            
        } else {
            // 3. Strength (Weight + Reps)
            HStack {
                TextField("Lbs", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                
                Button(set.unit) {
                    set.unit = (set.unit == "lbs") ? "kg" : "lbs"
                }
                .font(.caption)
                .buttonStyle(.bordered)
                
                Spacer()
                
                TextField("Reps", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 60)
                
                Text("r").font(.caption)
            }
        }
        
        Spacer()
        
        Button(action: onDelete) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .padding(.leading, 8)
    }
    
    @ViewBuilder
    private var displayContent: some View {
        Spacer()
        
        if isStepsBased || exerciseType == "Cardio" {
            // One formatter for every tracking type:
            // "30:00 • 3.2 mi" / "45:00 • 12 floors" / "30:00"
            Text(CardioFormatter.summary(for: set))
                .bold()
                .monospacedDigit()
        } else {
            HStack {
                Text("\(Int(set.weight)) \(set.unit)")
                    .bold()
                Text("x")
                Text("\(set.reps)")
            }
        }
    }
}
