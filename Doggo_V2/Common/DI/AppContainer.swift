import Foundation
import SwiftData

final class AppContainer {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Repositories
    
    lazy var workoutRepository: WorkoutRepositoryProtocol = {
        WorkoutRepository(modelContainer: modelContext.container)
    }()

    lazy var peptideRepository: PeptideRepositoryProtocol = {
        PeptideRepository(modelContainer: modelContext.container)
    }()
    
    // MARK: - Services

    /// Routes each request to the AI provider selected in Settings
    /// (Gemini / Claude / GPT), each with its own Keychain key.
    lazy var aiClient: AIClientProtocol = {
        AIClientRouter()
    }()
    
    lazy var hapticManager: HapticManager = {
        HapticManager.shared
    }()
    
    lazy var audioManager: AudioManager = {
        AudioManager.shared
    }()
    
    // MARK: - ViewModel Factories
    
    func makeActiveWorkoutViewModel() -> ActiveWorkoutViewModel {
        ActiveWorkoutViewModel(
            workoutRepository: workoutRepository,
            context: modelContext
        )
    }
    
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel()
    }
    
    func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(
            workoutRepository: workoutRepository,
            context: modelContext
        )
    }
}
