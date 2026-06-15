//
//  RoutineImportView.swift
//  Doggo
//
//  Created by Sorest on 1/19/26.
//

import SwiftUI
import SwiftData

struct RoutineImportView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Data Source
    @Query var allExercises: [Exercise]
    
    // State
    @State private var isProcessing = false
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    
    // The "Draft" Results
    @State private var importedRoutines: [AIImportedRoutine] = []
    
    // State for resolving "Unknown" exercises
    @State private var itemToResolve: AIImportedExercise?
    
    let container: AppContainer
    
    // Computed property to check if we have missing items
    var hasMissingExercises: Bool {
        importedRoutines.flatMap { $0.exercises }.contains { $0.confidence != "High" }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    loadingView
                } else if !importedRoutines.isEmpty {
                    reviewList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Import Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                if !importedRoutines.isEmpty {
                    // Batch Create Button
                    if hasMissingExercises {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Create Missing") { createAllMissing() }
                                .font(.caption).bold().foregroundStyle(.blue)
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save All") { saveAll() }
                            .bold()
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    handleFileSelection(url)
                }
            }
            .sheet(item: $itemToResolve) { item in
                ImportExerciseSelectionSheet(initialSearch: item.originalName) { selectedExercise in
                    resolveExercise(item, with: selectedExercise)
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Views
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Import from File")
                .font(.title2).bold()
            
            Text("Upload a PDF or Text file containing your workout plan.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button(action: { showFilePicker = true }) {
                Label("Select File", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            Text("Supported: PDF, TXT")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Reading File...")
                .font(.headline)
            Text("Mapping exercises to your database...")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    
    var reviewList: some View {
        List {
            ForEach($importedRoutines) { $routine in
                Section {
                    ForEach($routine.exercises) { $item in
                        importRow($item)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { offsets in
                        $routine.wrappedValue.exercises.remove(atOffsets: offsets)
                    }

                    if routine.exercises.isEmpty {
                        Text("All exercises removed — this routine won't be saved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        TextField("Routine Name", text: $routine.routineName)
                            .textInputAutocapitalization(.words)
                        Button(role: .destructive) {
                            withAnimation {
                                importedRoutines.removeAll { $0.id == routine.id }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .accessibilityLabel("Remove \(routine.routineName)")
                    }
                } footer: {
                    Text("Tap any field to edit. Swipe left on an exercise to remove it.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Low-confidence rows keep the tap-to-resolve flow; matched rows are
    /// edited inline (name, sets, reps) and saved through the same
    /// sanitize-and-create pipeline as the AI program generator.
    private func importRow(_ item: Binding<AIImportedExercise>) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Superset Indicator
            if let label = item.wrappedValue.supersetLabel {
                VStack(spacing: 0) {
                    Text(label).font(.caption2).bold().foregroundStyle(.white)
                        .frame(width: 20, height: 20).background(Circle().fill(Color.pink))
                    Rectangle().fill(Color.pink.opacity(0.3)).frame(width: 2).frame(maxHeight: .infinity)
                }
            } else { Color.clear.frame(width: 20) }

            statusIcon(for: item.wrappedValue.confidence).padding(.top, 4)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if item.wrappedValue.confidence != "High" {
                    Button {
                        itemToResolve = item.wrappedValue
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(item.wrappedValue.originalName).font(.headline).foregroundStyle(.red)
                            HStack {
                                Text("Tap to Resolve")
                                    .font(.caption2).bold().foregroundStyle(.white)
                                    .padding(4).background(Color.red).cornerRadius(4)
                                if let m = item.wrappedValue.suggestedMuscle {
                                    Text("AI: \(m)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: Spacing.sm) {
                        TextField("Exercise Name", text: item.mappedName)
                            .font(.headline)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        Button {
                            itemToResolve = item.wrappedValue
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remap exercise")
                    }
                    if item.wrappedValue.originalName != item.wrappedValue.mappedName {
                        Text("From: \"\(item.wrappedValue.originalName)\"").font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    TextField("Sets", value: item.sets, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 36)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                    Text("×").foregroundStyle(.tertiary)
                    TextField("Reps", text: item.reps)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                    if let note = item.wrappedValue.note {
                        Text(note).font(.caption).foregroundStyle(.orange).lineLimit(1)
                    }
                }
                .font(.caption)
            }
        }
    }
    
    func statusIcon(for confidence: String) -> some View {
        switch confidence {
        case "High": return Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default: return Image(systemName: "questionmark.circle.fill").foregroundStyle(.red)
        }
    }
    
    // MARK: - Logic
    
    func createAllMissing() {
        // Cache by canonical key so two unknown rows with the same name
        // (or "bench press" vs "Bench Press!") create one exercise.
        var createdThisBatch: [String: Exercise] = [:]

        withAnimation {
            for rIndex in 0..<importedRoutines.count {
                for eIndex in 0..<importedRoutines[rIndex].exercises.count {
                    var item = importedRoutines[rIndex].exercises[eIndex]

                    if item.confidence != "High" {
                        let cleanName = GenerateProgramUseCase.sanitizeExerciseName(item.originalName)
                        guard !cleanName.isEmpty else { continue }
                        let key = GenerateProgramUseCase.canonicalKey(cleanName)

                        // 1. SAFETY CHECK: Does an equivalent exist already?
                        if let existing = allExercises.first(where: { GenerateProgramUseCase.canonicalKey($0.name) == key }) ?? createdThisBatch[key] {
                            item.mappedName = existing.name
                            item.confidence = "High"
                        } else {
                            // 2. Create NEW
                            let newEx = Exercise(name: cleanName)
                            newEx.muscleGroup = item.suggestedMuscle ?? "Other"
                            newEx.type = item.suggestedType ?? "Strength"
                            if newEx.type == "Cardio", let tracking = item.suggestedCardioType {
                                newEx.cardioTracking = CardioTrackingType.from(tracking)
                            }
                            modelContext.insert(newEx)
                            createdThisBatch[key] = newEx

                            item.mappedName = newEx.name
                            item.confidence = "High"
                        }

                        importedRoutines[rIndex].exercises[eIndex] = item
                    }
                }
            }
        }
    }
    
    func resolveExercise(_ item: AIImportedExercise, with exercise: Exercise) {
        for rIndex in 0..<importedRoutines.count {
            if let eIndex = importedRoutines[rIndex].exercises.firstIndex(where: { $0.id == item.id }) {
                var updated = importedRoutines[rIndex].exercises[eIndex]
                updated.mappedName = exercise.name
                updated.confidence = "High"
                importedRoutines[rIndex].exercises[eIndex] = updated
            }
        }
    }
    
    func handleFileSelection(_ url: URL) {
        isProcessing = true
        guard let text = TextExtractor.extractText(from: url) else {
            errorMessage = "Could not read text."
            isProcessing = false
            return
        }
        
        Task {
            do {
                let apiClient = container.aiClient
                let prompt = GeminiPromptBuilder.buildImportPrompt(text: text, validExercises: allExercises)
                let response = try await apiClient.sendRequest(prompt: prompt)
                var result = try GeminiResponseParser.parseImport(response)
                result = applySmartMatching(to: result)
                
                await MainActor.run {
                    self.importedRoutines = result
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func applySmartMatching(to routines: [AIImportedRoutine]) -> [AIImportedRoutine] {
        var processed = routines
        for rIndex in 0..<processed.count {
            for eIndex in 0..<processed[rIndex].exercises.count {
                var ex = processed[rIndex].exercises[eIndex]
                if ex.confidence == "High" { continue }
                
                let cleanOrig = cleanString(ex.originalName)
                
                if let match = allExercises.first(where: {
                    let cleanDB = cleanString($0.name)
                    return cleanDB == cleanOrig || cleanDB.contains(cleanOrig)
                }) {
                    ex.mappedName = match.name
                    ex.confidence = "High"
                    processed[rIndex].exercises[eIndex] = ex
                }
            }
        }
        return processed
    }
    
    private func cleanString(_ input: String) -> String {
        return input.lowercased()
            .replacingOccurrences(of: "barbell", with: "")
            .replacingOccurrences(of: "dumbbell", with: "")
            .replacingOccurrences(of: "db", with: "")
            .filter { !$0.isPunctuation && !$0.isWhitespace }
    }
    
    func saveAll() {
        // LOCAL CACHE: Stores exercises created during THIS save session
        // Prevents duplicates if the routine lists the same new exercise twice (e.g., once for warmups)
        var sessionCreatedExercises: [String: Exercise] = [:]

        for draft in importedRoutines {
            // Edited drafts can leave blank names or emptied routines behind.
            let saveablePlans = draft.exercises.filter {
                !$0.mappedName.contains("Unknown")
                    && !GenerateProgramUseCase.sanitizeExerciseName($0.mappedName).isEmpty
            }
            guard !saveablePlans.isEmpty else { continue }

            let routineName = draft.routineName.trimmingCharacters(in: .whitespacesAndNewlines)
            let routine = Routine(name: routineName.isEmpty ? "Imported Routine" : routineName)
            modelContext.insert(routine)
            var supersetMap: [String: UUID] = [:]

            for (idx, item) in saveablePlans.enumerated() {
                var ssID: UUID? = nil
                if let lbl = item.supersetLabel {
                    if let id = supersetMap[lbl] { ssID = id }
                    else { let id = UUID(); supersetMap[lbl] = id; ssID = id }
                }

                // --- EXERCISE RESOLUTION ---
                // Hand-edited names go through the same pipeline as the AI
                // program generator: sanitize → exact match → canonical
                // token-set match → create.
                let exerciseToUse: Exercise
                let targetName = GenerateProgramUseCase.sanitizeExerciseName(item.mappedName)
                let canonicalKey = GenerateProgramUseCase.canonicalKey(targetName)

                // 1. Check DB (exact, then token-set equivalent)
                if let match = allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(targetName) == .orderedSame })
                    ?? allExercises.first(where: { GenerateProgramUseCase.canonicalKey($0.name) == canonicalKey }) {
                    exerciseToUse = match
                }
                // 2. Check Local Session Cache (created 0.01s ago?)
                else if let cached = sessionCreatedExercises[canonicalKey] {
                    exerciseToUse = cached
                }
                // 3. Create NEW (and cache it)
                else {
                    let newEx = Exercise(name: targetName)
                    // Try to carry over suggestion if available, else fallback
                    newEx.muscleGroup = item.suggestedMuscle ?? "Other"
                    newEx.type = item.suggestedType ?? "Strength"
                    if newEx.type == "Cardio", let tracking = item.suggestedCardioType {
                        newEx.cardioTracking = CardioTrackingType.from(tracking)
                    }

                    modelContext.insert(newEx)
                    exerciseToUse = newEx
                    sessionCreatedExercises[canonicalKey] = newEx
                }
                // -------------------------------------

                let rItem = RoutineItem(orderIndex: idx, exercise: exerciseToUse, note: item.note, supersetID: ssID)
                rItem.routine = routine
                modelContext.insert(rItem)

                // "6-8" survives as a real range: lower bound is the working
                // target, upper bound is the progression bar.
                let range = RepRange.parse(item.reps)

                for i in 0..<max(1, item.sets) {
                    let t = RoutineSetTemplate(orderIndex: i, targetReps: range.lower, targetRepsUpper: range.upper)
                    t.routineItem = rItem
                    modelContext.insert(t)
                }
            }
        }
        modelContext.saveLogging()
        dismiss()
    }
}

// MARK: - EXERCISE PICKER
struct ImportExerciseSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Exercise.name) var allExercises: [Exercise]
    
    var initialSearch: String
    var onSelect: (Exercise) -> Void
    
    @State private var searchText = ""
    @State private var showCreationSheet = false
    @State private var creationName = ""
    @State private var creationMuscle = "Other"
    @State private var creationType = "Strength"
    
    let muscleOptions = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Full Body", "Other"]
    let typeOptions = ["Strength", "Cardio", "Flexibility", "Other"]
    
    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty {
                    Section {
                        Button(action: {
                            creationName = searchText
                            showCreationSheet = true
                        }) {
                            Label("Create '\(searchText)'...", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                ForEach(muscleGroups, id: \.self) { group in
                    Section(header: Text(group)) {
                        ForEach(groupedExercises[group] ?? []) { exercise in
                            Button(action: {
                                onSelect(exercise)
                                dismiss()
                            }) {
                                HStack {
                                    Text(exercise.name).foregroundStyle(.primary)
                                    Spacer()
                                    if exercise.type == "Cardio" {
                                        Image(systemName: "figure.run").foregroundStyle(.blue)
                                    } else {
                                        Text(exercise.muscleGroup).font(.caption2).foregroundStyle(.secondary)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.1)).cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Select Exercise")
            .toolbar { Button("Cancel") { dismiss() } }
            .onAppear {
                if !initialSearch.contains("Unknown") {
                    searchText = initialSearch
                }
            }
            .sheet(isPresented: $showCreationSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("Exercise Details")) {
                            TextField("Name", text: $creationName)
                            Picker("Muscle Group", selection: $creationMuscle) {
                                ForEach(muscleOptions, id: \.self) { Text($0).tag($0) }
                            }
                            Picker("Exercise Type", selection: $creationType) {
                                ForEach(typeOptions, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                    .navigationTitle("New Exercise")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showCreationSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") { createAndSelect() }
                            .disabled(creationName.count < 2)
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
        }
    }
    
    var groupedExercises: [String: [Exercise]] {
        let filtered = allExercises.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
        return Dictionary(grouping: filtered, by: { $0.muscleGroup })
    }
    var muscleGroups: [String] { groupedExercises.keys.sorted() }
    
    func createAndSelect() {
        let cleanName = creationName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // SAFETY CHECK: Does it exist already?
        if let existing = allExercises.first(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }) {
            onSelect(existing)
        } else {
            let newExercise = Exercise(name: cleanName)
            newExercise.muscleGroup = creationMuscle
            newExercise.type = creationType
            modelContext.insert(newExercise)
            onSelect(newExercise)
        }
        
        showCreationSheet = false
        dismiss()
    }
}
