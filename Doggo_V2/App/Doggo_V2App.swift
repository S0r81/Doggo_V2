//
//  Doggo_V2App.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

@main
struct Doggo_V2App: App {
    // Theme storage
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    
    // Model Container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            Routine.self,
            RoutineItem.self,
            RoutineSetTemplate.self,
            AIGeneratedRoutine.self,
            UserProfile.self,
            BodyMeasurement.self,
            CustomProgram.self,
            PeptideProfile.self,
            PeptideSchedule.self,
            PeptideLog.self,
            NutritionProfile.self,
            NutritionCheckIn.self,
            DailyMacroLog.self,
            CoachContextItem.self,
            CoachMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(userTheme == .light ? .light : .dark)
                .tint(Color.accent(for: userTheme))
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    DataSeeder.seedExercises(context: context)
                    // Installs the foreground-presentation delegate for peptide
                    // dose reminders.
                    _ = PeptideNotificationManager.shared
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// Wraps a decoded program for Identifiable sheet presentation.
private struct PendingProgramImport: Identifiable {
    let id = UUID()
    let program: SharedProgram
}

// Root View - Handles onboarding check
struct RootView: View {
    @Environment(\.modelContext) var modelContext
    @Query var profiles: [UserProfile]

    @State private var isOnboarding = false
    @State private var container: AppContainer?
    @State private var pendingImport: PendingProgramImport?

    var body: some View {
        Group {
            if isOnboarding {
                OnboardingView(isOnboarding: $isOnboarding)
            } else if let container {
                ContentView(container: container)
                    .environment(\.appContainer, container)
            } else {
                ProgressView("Initializing...")
            }
        }
        .onAppear {
            // Check onboarding
            if profiles.isEmpty {
                isOnboarding = true
            }

            // Initialize container
            if container == nil {
                container = AppContainer(modelContext: modelContext)
            }
        }
        .onChange(of: profiles.isEmpty) { oldValue, newValue in
            if newValue {
                isOnboarding = true
            }
        }
        // Stage 2: catch doggov2://import/program?payload=… in any launch state.
        .onOpenURL { url in
            if let shared = ProgramShareManager.parse(url) {
                pendingImport = PendingProgramImport(program: shared)
            }
        }
        // Stage 3: preview + confirm before inserting.
        .sheet(item: $pendingImport) { pending in
            ProgramImportSheet(shared: pending.program, container: modelContext.container)
        }
    }
}
