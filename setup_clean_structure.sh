#!/bin/bash

################################################################################
# Doggo_V2 Clean Architecture Setup (Structure Only)
# 
# This script creates the folder structure and empty files.
# You'll copy code from old Doggo → new Doggo_V2 yourself.
#
# Run from: Doggo_V2/ directory (parent of Doggo_V2.xcodeproj)
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check we're in the right place
if [ ! -d "Doggo_V2.xcodeproj" ]; then
    print_error "Doggo_V2.xcodeproj not found!"
    print_info "Please run this from the Doggo_V2 directory"
    exit 1
fi

print_header "🏗️  Creating Clean Architecture Structure"
echo ""
print_info "Building in: Doggo_V2/"
echo ""

cd Doggo_V2

################################################################################
# Create Directory Structure
################################################################################

print_warning "Creating directories..."

# App layer
mkdir -p "App"

# Core layers
mkdir -p "Core/Domain/Models/Workout"
mkdir -p "Core/Domain/Models/Routine"
mkdir -p "Core/Domain/Models/User"
mkdir -p "Core/Domain/Models/AI"
mkdir -p "Core/Domain/UseCases/Workout"
mkdir -p "Core/Domain/UseCases/AI"
mkdir -p "Core/Domain/UseCases/Analytics"
mkdir -p "Core/Domain/Entities"

mkdir -p "Core/Data/Repositories"
mkdir -p "Core/Data/Network/AIService"
mkdir -p "Core/Data/Persistence"

mkdir -p "Core/Common/Extensions"
mkdir -p "Core/Common/Utilities/UI"
mkdir -p "Core/Common/Utilities/Import"
mkdir -p "Core/Common/Utilities/Export"
mkdir -p "Core/Common/Protocols"
mkdir -p "Core/Common/Constants"
mkdir -p "Core/Common/DI"

# Features
mkdir -p "Features/ActiveWorkout/ViewModels"
mkdir -p "Features/ActiveWorkout/Views"
mkdir -p "Features/ActiveWorkout/Components"

mkdir -p "Features/Dashboard/ViewModels"
mkdir -p "Features/Dashboard/Views"
mkdir -p "Features/Dashboard/Components"

mkdir -p "Features/ExerciseList/ViewModels"
mkdir -p "Features/ExerciseList/Views"

mkdir -p "Features/History/ViewModels"
mkdir -p "Features/History/Views"

mkdir -p "Features/Routines/ViewModels"
mkdir -p "Features/Routines/Views"
mkdir -p "Features/Routines/Components"

mkdir -p "Features/Profile/Views"

mkdir -p "Features/Onboarding/Views"

# Shared
mkdir -p "Shared/Components/Buttons"
mkdir -p "Shared/Components/Cards"
mkdir -p "Shared/Components/Charts"
mkdir -p "Shared/Components/States"
mkdir -p "Shared/Modifiers"

print_success "Directories created!"
echo ""

################################################################################
# Create Empty Files
################################################################################

print_warning "Creating empty files..."

# Move existing files to App
mv Doggo_V2App.swift App/ 2>/dev/null || true
mv ContentView.swift App/ 2>/dev/null || true
mv Item.swift Core/Domain/Models/ 2>/dev/null || true

# App
touch "App/RootView.swift"

# Models
touch "Core/Domain/Models/Workout/WorkoutSession.swift"
touch "Core/Domain/Models/Workout/WorkoutSet.swift"
touch "Core/Domain/Models/Workout/Exercise.swift"
touch "Core/Domain/Models/Routine/Routine.swift"
touch "Core/Domain/Models/Routine/RoutineItem.swift"
touch "Core/Domain/Models/Routine/RoutineSetTemplate.swift"
touch "Core/Domain/Models/User/UserProfile.swift"
touch "Core/Domain/Models/AI/AIGeneratedRoutine.swift"

# UseCases
touch "Core/Domain/UseCases/Workout/StartWorkoutUseCase.swift"
touch "Core/Domain/UseCases/Workout/CompleteSetUseCase.swift"
touch "Core/Domain/UseCases/AI/GenerateRoutineUseCase.swift"
touch "Core/Domain/UseCases/AI/AnalyzeWorkoutUseCase.swift"

# Entities
touch "Core/Domain/Entities/SetSuggestion.swift"
touch "Core/Domain/Entities/WorkoutStats.swift"

# Repositories
touch "Core/Data/Repositories/WorkoutRepository.swift"
touch "Core/Data/Repositories/RoutineRepository.swift"
touch "Core/Data/Repositories/ExerciseRepository.swift"
touch "Core/Data/Repositories/UserRepository.swift"

# AI Service
touch "Core/Data/Network/AIService/GeminiAPIClient.swift"
touch "Core/Data/Network/AIService/GeminiPromptBuilder.swift"
touch "Core/Data/Network/AIService/GeminiResponseParser.swift"

# Persistence
touch "Core/Data/Persistence/DataSeeder.swift"
touch "Core/Data/Persistence/UserDefaultsManager.swift"

# Extensions
touch "Core/Common/Extensions/Color+Theme.swift"
touch "Core/Common/Extensions/Date+Extensions.swift"
touch "Core/Common/Extensions/View+Extensions.swift"

