//
//  RoutineListView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Int
    
    // Toggle between the two modes
    @State private var selectedView = "Routines"
    let views = ["Routines", "Exercises"]
    let container: AppContainer
    
    // Theme State
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("routineSortOrder") private var routineSortOrder = "recent"

    // Sheets
    @State private var showCreateRoutine = false
    @State private var showCreateExercise = false
    @State private var showGenerator = false
    @State private var showImportSheet = false
    @State private var showPrograms = false
    
    var body: some View {
        NavigationStack {
            // spacing: 0 — each child owns its own explicit padding, so the
            // gap below the picker is one number instead of three stacked ones.
            VStack(spacing: 0) {
                // 1. Segmented Control
                Picker("View", selection: $selectedView) {
                    ForEach(views, id: \.self) { viewName in
                        Text(viewName)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 2. The Content
                if selectedView == "Routines" {
                    RoutineListContent(
                        selectedTab: $selectedTab,
                        container: container,
                        onCreateRoutine: { showCreateRoutine = true },
                        onBrowsePrograms: { showPrograms = true }
                    )
                    // Animation: Fade between views
                    .transition(.opacity.animation(.easeInOut))
                } else {
                    ExerciseLibraryContent(onCreateExercise: { showCreateExercise = true })
                        .transition(.opacity.animation(.easeInOut))
                }
            }
            .navigationTitle("Lift")
            // Inline matches Dashboard and avoids the large-title collapse
            // jitter caused by fixed content sitting above the scrolling List.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {

                        // Sort (Routines segment only)
                        if selectedView == "Routines" {
                            Menu {
                                Picker("Sort Routines", selection: $routineSortOrder) {
                                    Label("Recently Used", systemImage: "clock").tag("recent")
                                    Label("Name", systemImage: "textformat").tag("name")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .accessibilityLabel("Sort routines")
                        }

                        // Programs
                        Button(action: { showPrograms = true }) {
                            Image(systemName: "books.vertical")
                        }
                        .accessibilityLabel("Browse programs")

                        // Import Button
                        Button(action: { showImportSheet = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel("Import routine")

                        // AI Generator
                        Button(action: { showGenerator = true }) {
                            Image(systemName: "wand.and.stars")
                        }
                        .accessibilityLabel("AI routine builder")

                        // Plus Button
                        Button(action: {
                            if selectedView == "Routines" {
                                showCreateRoutine = true
                            } else {
                                showCreateExercise = true
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(selectedView == "Routines" ? "New routine" : "New exercise")
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                RoutineCreationView(container: container)
            }
            .sheet(isPresented: $showCreateExercise) {
                NavigationStack {
                    ExerciseCreationView()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showGenerator) {
                RoutineGeneratorView(container: container)
            }
            .sheet(isPresented: $showImportSheet) {
                RoutineImportView(container: container)
            }
            .sheet(isPresented: $showPrograms) {
                ProgramBrowserView()
            }
            // MARK: - THEME FIX (Main Background)
            .background(Color.background(for: userTheme))
        }
    }
}

// MARK: - Subview: Routine List
struct RoutineListContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query var routines: [Routine]
    @Binding var selectedTab: Int
    let container: AppContainer
    var onCreateRoutine: () -> Void = {}
    var onBrowsePrograms: () -> Void = {}

    // For "last performed" on rows and the active-workout guard on Start
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date, order: .reverse
    ) private var completedSessions: [WorkoutSession]

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == false })
    private var activeSessions: [WorkoutSession]

    // For schedule badges and "Assign to Day"
    @Query private var profiles: [UserProfile]

    // Theme State
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("routineSortOrder") private var routineSortOrder = "recent"

    @State private var routineToEdit: Routine?
    @State private var routineToPreview: Routine?
    @State private var routineToDelete: Routine?
    @State private var routinePendingStart: Routine?

    // MARK: - Sorting
    private var lastPerformedByRoutine: [UUID: Date] {
        var map: [UUID: Date] = [:]
        for session in completedSessions { // newest first — first write wins
            for set in session.sets {
                if let routineID = set.routineItem?.routine?.id, map[routineID] == nil {
                    map[routineID] = session.date
                }
            }
        }
        return map
    }

    private var sortedRoutines: [Routine] {
        switch routineSortOrder {
        case "name":
            return routines.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        default: // "recent" — your active program floats to the top
            let lastDates = lastPerformedByRoutine
            return routines.sorted {
                (lastDates[$0.id] ?? .distantPast) > (lastDates[$1.id] ?? .distantPast)
            }
        }
    }

    private func scheduledDays(for routine: Routine) -> [String] {
        guard let schedule = profiles.first?.weeklySchedule else { return [] }
        let idString = routine.id.uuidString
        return schedule.filter { $0.value == idString }.map(\.key)
    }

    var body: some View {
        List {
            if routines.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: "No Routines",
                    message: "Install a proven training program, or build a routine from scratch.",
                    actionTitle: "Browse Programs",
                    action: onBrowsePrograms,
                    secondaryActionTitle: "Create Your Own",
                    secondaryAction: onCreateRoutine
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(sortedRoutines) { routine in
                    RoutineRowView(
                        routine: routine,
                        completedSessions: completedSessions,
                        scheduledDays: scheduledDays(for: routine),
                        onPreview: { routineToPreview = routine },
                        onEdit: { routineToEdit = routine },
                        onStart: { requestStart(routine) },
                        onDuplicate: { duplicateRoutine(routine) },
                        onDelete: { routineToDelete = routine },
                        onToggleDay: { day in toggleDay(day, for: routine) }
                    )
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        routineToDelete = sortedRoutines[index]
                    }
                }
            }
        }
        // MARK: - THEME & ANIMATION FIXES
        .scrollContentBackground(.hidden) // Make List Transparent
        .background(Color.background(for: userTheme)) // Apply Theme
        .contentMargins(.top, Spacing.sm, for: .scrollContent) // Match Exercises segment
        .smoothListAnimation(value: routines) // Smooth Deletion/Reordering
        .sheet(item: $routineToEdit) { routine in
            RoutineCreationView(routineToEdit: routine, container: container)
        }
        .sheet(item: $routineToPreview) { routine in
            RoutinePreviewSheet(
                routine: routine,
                onEdit: { routineToEdit = routine },
                onStart: { requestStart(routine) }
            )
        }
        // MARK: - Delete Confirmation
        .alert("Delete Routine?", isPresented: Binding(
            get: { routineToDelete != nil },
            set: { if !$0 { routineToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { routineToDelete = nil }
            Button("Delete", role: .destructive) {
                if let routine = routineToDelete {
                    withAnimation { modelContext.delete(routine) }
                }
                routineToDelete = nil
            }
        } message: {
            if let routine = routineToDelete {
                Text("\"\(routine.name)\" and its \(routine.items.count) exercises will be removed. Your workout history is not affected.")
            }
        }
        // MARK: - Active Workout Guard
        .confirmationDialog(
            "Workout in Progress",
            isPresented: Binding(
                get: { routinePendingStart != nil },
                set: { if !$0 { routinePendingStart = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Finish Current & Start New") { finishActiveAndStartPending() }
            Button("Go to Current Workout") {
                routinePendingStart = nil
                selectedTab = 2
            }
            Button("Cancel", role: .cancel) { routinePendingStart = nil }
        } message: {
            Text("You already have an unfinished workout. Finishing saves it to your history before starting \"\(routinePendingStart?.name ?? "")\".")
        }
    }

    // MARK: - Duplicate & Schedule
    private func duplicateRoutine(_ routine: Routine) {
        let copy = Routine(name: "\(routine.name) Copy", note: routine.note)
        modelContext.insert(copy)

        // Preserve superset groupings with fresh IDs
        var supersetMap: [UUID: UUID] = [:]

        for item in routine.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let exercise = item.exercise, !exercise.isDeleted else { continue }

            let newItem = RoutineItem(orderIndex: item.orderIndex, exercise: exercise, note: item.note)
            if let oldID = item.supersetID {
                if supersetMap[oldID] == nil { supersetMap[oldID] = UUID() }
                newItem.supersetID = supersetMap[oldID]
            }
            newItem.routine = copy

            for template in item.templateSets.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                newItem.templateSets.append(
                    RoutineSetTemplate(
                        orderIndex: template.orderIndex,
                        targetReps: template.targetReps,
                        targetRepsUpper: template.targetRepsUpper,
                        targetWeight: template.targetWeight
                    )
                )
            }
            modelContext.insert(newItem)
        }

        modelContext.saveLogging()
        HapticManager.shared.impact(style: .light)
    }

    private func toggleDay(_ day: String, for routine: Routine) {
        guard let profile = profiles.first else { return }
        let idString = routine.id.uuidString
        withAnimation {
            if profile.weeklySchedule[day] == idString {
                profile.weeklySchedule.removeValue(forKey: day)
            } else {
                profile.weeklySchedule[day] = idString
            }
        }
        modelContext.saveLogging()
    }

    // MARK: - Start Logic
    private func requestStart(_ routine: Routine) {
        if activeSessions.isEmpty {
            startRoutine(routine)
        } else {
            routinePendingStart = routine
        }
    }

    private func finishActiveAndStartPending() {
        guard let routine = routinePendingStart else { return }
        for session in activeSessions {
            session.isCompleted = true
            if let start = session.startTime {
                session.duration = Date().timeIntervalSince(start)
            }
        }
        modelContext.saveLogging()
        routinePendingStart = nil
        startRoutine(routine)
    }

    private func startRoutine(_ routine: Routine) {
        HapticManager.shared.notification(type: .success)
        let viewModel = container.makeActiveWorkoutViewModel()
        viewModel.startWorkout(from: routine)
        selectedTab = 2
    }
}

// MARK: - UPGRADED EXERCISE LIBRARY
struct ExerciseLibraryContent: View {
    @Environment(\.modelContext) private var modelContext

    // Theme State
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    // 1. Safe Query
    @Query var exercises: [Exercise]

    var onCreateExercise: () -> Void = {}

    // 2. ViewModel
    @State private var viewModel = ExerciseListViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: String?
    @State private var exerciseToDelete: Exercise?
    @State private var exerciseToEdit: Exercise?
    @State private var recentExercises: [Exercise] = []
    // Name snapshot for the alert text — reading it off the model after deletion
    // crashes with "backing data could no longer be found in the store".
    @State private var pendingDeleteName = ""

    var groupedExercises: [String: [Exercise]] {
        viewModel.groupExercises(exercises, searchText: searchText, filter: selectedFilter)
    }

    var muscleGroups: [String] { groupedExercises.keys.sorted() }

    var body: some View {
        VStack(spacing: 0) {
            FilterChipRow(
                selection: $selectedFilter,
                muscleGroups: viewModel.muscleGroupOptions(from: exercises)
            )
            exerciseList
        }
    }

    private var exerciseList: some View {
        List {
            if exercises.isEmpty {
                EmptyStateView(
                    icon: "dumbbell",
                    title: "No Exercises",
                    message: "Add an exercise to start building your library.",
                    actionTitle: "Add Exercise",
                    action: onCreateExercise
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if muscleGroups.isEmpty {
                if selectedFilter == "Favorites" && searchText.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star",
                        description: Text("Swipe right on any exercise to add it to your favorites.")
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
            } else {
                // Quick access to what you actually use
                if searchText.isEmpty, selectedFilter == nil, !recentExercises.isEmpty {
                    Section("Recently Used") {
                        ForEach(recentExercises) { exercise in
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                ExerciseRow(exercise: exercise)
                            }
                        }
                    }
                }

                ForEach(muscleGroups, id: \.self) { group in
                    Section(header: Text("\(group) · \(groupedExercises[group]?.count ?? 0)")) {
                        ForEach(groupedExercises[group] ?? []) { exercise in
                            
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                ExerciseRow(exercise: exercise)
                            }
                            // Animation: Fade in/out when filtering
                            .transition(.opacity)
                            
                            // Swipe Actions
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    // Use ViewModel logic (which now has withAnimation)
                                    viewModel.toggleFavorite(exercise)
                                } label: {
                                    Label("Favorite", systemImage: exercise.isFavorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if exercise.isCustom {
                                    Button(role: .destructive) {
                                        pendingDeleteName = exercise.name
                                        exerciseToDelete = exercise
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        exerciseToEdit = exercise
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                } else {
                                    Button {
                                        // System Protection
                                    } label: {
                                        Label("System", systemImage: "lock")
                                    }
                                    .tint(.gray)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        // MARK: - THEME & ANIMATION FIXES
        .scrollContentBackground(.hidden) // Make List Transparent
        .background(Color.background(for: userTheme)) // Apply Theme
        .contentMargins(.top, Spacing.xs, for: .scrollContent) // chips row supplies the other 4pt
        // This is the Magic Line for Smooth Sorting:
        .animation(.smooth, value: exercises)
        // Deleting an exercise cascade-deletes its workout history — confirm first.
        .alert("Delete Exercise?", isPresented: Binding(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { exerciseToDelete = nil }
            Button("Delete", role: .destructive) {
                // Clear state first so nothing re-renders against the deleted model
                let target = exerciseToDelete
                exerciseToDelete = nil
                if let target {
                    recentExercises.removeAll { $0.id == target.id }
                    withAnimation { viewModel.deleteExercise(target, context: modelContext) }
                }
            }
        } message: {
            Text("\"\(pendingDeleteName)\" and all of its logged sets will be permanently deleted.")
        }
        .sheet(item: $exerciseToEdit) { exercise in
            NavigationStack {
                ExerciseCreationView(exerciseToEdit: exercise)
            }
            .presentationDetents([.medium])
        }
        .onAppear { loadRecentExercises() }
    }

    /// The five most recently used exercises, by completed-set date.
    private func loadRecentExercises() {
        var descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSet.workoutSession?.date, order: .reverse)]
        )
        descriptor.fetchLimit = 60

        guard let sets = try? modelContext.fetch(descriptor) else { return }

        var seen = Set<UUID>()
        var result: [Exercise] = []
        for set in sets {
            if let exercise = set.exercise, !exercise.isDeleted, !seen.contains(exercise.id) {
                seen.insert(exercise.id)
                result.append(exercise)
                if result.count == 5 { break }
            }
        }
        recentExercises = result
    }
}
