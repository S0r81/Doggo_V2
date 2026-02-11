import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Int
    
    // Toggle between the two modes
    @State private var selectedView = "Routines"
    let views = ["Routines", "Exercises"]
    let container: AppContainer
    
    // Sheets
    @State private var showCreateRoutine = false
    @State private var showCreateExercise = false
    @State private var showGenerator = false
    @State private var showImportSheet = false // <--- NEW STATE
    
    var body: some View {
        NavigationStack {
            VStack {
                // 1. Segmented Control
                Picker("View", selection: $selectedView) {
                    ForEach(views, id: \.self) { viewName in
                        Text(viewName)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 2. The Content
                if selectedView == "Routines" {
                    RoutineListContent(selectedTab: $selectedTab, container: container)
                } else {
                    ExerciseLibraryContent()
                }
            }
            .navigationTitle("Lift")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) { // Added spacing for better touch targets
                        
                        // 1. NEW: Import Button
                        Button(action: { showImportSheet = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        // 2. The AI Generator Button
                        Button(action: { showGenerator = true }) {
                            Image(systemName: "wand.and.stars")
                        }
                        
                        // 3. The Existing "Plus" Button
                        Button(action: {
                            if selectedView == "Routines" {
                                showCreateRoutine = true
                            } else {
                                showCreateExercise = true
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // Sheet for Routines
            .sheet(isPresented: $showCreateRoutine) {
                RoutineCreationView(container: container)
            }
            // Sheet for Exercises
            .sheet(isPresented: $showCreateExercise) {
                ExerciseCreationView()
                    .presentationDetents([.medium])
            }
            // Sheet for AI Generator
            .sheet(isPresented: $showGenerator) {
                RoutineGeneratorView(container: container)
            }
            // NEW: Sheet for File Import
            .sheet(isPresented: $showImportSheet) {
                RoutineImportView(container: container)
            }
        }
    }
}

// MARK: - Subview: Routine List
struct RoutineListContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query var routines: [Routine]
    @Binding var selectedTab: Int
    let container: AppContainer
    
    // State to track which routine we are editing
    @State private var routineToEdit: Routine?
    
    var body: some View {
        List {
            if routines.isEmpty {
                ContentUnavailableView("No Routines", systemImage: "clipboard")
            } else {
                ForEach(routines) { routine in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(routine.name)
                                .font(.headline)
                            Text("\(routine.items.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // EDIT BUTTON
                        Button(action: {
                            routineToEdit = routine
                        }) {
                            Image(systemName: "pencil.circle")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain) // Prevents clicking the whole row
                        .padding(.trailing, 8)
                        
                        // START BUTTON
                        Button("Start") {
                            startRoutine(routine)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteRoutine)
            }
        }
        // This sheet triggers whenever 'routineToEdit' is not nil
        .sheet(item: $routineToEdit) { routine in
            RoutineCreationView(routineToEdit: routine, container: container)
        }
    }
    
    // ... startRoutine and deleteRoutine remain the same ...
    private func startRoutine(_ routine: Routine) {
        let viewModel = container.makeActiveWorkoutViewModel()
        viewModel.startWorkout(from: routine)
        selectedTab = 2
    }
    
    private func deleteRoutine(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}

// MARK: - Subview: Exercise List (Grouped Manager)
struct ExerciseLibraryContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    
    @State private var searchText = ""
    
    // Grouping Logic
    var groupedExercises: [String: [Exercise]] {
        let filtered = exercises.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: filtered, by: { $0.muscleGroup })
    }
    
    var muscleGroups: [String] {
        groupedExercises.keys.sorted()
    }
    
    var body: some View {
        List {
            if exercises.isEmpty {
                ContentUnavailableView("No Exercises", systemImage: "dumbbell")
            } else {
                ForEach(muscleGroups, id: \.self) { group in
                    Section(header: Text(group)) {
                        ForEach(groupedExercises[group] ?? []) { exercise in
                            // Navigation to Detail/Stats View
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(exercise.name)
                                            .font(.headline)
                                        Text(exercise.type) // Subtitle
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteExercise(at: indexSet, in: group)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }
    
    // Helper to delete from the correct group
    private func deleteExercise(at offsets: IndexSet, in group: String) {
        let exercisesInGroup = groupedExercises[group] ?? []
        for index in offsets {
            let exerciseToDelete = exercisesInGroup[index]
            modelContext.delete(exerciseToDelete)
        }
    }
}