# Utilities
touch "Core/Common/Utilities/UI/HapticManager.swift"
touch "Core/Common/Utilities/UI/AudioManager.swift"
touch "Core/Common/Utilities/Import/CSVImporter.swift"
touch "Core/Common/Utilities/Import/TextExtractor.swift"
touch "Core/Common/Utilities/Import/DocumentPicker.swift"
touch "Core/Common/Utilities/Export/DataExporter.swift"

# Protocols
touch "Core/Common/Protocols/Repository.swift"
touch "Core/Common/Protocols/UseCase.swift"

# Constants
touch "Core/Common/Constants/AppConstants.swift"
touch "Core/Common/Constants/UnitSystem.swift"

# DI
touch "Core/Common/DI/AppContainer.swift"

# Feature: ActiveWorkout
touch "Features/ActiveWorkout/ViewModels/ActiveWorkoutViewModel.swift"
touch "Features/ActiveWorkout/Views/ActiveWorkoutView.swift"
touch "Features/ActiveWorkout/Components/SetRowView.swift"
touch "Features/ActiveWorkout/Components/CardioSetRowView.swift"
touch "Features/ActiveWorkout/Components/RestTimerView.swift"

# Feature: Dashboard
touch "Features/Dashboard/ViewModels/DashboardViewModel.swift"
touch "Features/Dashboard/Views/DashboardView.swift"
touch "Features/Dashboard/Views/WeeklyPlannerView.swift"

# Feature: ExerciseList
touch "Features/ExerciseList/ViewModels/ExerciseListViewModel.swift"
touch "Features/ExerciseList/Views/ExerciseListView.swift"
touch "Features/ExerciseList/Views/ExerciseCreationView.swift"
touch "Features/ExerciseList/Views/ExerciseDetailView.swift"
touch "Features/ExerciseList/Views/CoachView.swift"

# Feature: History
touch "Features/History/ViewModels/HistoryViewModel.swift"
touch "Features/History/Views/HistoryView.swift"
touch "Features/History/Views/WorkoutDetailView.swift"
touch "Features/History/Views/ExerciseAnalyticsView.swift"

# Feature: Routines
touch "Features/Routines/ViewModels/RoutineListViewModel.swift"
touch "Features/Routines/Views/RoutineListView.swift"
touch "Features/Routines/Views/RoutineCreationView.swift"
touch "Features/Routines/Views/RoutineGeneratorView.swift"
touch "Features/Routines/Views/RoutineImportView.swift"

# Feature: Profile
touch "Features/Profile/Views/ProfileSettingsView.swift"

# Feature: Onboarding
touch "Features/Onboarding/Views/OnboardingView.swift"

# Shared Components
touch "Shared/Components/Buttons/PrimaryButton.swift"
touch "Shared/Components/Buttons/QuickActionButton.swift"
touch "Shared/Components/Cards/StatCard.swift"
touch "Shared/Components/Cards/WorkoutFocusCard.swift"
touch "Shared/Components/Cards/LastWorkoutHero.swift"
touch "Shared/Components/Charts/ConsistencyChart.swift"
touch "Shared/Components/Charts/VolumeChart.swift"
touch "Shared/Components/States/LoadingView.swift"
touch "Shared/Components/States/EmptyStateView.swift"
touch "Shared/Components/States/ErrorView.swift"

# Modifiers
touch "Shared/Modifiers/CardStyle.swift"
touch "Shared/Modifiers/ThemedBackground.swift"

print_success "Empty files created!"
echo ""

################################################################################
# Create Documentation
################################################################################

print_warning "Creating documentation..."

cat > "../FILE_MAPPING.md" << 'EOF'
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

EOF

