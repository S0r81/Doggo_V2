# Architecture

Doggo is a single-module SwiftUI + SwiftData app (iOS 17+, Swift 6 strict
concurrency) with one app-extension target for the rest-timer Live Activity.
It follows a light Clean-Architecture split: a UI layer (`App`, `Features`,
`DesignSystem`), a business layer (`Domain`), and an infrastructure layer
(`Data`, `Services`). There is no backend — everything runs on-device, and the
only network calls are the user's own AI requests.

## Layers & dependency rules

```
App ─┬─► Features ─┬─► DesignSystem
     │             ├─► Domain
     │             └─► Services
     └─► Common (DI / constants / extensions)

Features ─► Data ─► Domain
Data ─► Services        Domain ─► (nothing app-specific; pure Swift + SwiftData)
```

The one rule worth enforcing in review:

- **`Domain` imports nothing from `Features`, `DesignSystem`, or `Data`.**
  Models, calculators, and entities are pure — they compile without SwiftUI.
  (This is why `AppFormatters`/`CardioFormatter` live in `Common/Formatters`,
  not `DesignSystem`: a `@Model` uses them, and Domain must not depend on the UI.)

Everything stays in one compilation unit, so these are conventions, not
module boundaries — but keeping them makes the code easy to extract into Swift
packages later.

## Folder map

| Folder | What goes here |
|---|---|
| `App/` | `@main`, the root tab shell, the onboarding gate, and DI wiring. |
| `DesignSystem/` | `Theme/` (colors, spacing, `AppTheme`), `Components/` (buttons, cards, charts, states), `Modifiers/`. The only home for reusable UI. |
| `Features/<Name>/` | A screen: `Views/`, `ViewModels/`, and feature-private `Components/`. |
| `Domain/Models/` | SwiftData `@Model` entities, grouped by area (Workout, Routine, Peptide, …). |
| `Domain/Entities/` | Plain `Sendable` value types & DTOs (AI request/response payloads, `WeeklyPlan`, stats). |
| `Domain/Calculators/` | Pure functions: `StrengthMath`, `PlateCalculator`, `MacroCalculator`, `ProgressionEngine`, `PlanTuner`, `ExerciseSanitizer`. |
| `Domain/UseCases/` | Orchestration that composes repositories + calculators + AI. |
| `Data/Repositories/` | `@ModelActor` data access (see below). |
| `Data/Networking/` | One thin HTTP client per AI provider, the shared executor, and `Secrets.xcconfig`. |
| `Data/ImportExport/` | CSV import, data export, document picking. |
| `Data/Persistence/` | Schema seeding, the bundled program catalog/installer, `ModelContext+Save`. |
| `Services/` | Cross-cutting runtime singletons (`Keychain`, notifications, haptics, audio, rest timer, sharing, Live Activity attributes). |
| `Common/` | DI container, constants (`UnitSystem`), protocols, small extensions, formatters. |
| `Resources/` | `Assets.xcassets`. |

## The repository pattern

Data access goes through `@ModelActor` repositories so `@Model` objects never
cross an actor boundary. Each method takes **values** in and returns
**`Sendable` snapshots or `PersistentIdentifier`s** out — never a live model.

```swift
@ModelActor
actor WorkoutRepository: WorkoutRepositoryProtocol {
    func importSessions(_ dtos: [SessionDTO]) throws { /* build @Model inside the actor */ }
    func delete(id: PersistentIdentifier) throws { /* fetch by id, delete */ }
}
```

UI that needs live objects still uses SwiftData's `@Query` / `mainContext`
directly (the main actor owns the view context); repositories are for the
heavier, off-the-main-actor mutations and imports. Saves go through
`ModelContext.saveLogging()` rather than `try? save()` so failures are logged.

## The AI layer

Adding or swapping an AI provider is deliberately cheap:

```
AIClientRouter           // resolves AIProvider.current → the right client
   └─ AIClientProtocol   // sendRequest(prompt:) async throws -> String
        ├─ GeminiAPIClient
        ├─ AnthropicAPIClient
        ├─ OpenAIAPIClient
        └─ OpenRouterAPIClient

AIClientSupport          // shared URLSession, key lookup, execute() + error mapping
APIError                 // LocalizedError: missingKey / invalidKey / rateLimited / providerError / parseError
```

Each client only builds a request and parses one field; `AIClientSupport.execute`
owns the connection, the 180s timeouts, and the HTTP→`APIError` mapping (including
reading the provider's error body so a 429 surfaces the real reason). Prompts and
parsers operate on plain text, so providers are interchangeable.

Keys are entered in-app (Settings → AI Coach) and stored **per provider** in the
Keychain via `KeychainManager`. Keys are never committed and never bundled.

## Adding a feature

1. Create `Features/<Name>/` with `Views/` (+ `ViewModels/` if it has state).
   Xcode picks it up automatically — the target uses a filesystem-synchronized
   group, so there is no `.pbxproj` editing for new files.
2. Read/write data with `@Query`/`@Environment(\.modelContext)` for live UI, or
   add a method to the relevant `@ModelActor` repository for heavy work.
3. Put any cross-screen UI in `DesignSystem/Components`; keep feature-only views
   under the feature folder.
4. Pure logic (formulas, transforms) goes in `Domain/Calculators` with a unit test.
5. Add the screen to the root tab/navigation in `App/`.

## Build configuration & secrets

The `Doggo_V2` target's base configuration is
`Data/Networking/Secrets.xcconfig`, which is **gitignored**. A fresh clone has no
copy, so:

```sh
cp Doggo_V2/Data/Networking/Secrets.example.xcconfig \
   Doggo_V2/Data/Networking/Secrets.xcconfig
```

You do not need to put keys in this file — enter them in-app (they go to the
Keychain). The file only needs to exist to satisfy the base-configuration
reference. See the example file for details.

## Concurrency & testing

- Swift 6 strict concurrency is on. Types that cross actors are `Sendable`;
  models stay inside their actor.
- Release builds compile `-O` with `SWIFT_COMPILATION_MODE = wholemodule`;
  Debug uses `-Onone` with testability enabled.
- Tests use the **Swift Testing** framework (`import Testing`, `@Test`,
  `#expect`). Run them with the `Doggo_V2` scheme on any iOS Simulator.
