# 🐕 Doggo V2

A native iOS workout tracker with an AI coach. Log lifts fast, plan your week, and get personalized training advice from the AI provider of your choice — Gemini, Claude, GPT, or anything on OpenRouter.

Built with SwiftUI + SwiftData. No accounts, no servers — your data stays on your device, and your AI keys stay in your Keychain.

## Features

### 🏋️ Workout Logging
- Fast set entry with **wheel pickers or a numeric keypad** (toggle in Profile)
- **Ghost values** show last session's weight × reps for every set — tap the checkmark on an untouched set to log "same as last time" in one tap
- Supersets with visual grouping, exercise reordering, swap & collapse
- Cardio tracking by distance, steps, or time
- **Floating rest timer** with presets (1m / 1.5m / 2m), +30s, and skip
- **Live Activity**: rest countdown on the lock screen and Dynamic Island
- Finish confirmation with a session summary (duration · sets · volume) — and a discard option so empty sessions never pollute your history

### 🤖 AI Coach (bring your own key)
- **Multiple providers**: Google Gemini, Anthropic Claude, OpenAI GPT, and OpenRouter (with a configurable model slug — or `openrouter/auto`)
- **Two modes, one toggle** — switch the Coach between:
  - **Report** (default) — an on-demand, data-grounded analysis of your volume, consistency, and muscle split
  - **Chat** — a real conversational thread that persists across launches, with one-tap starters (*Reset my targets · Design a program · Plan my meals · Build a workout*) and free typing
- **"What Coach knows"** — a user-editable, persistent profile (Dietary · Injuries & Limits · Equipment · Schedule · Personal Goals · Other) injected into *every* Coach request, both modes, so it reasons from your context without being reminded
- **Smart set suggestions** — the wand icon fills in weight/reps based on your history and goal
- AI routine generation: name a routine ("Back and Biceps") and auto-fill it, or use the full builder with duration, equipment, and cardio constraints
- AI weekly schedule generation that respects your split preference
- Every request — report and chat — flows through one provider-agnostic client, so all four providers, Keychain keys, and error handling behave identically
- Each provider's API key is stored separately in the iOS Keychain

### 📋 Routines
- Build routines with per-set rep targets and superset links
- Rows show muscle focus, estimated duration, last performed, and scheduled days
- Long-press for **Start / Edit / Duplicate / Assign to Day / Delete**
- Routine preview sheet — see exactly what's inside before starting
- Weekly planner with drag-and-drop scheduling; today's plan surfaces on the Workout tab

### 📊 Progress
- Dashboard with paged consistency & volume charts, recent PRs, and muscle-focus donut
- Per-exercise progress charts (best per session) and full set history
- Exercise library with filter chips, search, favorites, recently-used, and inline PRs
- History grouped by month with search
- CSV export / import

### 🥗 Nutrition / Diet Planner
- Guided onboarding turns your weight, body-fat, sex, age, activity, and goal rate into personalized daily calorie + macro targets
- Macro math engine derived from a published fat-loss protocol (Norton & Hill, *Fat Loss Forever*) — BMR, deficit multipliers, protein targets, and rate-of-loss bands
- Daily macro logging with a quick-log sheet, plus a nutrition history view
- Stall detection and one-tap **reverse diet** when a cut plateaus

### 💉 Peptide Tracker
- **Reconstitution calculator** — enter vial amount, reconstitution volume, and target dose to get an exact "pull to X units" on the syringe
- Schedules by **daily**, **specific weekdays**, or **on/off cycles**, with local reminder notifications
- Dose logging with a syringe visual and a calendar that shows logged vs. scheduled days at a glance

### 🎨 Polish
- Four themes: Light, Dark, **Nordic**, and **Gruvbox**
- Haptics and sound throughout
- VoiceOver labels on controls and charts

## Getting Started

### Requirements
- Xcode 26+, iOS 17+

### Run in the Simulator
1. Clone, then create the (gitignored) base config from the template:
   ```sh
   cp Doggo_V2/Data/Networking/Secrets.example.xcconfig \
      Doggo_V2/Data/Networking/Secrets.xcconfig
   ```
   No keys needed in it — AI keys are entered in-app. The file just needs to exist.
2. Open `Doggo_V2.xcodeproj`
3. Select the `Doggo_V2` scheme, pick an iPhone simulator, and press **Run** (⌘R)

### Install on Your iPhone (free — no paid developer account needed)

You can sideload Doggo onto any iPhone with just a free Apple ID:

