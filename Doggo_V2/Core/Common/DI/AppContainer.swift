import Foundation
import SwiftData

final class AppContainer {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // MARK: - API Key Migration
        // If Keychain is empty, try to migrate the legacy hardcoded key
        if KeychainManager.shared.retrieveKey() == nil {
            if let legacyKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String, !legacyKey.isEmpty {
                print("🔑 Migrating legacy API Key to Keychain...")
                KeychainManager.shared.save(key: legacyKey)
            }
        }
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