cat > "../STRUCTURE.txt" << 'EOF'
Doggo_V2/
├── App/
│   ├── Doggo_V2App.swift           # Entry point
│   ├── ContentView.swift           # (generated by Xcode)
│   └── RootView.swift              # Main tab navigation
│
├── Core/
│   ├── Domain/                     # Business Logic
│   │   ├── Models/
│   │   │   ├── Workout/
│   │   │   │   ├── WorkoutSession.swift
│   │   │   │   ├── WorkoutSet.swift
│   │   │   │   └── Exercise.swift
│   │   │   ├── Routine/
│   │   │   │   ├── Routine.swift
│   │   │   │   ├── RoutineItem.swift
│   │   │   │   └── RoutineSetTemplate.swift
│   │   │   ├── User/
│   │   │   │   └── UserProfile.swift
│   │   │   └── AI/
│   │   │       └── AIGeneratedRoutine.swift
│   │   ├── UseCases/
│   │   │   ├── Workout/
│   │   │   │   ├── StartWorkoutUseCase.swift
│   │   │   │   └── CompleteSetUseCase.swift
│   │   │   ├── AI/
│   │   │   │   ├── GenerateRoutineUseCase.swift
│   │   │   │   └── AnalyzeWorkoutUseCase.swift
│   │   │   └── Analytics/
│   │   └── Entities/
│   │       ├── SetSuggestion.swift
│   │       └── WorkoutStats.swift
│   │
│   ├── Data/                       # Data Access
│   │   ├── Repositories/
│   │   │   ├── WorkoutRepository.swift
│   │   │   ├── RoutineRepository.swift
│   │   │   ├── ExerciseRepository.swift
│   │   │   └── UserRepository.swift
│   │   ├── Network/
│   │   │   └── AIService/
│   │   │       ├── GeminiAPIClient.swift
│   │   │       ├── GeminiPromptBuilder.swift
│   │   │       └── GeminiResponseParser.swift
│   │   └── Persistence/
│   │       ├── DataSeeder.swift
│   │       └── UserDefaultsManager.swift
│   │
│   └── Common/                     # Shared Code
│       ├── Extensions/
│       │   ├── Color+Theme.swift
│       │   ├── Date+Extensions.swift
│       │   └── View+Extensions.swift
│       ├── Utilities/
│       │   ├── UI/
│       │   │   ├── HapticManager.swift
│       │   │   └── AudioManager.swift
│       │   ├── Import/
│       │   │   ├── CSVImporter.swift
│       │   │   ├── TextExtractor.swift
│       │   │   └── DocumentPicker.swift
│       │   └── Export/
│       │       └── DataExporter.swift
│       ├── Protocols/
│       │   ├── Repository.swift
│       │   └── UseCase.swift
│       ├── Constants/
│       │   ├── AppConstants.swift
│       │   └── UnitSystem.swift
│       └── DI/
│           └── AppContainer.swift
│
├── Features/                       # Feature Modules
│   ├── ActiveWorkout/
│   │   ├── ViewModels/
│   │   │   └── ActiveWorkoutViewModel.swift
│   │   ├── Views/
│   │   │   └── ActiveWorkoutView.swift
│   │   └── Components/
│   │       ├── SetRowView.swift
│   │       ├── CardioSetRowView.swift
│   │       └── RestTimerView.swift
│   │
│   ├── Dashboard/
│   │   ├── ViewModels/
│   │   │   └── DashboardViewModel.swift
│   │   ├── Views/
│   │   │   ├── DashboardView.swift
│   │   │   └── WeeklyPlannerView.swift
│   │   └── Components/
│   │
│   ├── ExerciseList/
│   │   ├── ViewModels/
│   │   │   └── ExerciseListViewModel.swift
│   │   └── Views/
│   │       ├── ExerciseListView.swift
│   │       ├── ExerciseCreationView.swift
│   │       ├── ExerciseDetailView.swift
│   │       └── CoachView.swift
│   │
│   ├── History/
│   │   ├── ViewModels/
│   │   │   └── HistoryViewModel.swift
│   │   └── Views/
│   │       ├── HistoryView.swift
│   │       ├── WorkoutDetailView.swift
│   │       └── ExerciseAnalyticsView.swift
│   │
│   ├── Routines/
│   │   ├── ViewModels/
│   │   │   └── RoutineListViewModel.swift
│   │   ├── Views/
│   │   │   ├── RoutineListView.swift
│   │   │   ├── RoutineCreationView.swift
│   │   │   ├── RoutineGeneratorView.swift
│   │   │   └── RoutineImportView.swift
│   │   └── Components/
│   │
│   ├── Profile/
│   │   └── Views/
│   │       └── ProfileSettingsView.swift
│   │
│   └── Onboarding/
│       └── Views/
│           └── OnboardingView.swift
│
└── Shared/                         # Reusable UI
    ├── Components/
    │   ├── Buttons/
    │   │   ├── PrimaryButton.swift
    │   │   └── QuickActionButton.swift
    │   ├── Cards/
    │   │   ├── StatCard.swift
    │   │   ├── WorkoutFocusCard.swift
    │   │   └── LastWorkoutHero.swift
    │   ├── Charts/
    │   │   ├── ConsistencyChart.swift
    │   │   └── VolumeChart.swift
    │   └── States/
    │       ├── LoadingView.swift
    │       ├── EmptyStateView.swift
    │       └── ErrorView.swift
    └── Modifiers/
        ├── CardStyle.swift
        └── ThemedBackground.swift

Total Files: ~80 Swift files
EOF

print_success "Created FILE_MAPPING.md"
print_success "Created STRUCTURE.txt"

################################################################################
# Summary
################################################################################

cd ..

print_header "✅ Structure Created!"
echo ""
print_success "Clean architecture ready in: Doggo_V2/"
print_success "File mapping created: FILE_MAPPING.md"
print_success "Structure reference: STRUCTURE.txt"
echo ""
print_info "Next Steps:"
echo "  1. Open Xcode project"
echo "  2. Add new folders to project:"
echo "     • Right-click 'Doggo_V2' group"
echo "     • File → Add Files to 'Doggo_V2'"
echo "     • Select: App/, Core/, Features/, Shared/"
echo "     • Uncheck 'Copy items if needed'"
echo "  3. Use FILE_MAPPING.md to copy files"
echo "  4. Start with models (easiest)"
echo ""
print_warning "All files are empty - ready for you to populate!"
echo ""
print_success "Ready to migrate! 🚀"
EOF