1. **Add your Apple ID to Xcode** — Xcode → Settings → Accounts → **+** → sign in with your Apple ID. This creates a free "Personal Team."
2. **Set the signing team** — select the project in the navigator → target **Doggo_V2** → *Signing & Capabilities* → check **Automatically manage signing** → choose your Personal Team. Repeat for the **DoggoWidgetExtension** target (it powers the rest-timer Live Activity).
3. **Make the bundle IDs yours** — Apple requires unique IDs per team. On both targets, change the Bundle Identifier prefix to something personal, e.g. `com.yourname.Doggo-V2` (the widget must keep the app's ID as its prefix: `com.yourname.Doggo-V2.DoggoWidget`).
4. **Enable Developer Mode on the phone** — Settings → Privacy & Security → **Developer Mode** → on → restart the phone. (This toggle only appears after you've attempted a run, or while the phone is plugged into a Mac with Xcode open.)
5. **Plug in your iPhone**, select it as the run destination in Xcode, and press **Run**. The first build to a new device takes a couple of minutes while Xcode prepares it.
6. **Trust your certificate** — the first launch will fail with *"Untrusted Developer."* On the phone: Settings → General → **VPN & Device Management** → under *Developer App*, tap your Apple ID → **Trust** → Allow. Launch the app again.

**Good to know:**
- With a free Apple ID the install **expires after 7 days** — the app stays on your phone but won't open. Just plug in and press Run again to re-sign it (your data is kept). A paid Apple Developer account ($99/yr) extends this to 1 year and removes the 3-app limit.
- If the build fails with a provisioning error, it's almost always step 2 or 3 — re-check both targets.

### AI Coach setup (optional)
In-app: Settings (gear icon) → AI Coach Configuration → pick a provider and paste your API key:
- Gemini — [aistudio.google.com](https://aistudio.google.com)
- Claude — [platform.claude.com](https://platform.claude.com)
- GPT — [platform.openai.com](https://platform.openai.com)
- OpenRouter — [openrouter.ai](https://openrouter.ai)

Everything except the AI features works fully offline with no key.

## Architecture

```
Doggo_V2/
├── App/            @main entry, root tab shell, onboarding gate, DI wiring
├── DesignSystem/   Theme (colors/spacing), reusable Components, Modifiers
├── Features/       One folder per screen — Views + ViewModels
│                   Dashboard · ActiveWorkout · Routines · ExerciseList ·
│                   History · Progress · Nutrition · Peptides · Profile · Onboarding
├── Domain/         Business core, no UIKit/SwiftUI
│   ├── Models/      SwiftData @Model entities (WorkoutSession, Exercise, Routine, …)
│   ├── Entities/    Plain value types & DTOs (AI payloads, WeeklyPlan, stats)
│   ├── Calculators/ Pure math — StrengthMath, PlateCalculator, ProgressionEngine, …
│   └── UseCases/    Workout + AI orchestration
├── Data/
│   ├── Repositories/ @ModelActor data access (value-in / Sendable-out)
│   ├── Networking/   One thin HTTP client per AI provider + Secrets.xcconfig
│   ├── ImportExport/ CSV import, data export, document picking
│   └── Persistence/  ModelContainer seeding, program catalog, save helpers
├── Services/       Cross-cutting runtime singletons — Keychain, notifications,
│                   haptics, audio, rest timer, sharing, Live Activity attributes
├── Common/         DI container, constants, protocols, extensions, formatters
├── Resources/      Assets.xcassets
└── DoggoWidget/    Live Activity extension (rest-timer countdown)
```

- **SwiftData** for persistence; writes funnel through `@ModelActor` repositories so no `@Model` ever crosses an actor boundary (value in, `Sendable` out).
- **Feature modules** are self-contained (Views + ViewModels), wired through an `AppContainer` for dependency injection.
- **Provider-agnostic AI layer**: prompts and parsers work on plain text, so each provider only needs a small HTTP client behind a shared `AIClientProtocol`; an `AIClientRouter` resolves the selected provider at request time, and a shared `AIClientSupport.execute` centralizes the `URLSession`, timeouts, and error mapping.

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for the layer boundaries, the repository pattern, and a step-by-step guide to adding a feature.

## Privacy

- Workout data never leaves the device (SwiftData, local only)
- API keys live in the iOS Keychain and are excluded from the repo and the app bundle
- AI requests send only workout summaries/prompts directly to the provider you configured — there is no middleman server
