//
//  ActiveWorkoutView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let container: AppContainer
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ActiveWorkoutViewModel?
    
    // MARK: - Global Settings
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    
    @StateObject private var timerManager = RestTimerManager()
    
    // UI State
    @State private var showExerciseList = false
    @State private var exerciseToSwap: Exercise?
    @State private var collapsedExercises: Set<UUID> = []
    
    // MARK: - NEW: Delete Confirmation State
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
            
            // Toolbar (Timer & History)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if timerManager.isActive {
                        Button {
                            withAnimation { timerManager.stopTimer() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .symbolEffect(.bounce, value: timerManager.timeRemaining)
                                Text(timerManager.formattedTime).monospacedDigit()
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: HistoryView(container: container)) {
                        Text("History").bold()
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
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
        // MARK: - NEW: Delete Confirmation Alert
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
    }
    
    @ViewBuilder
    private func workoutContent(viewModel: ActiveWorkoutViewModel) -> some View {
        VStack(spacing: 0) {
            WorkoutHeaderView(
                elapsedSeconds: viewModel.elapsedSeconds,
                onFinish: {
                    HapticManager.shared.notification(type: .success)
                    Task { await viewModel.finishWorkout() }
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
                    .animation(.default, value: collapsedExercises)
                }
            } else {
                ContentUnavailableView("No Active Workout", systemImage: "dumbbell.fill")
                Button("Start Freestyle Workout") {
                    viewModel.startNewWorkout()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
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
                            CardioSetRowView(set: set, index: index)
                        } else {
                            SetRowView(
                                set: set,
                                index: index,
                                onComplete: {
                                    viewModel.completeSet(set)
                                    withAnimation { timerManager.startTimer(duration: defaultRestSeconds) }
                                },
                                container: container
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
                            .font(.subheadline).foregroundStyle(.blue)
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
                // MARK: - NEW: Delete Trigger
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

// MARK: - UPDATED Header with Menu (Including Delete)
struct WorkoutSectionHeader: View {
    let exercise: Exercise
    let session: WorkoutSession
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSwap: () -> Void
    let onDelete: () -> Void // NEW Callback
    
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
                
                // MARK: - MENU (Swap / Collapse / Delete)
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
                        .foregroundStyle(.blue)
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

// Keep WorkoutHeaderView as is...
struct WorkoutHeaderView: View {
    let elapsedSeconds: Int
    let onFinish: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Session").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Text(formatTime(elapsedSeconds)).font(.largeTitle).monospacedDigit().fontWeight(.bold)
            }
            Spacer()
            Button("Finish") { onFinish() }
                .buttonStyle(.borderedProminent).tint(.green).fontWeight(.bold)
        }
        .padding().background(Color(uiColor: .systemBackground))
    }
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
