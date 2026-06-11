//
//  WeeklyPlannerView.swift
//  Doggo
//
//  Created by Sorest on 1/20/26.
//

import SwiftUI
import SwiftData

struct WeeklyPlannerView: View {
    @AppStorage("cachedCoachAdvice") private var cachedAdvice: String = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Fetch User Profile to save the schedule
    @Query var profiles: [UserProfile]
    var userProfile: UserProfile? { profiles.first }
    
    // Fetch Routines to populate the "Drawer" and for AI context
    @Query(sort: \Routine.name) var routines: [Routine]
    
    // MARK: - AI State
    @State private var isGenerating = false
    @State private var showAIAlert = false
    let container: AppContainer
    
    let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MAIN CONTENT
                VStack(spacing: 0) {
                    
                    // 1. SMART START HEADER (Visible if today has a routine)
                    if let todayRoutine = getRoutineForToday() {
                        VStack(spacing: 12) {
                            Text("TODAY'S MISSION")
                                .font(.caption).bold()
                                .foregroundStyle(.white.opacity(0.8))
                                .tracking(1)
                            
                            Text(todayRoutine.name)
                                .font(.title).bold()
                                .foregroundStyle(.white)
                            
                            Button(action: {
                                startWorkout(routine: todayRoutine)
                            }) {
                                Text("START NOW")
                                    .font(.headline.bold())
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.blue.gradient)
                    }
                    
                    // 2. THE WEEKLY GRID (Drop Targets)
                    List {
                        Section(header: Text("Your Schedule")) {
                            ForEach(daysOfWeek, id: \.self) { day in
                                DayRow(
                                    day: day,
                                    assignedRoutine: getRoutine(for: day),
                                    onRemove: { removeRoutine(from: day) }
                                )
                                // THE DROP ZONE
                                .dropDestination(for: String.self) { items, location in
                                    guard let routineID = items.first else { return false }
                                    assignRoutine(routineID, to: day)
                                    return true
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    
                    // 3. THE ROUTINE DRAWER (Draggable Source)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Drag a routine to a day above:")
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                if routines.isEmpty {
                                    ContentUnavailableView("No Routines", systemImage: "dumbbell")
                                        .frame(width: 200)
                                } else {
                                    ForEach(routines) { routine in
                                        DraggableRoutineCard(routine: routine)
                                            // MAKE DRAGGABLE
                                            .draggable(routine.id.uuidString) {
                                                Text(routine.name)
                                                    .padding()
                                                    .background(.blue)
                                                    .foregroundStyle(.white)
                                                    .cornerRadius(10)
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20) // Safety spacing for home bar
                        }
                        .frame(height: 80)
                    }
                    .padding(.top, 16)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: -5)
                }
                
                // 4. LOADING OVERLAY
                if isGenerating {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("AI is building your week...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationTitle("Weekly Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                // NEW: AI "Magic Wand" Button
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAIAlert = true }) {
                        Image(systemName: "wand.and.stars")
                    }
                    .disabled(isGenerating)
                }
            }
            .alert("Auto-Schedule", isPresented: $showAIAlert) {
                Button("Generate for Me") { generateSmartSchedule() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("AI will analyze your profile and existing routines to create a balanced weekly split. It may create new routines if needed.")
            }
        }
    }
    
    // MARK: - Manual Logic
    
    func getRoutine(for day: String) -> Routine? {
        guard let idString = userProfile?.weeklySchedule[day],
              let uuid = UUID(uuidString: idString) else { return nil }
        return routines.first(where: { $0.id == uuid })
    }
    
    func getRoutineForToday() -> Routine? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: Date())
        return getRoutine(for: dayName)
    }
    
    func assignRoutine(_ routineID: String, to day: String) {
        withAnimation { userProfile?.weeklySchedule[day] = routineID }
    }
    
    func removeRoutine(from day: String) {
        withAnimation { _ = userProfile?.weeklySchedule.removeValue(forKey: day) }
    }
    
    func startWorkout(routine: Routine) {
        let newSession = WorkoutSession(name: routine.name)
        newSession.startTime = Date()
        
        var orderIndex = 0
        for item in routine.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let exercise = item.exercise else { continue }
            for _ in item.templateSets {
                let newSet = WorkoutSet(weight: 0, reps: 0, orderIndex: orderIndex)
                newSet.exercise = exercise
                newSet.workoutSession = newSession
                newSet.routineItem = item
                modelContext.insert(newSet)
                orderIndex += 1
            }
        }
        modelContext.insert(newSession)
        dismiss()
    }
    
    // MARK: - AI Logic (The Brain)
    
    func generateSmartSchedule() {
        guard let profile = userProfile else { return }
        isGenerating = true
        
        // Fetch workout history for context
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let history = (try? modelContext.fetch(descriptor)) ?? []
        
        Task {
            do {
                // NEW: Use split AI service
                let apiClient = container.aiClient
                let prompt = GeminiPromptBuilder.buildSchedulePrompt(
                    profile: profile,
                    history: history,
                    coachAdvice: cachedAdvice
                )
                
                let rawResponse = try await apiClient.sendRequest(prompt: prompt)
                let weeklyPlan = try GeminiResponseParser.parseSchedule(rawResponse)
                
                await MainActor.run {
                    applyAISchedule(weeklyPlan)
                    isGenerating = false
                }
            } catch {
                print("AI Error: \(error)")
                await MainActor.run { isGenerating = false }
            }
        }
    }
    
    func parseAIResponse(_ text: String) throws -> [String: String] {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return [:] }
        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8) else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: data)
    }
    
    @MainActor
    func applyAISchedule(_ weeklyPlan: WeeklyPlan) {
        // Extract day-to-routine mapping from WeeklyPlan
        for daySchedule in weeklyPlan.days {
            let day = daySchedule.day
            let focus = daySchedule.focus
            
            if focus.lowercased() == "rest" {
                userProfile?.weeklySchedule.removeValue(forKey: day)
                continue
            }
            
            // Try to find matching routine
            if let existing = routines.first(where: { $0.name.lowercased().contains(focus.lowercased()) }) {
                userProfile?.weeklySchedule[day] = existing.id.uuidString
            } else {
                // Auto-create missing routine
                let routineName = focus
                let newRoutine = Routine(name: routineName, note: "AI Generated")
                modelContext.insert(newRoutine)
                try? modelContext.save()
                userProfile?.weeklySchedule[day] = newRoutine.id.uuidString
                
                print("✨ Auto-populating new routine: \(routineName)")
                Task {
                    do {
                        // Use new AI service
                        let apiClient = container.aiClient
                        let prompt = GeminiPromptBuilder.buildRoutineContentPrompt(
                            routineName: routineName,
                            profile: userProfile
                        )
                        let rawResponse = try await apiClient.sendRequest(prompt: prompt)
                        let generatedContent = try GeminiResponseParser.parseExerciseList(rawResponse)
                        
                        await MainActor.run {
                            var orderIndex = 0
                            for genEx in generatedContent {
                                let targetName: String = genEx.name
                                let descriptor = FetchDescriptor<Exercise>(
                                    predicate: #Predicate { $0.name == targetName }
                                )
                                let exercise: Exercise
                                
                                if let existingEx = try? modelContext.fetch(descriptor).first {
                                    exercise = existingEx
                                } else {
                                    let newEx = Exercise(name: genEx.name)
                                    modelContext.insert(newEx)
                                    exercise = newEx
                                }
                                
                                let newItem = RoutineItem(
                                    orderIndex: orderIndex,
                                    exercise: exercise,
                                    note: genEx.note
                                )
                                newItem.routine = newRoutine
                                
                                for i in 0..<genEx.sets {
                                    let tmpl = RoutineSetTemplate(
                                        orderIndex: i,
                                        targetReps: genEx.reps
                                    )
                                    newItem.templateSets.append(tmpl)
                                }
                                
                                modelContext.insert(newItem)
                                orderIndex += 1
                            }
                        }
                    } catch {
                        print("❌ Failed to populate \(routineName): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct DayRow: View {
    let day: String
    let assignedRoutine: Routine?
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(day.prefix(3).uppercased())
                .font(.caption).bold()
                .foregroundStyle(.secondary)
                .frame(width: 40)
            
            if let routine = assignedRoutine {
                HStack {
                    Image(systemName: "dumbbell.fill").foregroundStyle(.blue).font(.caption)
                    Text(routine.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.gray.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Rest Day")
                    .font(.subheadline).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.gray.opacity(0.2))
                    )
            }
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
    }
}

struct DraggableRoutineCard: View {
    let routine: Routine
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(routine.name)
                .font(.subheadline).bold()
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text("\(routine.items.count) Exercises")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 140, alignment: .leading)
        .cardSurface(cornerRadius: 10, shadowed: true)
    }
}

