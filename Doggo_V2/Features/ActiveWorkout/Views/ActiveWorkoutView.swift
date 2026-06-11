//
//  ActiveWorkoutView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

/// Identifies which set's text field currently owns the keyboard. Hoisted to
/// ActiveWorkoutView so a single keyboard toolbar can be declared once, rather
/// than per-row (which failed to register after a cold launch).
enum WorkoutSetField: Hashable {
    case weight(UUID)
    case reps(UUID)
    case distance(UUID)
    case steps(UUID)
    case time(UUID)
}

struct ActiveWorkoutView: View {
    let container: AppContainer

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ActiveWorkoutViewModel?

    // Single source of keyboard focus for every set row in the list.
    @FocusState private var focusedField: WorkoutSetField?

    // For the "Today's Plan" empty state
    @Query private var profiles: [UserProfile]
    @Query private var routines: [Routine]

    // MARK: - Finish Confirmation State
    @State private var showFinishConfirmation = false
    @State private var showEmptyFinishOptions = false
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    
    // MARK: - Global Settings
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("userTheme") private var userTheme: AppTheme = .light // <--- THEME SUPPORT
    
    @StateObject private var timerManager = RestTimerManager()
    
    // UI State
    @State private var showExerciseList = false
    @State private var exerciseToSwap: Exercise?
    @State private var collapsedExercises: Set<UUID> = []
    
    // MARK: - Delete Confirmation State
    @State private var showDeleteConfirmation = false
    @State private var exerciseToDelete: Exercise?
    
    enum DisplayUnit: Identifiable {
        case single(Exercise)
        case superset([Exercise])
        
