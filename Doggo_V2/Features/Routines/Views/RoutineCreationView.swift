//
//  RoutineCreationView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct RoutineCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var routineToEdit: Routine?
    
    // Data for AI context and matching
    @Query var allExercises: [Exercise]
    @Query var profiles: [UserProfile]
    
    @State private var name = ""
    @State private var routineItems: [RoutineItem] = []
    
    // UI State
    @State private var showExercisePicker = false
    @State private var itemToConfigure: RoutineItem?
    
    // MARK: - AI State
    @State private var isGenerating = false
    @State private var aiError: String?
    
    // Dependency Injection
    let container: AppContainer
    
    // MARK: - Superset State
    @State private var isSelectionMode = false
    @State private var selectedItems = Set<RoutineItem>()
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Section 1: Name & AI
                Section(header: Text("Routine Details")) {
                    HStack {
                        TextField("Routine Name (e.g. Leg Day)", text: $name)
                        
                        // MAGIC WAND BUTTON
                        if isGenerating {
                            ProgressView()
                                .padding(.leading, 8)
                        } else if !name.isEmpty {
                            Button(action: autofillWithAI) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.purple)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                    }
                }
                
                // MARK: - Section 2: Exercises
                Section(header: headerWithActions) {
                    if routineItems.isEmpty {
                        VStack(spacing: 8) {
                            Text("No exercises added")
                                .foregroundStyle(.secondary)
                            
                            if name.isEmpty {
                                Text("Enter a name to use AI Auto-Fill")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(routineItems) { item in
                            RoutineItemRow(
                                item: item,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedItems.contains(item),
                                toggleAction: { toggleSelection(for: item) },
                                configureAction: { itemToConfigure = item }
                            )
                        }
                        .onMove(perform: moveItem)
                        .onDelete(perform: deleteItem)
                    }
                    
                    if !isSelectionMode {
                        Button(action: { showExercisePicker = true }) {
                            Label("Add Exercise", systemImage: "plus")
                        }
                        .disabled(isGenerating)
                    }
                }
            }
            .navigationTitle(routineToEdit == nil ? "New Routine" : "Edit Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoutine() }
                        .disabled(name.isEmpty || routineItems.isEmpty || isGenerating)
                }
                
                // Select Button
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        withAnimation {
                            isSelectionMode.toggle()
                            selectedItems.removeAll()
                        }
                    }
                    .disabled(routineItems.isEmpty || isGenerating)
                }
                
                // Edit Button (Standard)
                if !isSelectionMode && !routineItems.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .onAppear {
                if let routine = routineToEdit {
                    name = routine.name
                    routineItems = routine.items.sorted { $0.orderIndex < $1.orderIndex }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExerciseSelectionSheet(onSelect: addExercise)
            }
            .sheet(item: $itemToConfigure) { item in
                SetConfigurationView(item: item)
                    .presentationDetents([.medium, .large])
            }
            // Error Alert
            .alert("AI Error", isPresented: Binding(get: { aiError != nil }, set: { _ in aiError = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiError ?? "Unknown error")
            }
        }
    }
    
    // MARK: - AI Logic (UPDATED)
    
    private func autofillWithAI() {
        guard name.count >= 3 else {
            aiError = "Please enter a descriptive routine name first (e.g. 'Back and Biceps')."
            return
        }
        
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isGenerating = true
        
        Task {
            do {
                // 1. Get Client
                let apiClient = container.aiClient
                
                // 2. Build Prompt
                let prompt = GeminiPromptBuilder.buildRoutineContentPrompt(
                    routineName: name,
                    profile: profiles.first
                )
                
                // 3. Send Request
                let response = try await apiClient.sendRequest(prompt: prompt)
                
                // 4. Parse Response
                let generatedExercises = try GeminiResponseParser.parseExerciseList(response)
                
                await MainActor.run {
                    for genEx in generatedExercises {
                        // A. Find or Create Exercise
                        let exercise: Exercise
                        if let existing = allExercises.first(where: { $0.name.lowercased() == genEx.name.lowercased() }) {
                            exercise = existing
                        } else {
                            let newEx = Exercise(name: genEx.name)
                            modelContext.insert(newEx)
                            exercise = newEx
                        }
                        
                        // B. Create Routine Item
                        let newItem = RoutineItem(orderIndex: routineItems.count, exercise: exercise, note: genEx.note)
                        
                        // C. Add Sets
                        for i in 0..<genEx.sets {
                            let tmplSet = RoutineSetTemplate(orderIndex: i, targetReps: genEx.reps)
                            newItem.templateSets.append(tmplSet)
                        }
                        
                        routineItems.append(newItem)
                    }
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    aiError = "Could not generate routine. Please check your internet or try a different name."
                    isGenerating = false
                }
            }
        }
    }
    
    // MARK: - Superset & Standard Logic
    
    var headerWithActions: some View {
        HStack {
            Text("Exercises")
            Spacer()
            
            if isSelectionMode && selectedItems.count > 1 {
                Button("Link Superset") { linkSelectedItems() }
                    .font(.caption).bold().foregroundStyle(.pink)
            }
            
            if isSelectionMode && selectedItems.count == 1,
               let item = selectedItems.first,
               item.supersetID != nil {
                Button("Unlink") { unlinkItem(item) }
                    .font(.caption).bold().foregroundStyle(.red)
            }
        }
    }
    
    private func toggleSelection(for item: RoutineItem) {
        if selectedItems.contains(item) { selectedItems.remove(item) } else { selectedItems.insert(item) }
    }
    
    private func linkSelectedItems() {
        let newID = UUID()
        let sortedSelection = routineItems.filter { selectedItems.contains($0) }
        withAnimation {
            for item in sortedSelection { item.supersetID = newID }
            isSelectionMode = false; selectedItems.removeAll()
        }
    }
    
    private func unlinkItem(_ item: RoutineItem) {
        withAnimation {
            item.supersetID = nil
            isSelectionMode = false; selectedItems.removeAll()
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        let newItem = RoutineItem(orderIndex: routineItems.count, exercise: exercise)
        for i in 0..<3 {
            let set = RoutineSetTemplate(orderIndex: i, targetReps: 10)
            newItem.templateSets.append(set)
        }
        routineItems.append(newItem)
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        routineItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in routineItems.enumerated() { item.orderIndex = index }
    }
    
    private func deleteItem(at offsets: IndexSet) { routineItems.remove(atOffsets: offsets) }
    
    private func saveRoutine() {
        let routine = routineToEdit ?? Routine(name: name)
        routine.name = name
        
        if routineToEdit == nil { modelContext.insert(routine) }
        routine.items = []
        for (index, item) in routineItems.enumerated() {
            item.orderIndex = index
            item.routine = routine
            routine.items.append(item)
            modelContext.insert(item)
        }
        dismiss()
    }
}

