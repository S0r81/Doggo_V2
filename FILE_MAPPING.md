# File Mapping: Old Doggo → New Doggo_V2

## How to Use This Guide
1. Find the file you want to migrate in the "Old Location" column
2. Copy its contents
3. Paste into the corresponding "New Location"
4. Refactor as needed
5. Test
6. Move to next file

---

## Models

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Core/Models/WorkoutSession.swift` | `Doggo_V2/Core/Domain/Models/Workout/WorkoutSession.swift` | Just copy |
| `Doggo/Core/Models/WorkoutSet.swift` | `Doggo_V2/Core/Domain/Models/Workout/WorkoutSet.swift` | Just copy |
| `Doggo/Core/Models/Exercise.swift` | `Doggo_V2/Core/Domain/Models/Workout/Exercise.swift` | Just copy |
| `Doggo/Core/Models/Routine.swift` | `Doggo_V2/Core/Domain/Models/Routine/Routine.swift` | Just copy |
| `Doggo/Core/Models/RoutineItem.swift` | `Doggo_V2/Core/Domain/Models/Routine/RoutineItem.swift` | Just copy |
| `Doggo/Core/Models/RoutineSetTemplate.swift` | `Doggo_V2/Core/Domain/Models/Routine/RoutineSetTemplate.swift` | Just copy |
| `Doggo/Core/Models/UserProfile.swift` | `Doggo_V2/Core/Domain/Models/User/UserProfile.swift` | Just copy |
| `Doggo/Core/Models/AIGeneratedRoutine.swift` | `Doggo_V2/Core/Domain/Models/AI/AIGeneratedRoutine.swift` | Just copy |
| `Doggo/Core/Models/UnitSystem.swift` | `Doggo_V2/Core/Common/Constants/UnitSystem.swift` | Move to Constants |

---

## Extensions

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Core/Extensions/Color+Theme.swift` | `Doggo_V2/Core/Common/Extensions/Color+Theme.swift` | Just copy |
| `Doggo/Core/Extensions/Date+Extensions.swift` | `Doggo_V2/Core/Common/Extensions/Date+Extensions.swift` | Just copy |
| `Doggo/Core/Extensions/View+Theme.swift` | `Doggo_V2/Core/Common/Extensions/View+Extensions.swift` | Just copy |

---

## Utilities

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Core/Utilities/HapticManager.swift` | `Doggo_V2/Core/Common/Utilities/UI/HapticManager.swift` | Just copy |
| `Doggo/Core/Utilities/AudioManager.swift` | `Doggo_V2/Core/Common/Utilities/UI/AudioManager.swift` | Just copy |
| `Doggo/Core/Utilities/CSVImporter.swift` | `Doggo_V2/Core/Common/Utilities/Import/CSVImporter.swift` | Just copy |
| `Doggo/Core/Utilities/TextExtractor.swift` | `Doggo_V2/Core/Common/Utilities/Import/TextExtractor.swift` | Just copy |
| `Doggo/Core/Utilities/DocumentPicker.swift` | `Doggo_V2/Core/Common/Utilities/Import/DocumentPicker.swift` | Just copy |
| `Doggo/Core/Utilities/DataExporter.swift` | `Doggo_V2/Core/Common/Utilities/Export/DataExporter.swift` | Just copy |
| `Doggo/Core/Utilities/DataSeeder.swift` | `Doggo_V2/Core/Data/Persistence/DataSeeder.swift` | Just copy |

---

## GeminiManager → Split Into 3 Files

| Old Code Section | New Location | What to Copy |
|------------------|--------------|--------------|
| HTTP request logic | `Doggo_V2/Core/Data/Network/AIService/GeminiAPIClient.swift` | Just the `sendRequest()` method |
| Prompt building | `Doggo_V2/Core/Data/Network/AIService/GeminiPromptBuilder.swift` | All prompt construction logic |
| JSON parsing | `Doggo_V2/Core/Data/Network/AIService/GeminiResponseParser.swift` | All parsing methods |

---

## Features - ActiveWorkout

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/ActiveWorkout/ActiveWorkoutViewModel.swift` | `Doggo_V2/Features/ActiveWorkout/ViewModels/ActiveWorkoutViewModel.swift` | Refactor to use repositories |
| `Doggo/Features/ActiveWorkout/ActiveWorkoutView.swift` | `Doggo_V2/Features/ActiveWorkout/Views/ActiveWorkoutView.swift` | Just copy |
| `Doggo/Features/ActiveWorkout/Components/SetRowView.swift` | `Doggo_V2/Features/ActiveWorkout/Components/SetRowView.swift` | Just copy |
| `Doggo/Features/ActiveWorkout/Components/RestTimerView.swift` | `Doggo_V2/Features/ActiveWorkout/Components/RestTimerView.swift` | Just copy |