        var id: String {
            switch self {
            case .single(let e): return e.id.uuidString
            case .superset(let es): return es.map { $0.id.uuidString }.joined()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    workoutContent(viewModel: viewModel)
                } else {
                    ProgressView("Loading...")
                }
            }
            .onAppear {
                if viewModel == nil {
                    self.viewModel = container.makeActiveWorkoutViewModel()
                }
                if let vm = viewModel {
                    Task { await vm.checkForActiveSession() }
                }
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            
            // Toolbar (History). The rest timer moved from a toolbar capsule
            // (where one accidental tap cancelled it) to the floating
            // RestTimerView card overlaid at the bottom of the list.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: HistoryView(container: container)) {
                        Text("History").bold()
                    }
                }
                // NOTE: The keyboard "Done" toolbar moved into SetRowView /
                // CardioSetRowView. Registered up here it silently failed to
                // appear after a cold launch until the view was rebuilt.
            }
        }
        .sheet(isPresented: $showExerciseList) {
            if let session = viewModel?.currentSession {
                ExerciseListView(currentSession: session) { selectedExercise in
                    if let old = exerciseToSwap {
                        viewModel?.replaceExercise(oldExercise: old, newExercise: selectedExercise)
                        exerciseToSwap = nil
                    } else {
                        viewModel?.addSet(to: selectedExercise, weight: 0, reps: 0)
                    }
                    showExerciseList = false
                }
            }
        }
        // MARK: - Delete Confirmation Alert
        .alert("Delete Exercise?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    withAnimation {
                        viewModel?.deleteExercise(exercise)
                    }
                }
                exerciseToDelete = nil
            }
        } message: {
            if let exercise = exerciseToDelete {
                Text("Are you sure you want to remove \(exercise.name) and all its sets?")
            }
        }
        // MARK: - Finish Confirmation (with summary)
        .confirmationDialog("Finish Workout?", isPresented: $showFinishConfirmation, titleVisibility: .visible) {
            Button("Finish & Save") {
                HapticManager.shared.notification(type: .success)
                timerManager.stopTimer()
                Task { await viewModel?.finishWorkout() }
            }
            Button("Keep Logging", role: .cancel) {}
        } message: {
            Text(finishSummary)
        }
        // MARK: - Empty Workout Guard
        .confirmationDialog("Nothing Logged Yet", isPresented: $showEmptyFinishOptions, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive) {
                timerManager.stopTimer()
                viewModel?.discardWorkout()
            }
            Button("Save Anyway") {
                timerManager.stopTimer()
                Task { await viewModel?.finishWorkout() }
            }
            Button("Keep Logging", role: .cancel) {}
        } message: {
            Text("No sets are marked complete. Discard this session, or save it to history as-is?")
        }
    }

    // "45 min · 18 sets completed · 12,400 lbs"
    private var finishSummary: String {
        guard let session = viewModel?.currentSession else { return "" }
        let completed = session.sets.filter { $0.isCompleted }

        var volumeLbs = 0.0
        for set in completed where (set.distance ?? 0) == 0 && set.weight > 0 {
            let weight = set.unit == "kg" ? set.weight * 2.20462 : set.weight
            volumeLbs += weight * Double(set.reps)
        }

        let minutes = max(1, (viewModel?.elapsedSeconds ?? 0) / 60)
        var parts = ["\(minutes) min", "\(completed.count) sets completed"]
        if volumeLbs > 0 {
            let isMetric = unitSystem == .metric
            let volume = isMetric ? volumeLbs * 0.453592 : volumeLbs
            parts.append("\(Int(volume).formatted()) \(isMetric ? "kg" : "lbs") volume")
        }
        return parts.joined(separator: " · ")
    }
    
    @ViewBuilder
    private func workoutContent(viewModel: ActiveWorkoutViewModel) -> some View {
        VStack(spacing: 0) {
            WorkoutHeaderView(
                elapsedSeconds: viewModel.elapsedSeconds,
                userTheme: userTheme, // Pass theme down
                onFinish: {
                    guard let session = viewModel.currentSession else { return }
                    if session.sets.contains(where: { $0.isCompleted }) {
                        showFinishConfirmation = true
                    } else {
                        showEmptyFinishOptions = true
                    }
                }
            )
            Divider()
            
            if let session = viewModel.currentSession {
                ScrollViewReader { proxy in
                    List {
                        let groups = getDisplayGroups(from: session)
                        ForEach(groups) { group in
                            switch group {
                            case .single(let exercise):
                                renderExerciseSection(exercise, session: session, viewModel: viewModel, proxy: proxy)
                            case .superset(let exercises):
                                Section {
                                    ForEach(exercises) { exercise in
                                        renderExerciseSection(exercise, session: session, viewModel: viewModel, isSuperset: true, proxy: proxy)
                                    }
                                } header: {
                                    HStack {
                                        Image(systemName: "flame.fill").foregroundStyle(.pink)
                                        Text("SUPERSET").font(.headline).foregroundStyle(.pink)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        
                        Section {
                            Button {
                                exerciseToSwap = nil
                                showExerciseList = true
                            } label: {
                                Label("Add Exercise", systemImage: "plus")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    // MARK: - THEME & ANIMATION FIXES
                    .scrollContentBackground(.hidden) // Make List Transparent
                    .background(Color.background(for: userTheme)) // Apply Theme Background
                    .smoothListAnimation(value: session.sets.count) // Smooth Set Deletion
                    // Swipe down on the list to dismiss the keypad — a reliable
                    // UIKit-backed fallback regardless of the Done bar.
                    .scrollDismissesKeyboard(.interactively)
                    // Custom "Done" bar. The native .toolbar(.keyboard) API fails
                    // to attach on a cold launch here; a safeAreaInset bar floats
                    // above the keyboard via SwiftUI keyboard avoidance and works
                    // on first focus every time.
                    .safeAreaInset(edge: .bottom) {
                        if focusedField != nil {
                            keyboardDoneBar
                        }
                    }
                    .animation(.snappy, value: focusedField)
                }
            } else {
                Spacer()
                if let todayRoutine = todaysPlannedRoutine {
                    // Surface the weekly plan here instead of burying it in the planner sheet
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "Today: \(todayRoutine.name)",
                        message: "From your weekly plan — \(todayRoutine.items.count) exercises ready to go.",
                        actionTitle: "Start \(todayRoutine.name)",
                        action: {
                            HapticManager.shared.notification(type: .success)
                            viewModel.startWorkout(from: todayRoutine)
                        },
                        secondaryActionTitle: "Start Freestyle Workout",
                        secondaryAction: { viewModel.startNewWorkout() }
                    )
                } else {
                    EmptyStateView(
                        icon: "dumbbell.fill",
                        title: "No Active Workout",
                        message: "Start a freestyle session, or pick a routine from the Lift tab.",
                        actionTitle: "Start Freestyle Workout",
                        action: { viewModel.startNewWorkout() }
                    )
                }
                Spacer()
            }
        }
        // MARK: - MAIN BACKGROUND FIX
        .background(Color.background(for: userTheme))
        // MARK: - Floating Rest Timer
        // The full-featured RestTimerView (presets, +30s, skip) — hidden while
        // the keypad is up so it doesn't fight the Done bar.
        .overlay(alignment: .bottom) {
            if timerManager.isActive && focusedField == nil {
                RestTimerView(
                    seconds: timerManager.timeRemaining,
                    onAdd: { timerManager.addTime(30) },
                    onSkip: { withAnimation { timerManager.stopTimer() } },
                    onSetPreset: { duration in timerManager.startTimer(duration: duration) }
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.isActive)
    }

    /// Today's routine from the user's weekly schedule, if one is assigned.
    private var todaysPlannedRoutine: Routine? {
        guard let schedule = profiles.first?.weeklySchedule else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: Date())
        guard let idString = schedule[dayName], let uuid = UUID(uuidString: idString) else { return nil }
        return routines.first { $0.id == uuid }
    }
    
    // Floats above the keyboard while a set field is focused.
    private var keyboardDoneBar: some View {
        HStack(spacing: 20) {
            Button { moveFocus(-1) } label: {
                Image(systemName: "chevron.up").fontWeight(.semibold)
            }
            .disabled(!canMoveFocus(-1))
            .accessibilityLabel("Previous field")

            Button { moveFocus(1) } label: {
                Image(systemName: "chevron.down").fontWeight(.semibold)
            }
            .disabled(!canMoveFocus(1))
            .accessibilityLabel("Next field")

            Spacer()
            Button("Done") { focusedField = nil }
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .overlay(alignment: .top) { Divider() }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Focus Navigation
    /// Every focusable input field in the current session, in list order, so
    /// the Done bar's arrows can chain through weight → reps → next set.
    private func orderedFocusFields() -> [WorkoutSetField] {
        guard let session = viewModel?.currentSession else { return [] }
        let useKeypad = UserDefaults.standard.bool(forKey: "useKeypadForSets")
        var fields: [WorkoutSetField] = []

        for set in session.sets.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let exercise = set.exercise,
                  !collapsedExercises.contains(exercise.id) else { continue }

            if exercise.type == "Cardio" {
                switch exercise.cardioType {
                case "Distance": fields.append(.distance(set.id))
                case "Steps": fields.append(.steps(set.id))
                default: break
                }
                fields.append(.time(set.id))
            } else if useKeypad {
                fields.append(.weight(set.id))
                fields.append(.reps(set.id))
            }
        }
        return fields
    }

    private func moveFocus(_ delta: Int) {
        guard let current = focusedField else { return }
        let fields = orderedFocusFields()
        guard let index = fields.firstIndex(of: current) else { return }
        let target = index + delta
        if fields.indices.contains(target) {
            focusedField = fields[target]
        } else if delta > 0 {
            focusedField = nil
        }
    }

    private func canMoveFocus(_ delta: Int) -> Bool {
        guard let current = focusedField else { return false }
        let fields = orderedFocusFields()
        guard let index = fields.firstIndex(of: current) else { return false }
        return fields.indices.contains(index + delta)
    }

    @ViewBuilder
    private func renderExerciseSection(
        _ exercise: Exercise,
        session: WorkoutSession,
        viewModel: ActiveWorkoutViewModel,
        isSuperset: Bool = false,
        proxy: ScrollViewProxy
    ) -> some View {
        Section {
            if !collapsedExercises.contains(exercise.id) {
                let relevantSets = getSets(for: exercise, in: session)
                ForEach(relevantSets, id: \.self) { set in
                    let index = (relevantSets.firstIndex(of: set) ?? 0) + 1
                    HStack(spacing: 0) {
                        if isSuperset {
                            Rectangle().fill(Color.pink).frame(width: 4).padding(.trailing, 12)
                        }
                        
                        if exercise.type == "Cardio" {
                            CardioSetRowView(set: set, index: index, focus: $focusedField)
                        } else {
                            SetRowView(
                                set: set,
                                index: index,
                                onComplete: {
                                    viewModel.completeSet(set)
                                    withAnimation { timerManager.startTimer(duration: defaultRestSeconds) }
                                },
                                container: container,
                                focus: $focusedField
                            )
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    let relevantSets = getSets(for: exercise, in: session)
                    for index in indexSet { viewModel.deleteSet(relevantSets[index]) }
                }
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    viewModel.addSet(to: exercise, weight: 0, reps: 0)
                } label: {
                    HStack {
                        if isSuperset { Color.clear.frame(width: 16) }
                        Label("Add Set", systemImage: "plus.circle.fill")
                            .font(.subheadline).foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
            }
        } header: {
            WorkoutSectionHeader(
                exercise: exercise,
                session: session,
                isCollapsed: collapsedExercises.contains(exercise.id),
                onToggleCollapse: { toggleCollapse(for: exercise) },
                onMoveUp: { moveExercise(exercise, direction: -1, viewModel: viewModel, proxy: proxy) },
                onMoveDown: { moveExercise(exercise, direction: 1, viewModel: viewModel, proxy: proxy) },
                onSwap: {
                    exerciseToSwap = exercise
                    showExerciseList = true
                },
                onDelete: {
                    exerciseToDelete = exercise
                    showDeleteConfirmation = true
                }
            )
            .id(exercise.id)
        }
    }
    
    // Helpers (Display Groups, Get Sets, Move Logic...) -> Same as previous
    private func getDisplayGroups(from session: WorkoutSession) -> [DisplayUnit] {
        let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
        var uniqueExercises: [Exercise] = []
        for set in sortedSets {
            if let ex = set.exercise, !uniqueExercises.contains(ex) { uniqueExercises.append(ex) }
        }
        var groups: [DisplayUnit] = []
        var i = 0
        while i < uniqueExercises.count {
            let currentEx = uniqueExercises[i]
            let currentSet = session.sets.first(where: { $0.exercise == currentEx })
            let currentSupersetID = currentSet?.routineItem?.supersetID
            if let id = currentSupersetID {
                var supersetBuffer: [Exercise] = [currentEx]
                var j = i + 1
                while j < uniqueExercises.count {
                    let nextEx = uniqueExercises[j]
                    let nextSet = session.sets.first(where: { $0.exercise == nextEx })
                    if nextSet?.routineItem?.supersetID == id {
                        supersetBuffer.append(nextEx)
                        j += 1
                    } else { break }
                }
                groups.append(.superset(supersetBuffer))
                i = j
            } else {
                groups.append(.single(currentEx))
                i += 1
            }
        }
        return groups
    }
    
    private func getSets(for exercise: Exercise, in session: WorkoutSession) -> [WorkoutSet] {
        session.sets.filter { $0.exercise == exercise }.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private func getExercises(from session: WorkoutSession) -> [Exercise] {
        let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
        var unique: [Exercise] = []
        for set in sortedSets {
            if let exercise = set.exercise {
                if !unique.contains(where: { $0.id == exercise.id }) { unique.append(exercise) }
            }
        }
        return unique
    }
    
    private func toggleCollapse(for exercise: Exercise) {
        withAnimation {
            if collapsedExercises.contains(exercise.id) { collapsedExercises.remove(exercise.id) }
            else { collapsedExercises.insert(exercise.id) }
        }
    }
    
    private func moveExercise(_ exercise: Exercise, direction: Int, viewModel: ActiveWorkoutViewModel, proxy: ScrollViewProxy) {
        guard let session = viewModel.currentSession else { return }
        var currentOrder = getExercises(from: session)
        guard let currentIndex = currentOrder.firstIndex(of: exercise) else { return }
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < currentOrder.count else { return }
        
        withAnimation {
            currentOrder.swapAt(currentIndex, newIndex)
            var globalSetIndex = 0
            for ex in currentOrder {
                let setsForExercise = getSets(for: ex, in: session)
                for set in setsForExercise {
                    set.orderIndex = globalSetIndex
                    globalSetIndex += 1
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { proxy.scrollTo(exercise.id, anchor: UnitPoint(x: 0.5, y: 0.15)) }
        }
    }
}

// MARK: - UPDATED Header
struct WorkoutSectionHeader: View {
    let exercise: Exercise
    let session: WorkoutSession
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSwap: () -> Void
    let onDelete: () -> Void
    
    private var aiNote: String? {
        session.sets.first(where: { $0.exercise == exercise && $0.routineItem?.note != nil })?.routineItem?.note
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .textCase(nil)
                
                Spacer()
                
                HStack(spacing: 0) {
                    Button(action: onMoveUp) { Image(systemName: "arrow.up").font(.caption.bold()).padding(8) }.buttonStyle(.plain)
                    Button(action: onMoveDown) { Image(systemName: "arrow.down").font(.caption.bold()).padding(8) }.buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
                
                Menu {
                    Button("Swap Exercise", systemImage: "arrow.triangle.2.circlepath") {
                        onSwap()
                    }
                    
                    Button(isCollapsed ? "Expand" : "Collapse", systemImage: "chevron.right") {
                        onToggleCollapse()
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Exercise", systemImage: "trash")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .padding(.leading, 8)
                        .padding(.vertical, 8)
                }
            }
            
            if let note = aiNote, !note.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.caption2)
                    Text(note).font(.caption).fontWeight(.medium)
                }
                .foregroundStyle(.purple)
                .textCase(nil)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - UPDATED Top Bar (Supports Theme)
struct WorkoutHeaderView: View {
    let elapsedSeconds: Int
    let userTheme: AppTheme // <--- Pass Theme
    let onFinish: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Session").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Text(formatTime(elapsedSeconds)).font(.largeTitle).monospacedDigit().fontWeight(.bold)
            }
            Spacer()
            Button("Finish") { onFinish() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .fontWeight(.bold)
        }
        .padding()
        // MARK: - HEADER BACKGROUND FIX
        .background(Color.background(for: userTheme))
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