// MARK: - Subview: Routine Item Row
struct RoutineItemRow: View {
    let item: RoutineItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let toggleAction: () -> Void
    let configureAction: () -> Void
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .onTapGesture { toggleAction() }
            }
            if item.supersetID != nil {
                Capsule().fill(Color.pink).frame(width: 4).padding(.vertical, 2)
            }
            if !isSelectionMode {
                Image(systemName: "line.3.horizontal").foregroundStyle(.gray)
            }
            VStack(alignment: .leading) {
                Text(item.exercise?.name ?? "Unknown").font(.headline)
                HStack {
                    Text(item.exercise?.isCardio == true ? "1 session" : repSummary(for: item))
                    if item.supersetID != nil {
                        Text("• Superset").foregroundStyle(.pink).fontWeight(.bold)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !isSelectionMode {
                Button(action: configureAction) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.blue).padding(8)
                        .background(Color.blue.opacity(0.1)).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Subview: Set Configuration Sheet
struct SetConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var item: RoutineItem
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Sets & Reps")) {
                    if item.templateSets.isEmpty {
                        Text("No sets configured.").foregroundStyle(.secondary)
                    } else {
                        ForEach(item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex })) { set in
                            SetRowConfig(set: set)
                        }
                        .onDelete { indexSet in
                            let sortedSets = item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex })
                            for index in indexSet {
                                let setToRemove = sortedSets[index]
                                if let realIndex = item.templateSets.firstIndex(of: setToRemove) {
                                    item.templateSets.remove(at: realIndex)
                                }
                            }
                            reindexSets()
                        }
                    }
                    Button("Add Set") {
                        withAnimation {
                            let nextIndex = item.templateSets.count
                            let reps = item.templateSets.last?.targetReps ?? 10
                            let newSet = RoutineSetTemplate(orderIndex: nextIndex, targetReps: reps)
                            item.templateSets.append(newSet)
                        }
                    }
                }
                if let note = item.note, !note.isEmpty {
                    Section(header: Text("Coach's Note")) {
                        Text(note).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(item.exercise?.name ?? "Configure")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
    
    private func reindexSets() {
        let sortedSets = item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex })
        for (index, set) in sortedSets.enumerated() { set.orderIndex = index }
    }
}

// MARK: - Helper Row for Binding
struct SetRowConfig: View {
    @Bindable var set: RoutineSetTemplate
    var body: some View {
        HStack {
            Text("Set \(set.orderIndex + 1)").foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
            Spacer()
            Stepper("\(set.targetReps) Reps", value: $set.targetReps, in: 1...100).fixedSize()
        }
    }
}

// Helper: Selection Sheet
// Uses the same ExerciseRow + filter chips as the rest of the app so the two
// exercise pickers look and behave identically.
struct ExerciseSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Query var allExercises: [Exercise]
    var onSelect: (Exercise) -> Void

    @State private var viewModel = ExerciseListViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: String?

    var groupedExercises: [String: [Exercise]] {
        viewModel.groupExercises(allExercises, searchText: searchText, filter: selectedFilter)
    }

    var muscleGroups: [String] { groupedExercises.keys.sorted() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterChipRow(
                    selection: $selectedFilter,
                    muscleGroups: viewModel.muscleGroupOptions(from: allExercises)
                )
                List {
                    if muscleGroups.isEmpty {
                        if selectedFilter == "Favorites" && searchText.isEmpty {
                            ContentUnavailableView(
                                "No Favorites Yet",
                                systemImage: "star",
                                description: Text("Swipe right on any exercise in the library to add favorites.")
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            ContentUnavailableView(
                                "No Matches",
                                systemImage: "magnifyingglass",
                                description: Text("Try a different search or filter.")
                            )
                            .listRowBackground(Color.clear)
                        }
                    }
                    ForEach(muscleGroups, id: \.self) { group in
                        Section(header: Text("\(group) · \(groupedExercises[group]?.count ?? 0)")) {
                            ForEach(groupedExercises[group] ?? []) { exercise in
                                Button(action: { onSelect(exercise); dismiss() }) {
                                    ExerciseRow(exercise: exercise)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Exercise")
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