---

## Features - Dashboard

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/Dashboard/DashboardView.swift` | Multiple files | See extraction guide below |
| `Doggo/Features/Dashboard/WeeklyPlannerView.swift` | `Doggo_V2/Features/Dashboard/Views/WeeklyPlannerView.swift` | Just copy |

### Dashboard Extraction:
- **DashboardView main logic** → `Features/Dashboard/Views/DashboardView.swift`
- **StatCard struct** → `Shared/Components/Cards/StatCard.swift`
- **QuickActionButton struct** → `Shared/Components/Buttons/QuickActionButton.swift`
- **WorkoutFocusCard struct** → `Shared/Components/Cards/WorkoutFocusCard.swift`
- **LastWorkoutHero struct** → `Shared/Components/Cards/LastWorkoutHero.swift`
- **Analytics logic** → Create `Features/Dashboard/ViewModels/DashboardViewModel.swift`

---

## Features - History

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/History/HistoryView.swift` | `Doggo_V2/Features/History/Views/HistoryView.swift` | Extract logic to ViewModel |
| `Doggo/Features/History/WorkoutDetailView.swift` | `Doggo_V2/Features/History/Views/WorkoutDetailView.swift` | Just copy |
| `Doggo/Features/History/ExerciseAnalyticsView.swift` | `Doggo_V2/Features/History/Views/ExerciseAnalyticsView.swift` | Just copy |

---

## Features - Routines

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/Lift/RoutineListView.swift` | `Doggo_V2/Features/Routines/Views/RoutineListView.swift` | Just copy |
| `Doggo/Features/Lift/RoutineCreationView.swift` | `Doggo_V2/Features/Routines/Views/RoutineCreationView.swift` | Just copy |
| `Doggo/Features/Lift/RoutineGeneratorView.swift` | `Doggo_V2/Features/Routines/Views/RoutineGeneratorView.swift` | Update AI service usage |
| `Doggo/Features/Lift/RoutineImportView.swift` | `Doggo_V2/Features/Routines/Views/RoutineImportView.swift` | Just copy |

---

## Features - ExerciseList

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/ExerciseList/ExerciseListView.swift` | `Doggo_V2/Features/ExerciseList/Views/ExerciseListView.swift` | Just copy |
| `Doggo/Features/ExerciseList/ExerciseCreationView.swift` | `Doggo_V2/Features/ExerciseList/Views/ExerciseCreationView.swift` | Just copy |
| `Doggo/Features/ExerciseList/CoachView.swift` | `Doggo_V2/Features/ExerciseList/Views/CoachView.swift` | Update AI service usage |

---

## Features - Profile

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/Profile/ProfileSettingsView.swift` | `Doggo_V2/Features/Profile/Views/ProfileSettingsView.swift` | Just copy |

---

## Features - Onboarding

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `Doggo/Features/Onboarding/OnboardingView.swift` | `Doggo_V2/Features/Onboarding/Views/OnboardingView.swift` | Just copy |

---

## New Files to Create (Don't exist in old project)

These are NEW files that improve architecture:

### Repositories (Extract from ViewModels)
- `Core/Data/Repositories/WorkoutRepository.swift` - Extract SwiftData queries from ViewModels
- `Core/Data/Repositories/RoutineRepository.swift` - Extract routine queries
- `Core/Data/Repositories/ExerciseRepository.swift` - Extract exercise queries
- `Core/Data/Repositories/UserRepository.swift` - Extract user queries

### ViewModels (Extract from Views)
- `Features/Dashboard/ViewModels/DashboardViewModel.swift` - Extract from DashboardView
- `Features/History/ViewModels/HistoryViewModel.swift` - Extract from HistoryView
- `Features/ExerciseList/ViewModels/ExerciseListViewModel.swift` - Extract from ExerciseListView
- `Features/Routines/ViewModels/RoutineListViewModel.swift` - Extract from RoutineListView

### DI Container
- `Core/Common/DI/AppContainer.swift` - Centralize dependency injection

### Settings Manager
- `Core/Data/Persistence/UserDefaultsManager.swift` - Centralize all UserDefaults

---

## Migration Order (Suggested)

1. ✅ Models (just copy)
2. ✅ Extensions (just copy)
3. ✅ Utilities (just copy)
4. ✅ Shared components (extract from DashboardView)
5. ✅ Create repositories
6. ✅ Split GeminiManager
7. ✅ Migrate features one by one
8. ✅ Wire up DI container
9. ✅ Test thoroughly

