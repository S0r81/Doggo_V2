//
//  OnboardingView.swift
//  Doggo
//
//  Created by Sorest on 1/14/26.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) var modelContext
    // Bound to RootView's `isOnboarding` flag — set to false when the user finishes.
    @Binding var isOnboarding: Bool
    
    // Form State
    @State private var step = 0
    @State private var selectedProgramID: String?
    @State private var name = ""
    @State private var age = 25
    @State private var weight = 165 // lbs default
    @State private var height = 70 // inches default
    @State private var goal = "Build Muscle"
    @State private var experience = "Intermediate"
    @State private var activity = "Active"
    
    let goals = ["Build Muscle", "Lose Fat", "Strength", "Endurance", "General Health"]
    let levels = ["Beginner", "Intermediate", "Advanced"]
    let activities = ["Sedentary (Desk Job)", "Lightly Active", "Active", "Very Active (Athlete)"]
    
    var body: some View {
        VStack {
            // Progress Bar
            ProgressView(value: Double(step), total: 4)
                .padding()
            
            TabView(selection: $step) {
                // STEP 0: INTRO & NAME
                VStack(spacing: 20) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                    Text("Welcome to Doggo")
                        .font(.largeTitle).bold()
                    Text("Your personal AI Strength Coach.")
                        .foregroundStyle(.secondary)
                    
                    TextField("What's your name?", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .padding()
                        .padding(.top, 20)
                }
                .tag(0)
                
                // STEP 1: STATS
                Form {
                    Section(header: Text("The Basics")) {
                        Stepper("Age: \(age)", value: $age, in: 12...100)
                        
                        // Simple Imperial Inputs for now (can expand logic later)
                        HStack {
                            Text("Weight (lbs)")
                            Spacer()
                            TextField("165", value: $weight, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Height (in)")
                            Spacer()
                            TextField("70", value: $height, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section(header: Text("Experience")) {
                        Picker("Level", selection: $experience) {
                            ForEach(levels, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .tag(1)
                
                // STEP 2: GOALS
                Form {
                    Section(header: Text("What is your main goal?")) {
                        Picker("Goal", selection: $goal) {
                            ForEach(goals, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.inline)
                    }
                    
                    Section(header: Text("Activity Level")) {
                        Picker("Activity", selection: $activity) {
                            ForEach(activities, id: \.self) { Text($0) }
                        }
                    }
                }
                .tag(2)

                // STEP 3: PICK A PROGRAM (optional — Skip just finishes)
                Form {
                    Section {
                        Text("Start with a proven plan — routines and a weekly schedule, ready on day one. You can change or remove it anytime.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Pick your program")
                    }

                    Section {
                        ForEach(Array(recommendedPrograms.enumerated()), id: \.element.id) { index, program in
                            Button {
                                withAnimation(.snappy) {
                                    selectedProgramID = selectedProgramID == program.id ? nil : program.id
                                }
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        HStack(spacing: Spacing.xs) {
                                            Text(program.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            if index == 0 {
                                                Text("FOR YOU")
                                                    .font(.caption2).bold()
                                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundStyle(Color.accentColor)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Text("\(program.daysPerWeek) days/week · \(program.tagline)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedProgramID == program.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedProgramID == program.id ? Color.accentColor : Color.secondary.opacity(0.4))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("Skip to start with an empty slate — programs stay available on the Lift tab.")
                    }
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Navigation Buttons
            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .padding()
                }

                Spacer()

                if step == 3 && selectedProgramID == nil {
                    Button("Skip") { finishOnboarding() }
                        .padding(.trailing, 4)
                }

                Button(step == 3 ? "Finish" : "Next") {
                    if step < 3 {
                        withAnimation { step += 1 }
                    } else {
                        finishOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty && step == 0)
                .padding()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var recommendedPrograms: [ProgramDefinition] {
        ProgramCatalog.recommended(experience: experience, goal: goal)
    }

    func finishOnboarding() {
        // Convert Imperial to Metric for internal storage (optional, but cleaner)
        let weightKG = Double(weight) * UnitSystem.kilogramsPerPound
        let heightCM = Double(height) * 2.54

        let profile = UserProfile(
            name: name,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            activityLevel: activity,
            fitnessGoal: goal,
            experienceLevel: experience
        )

        modelContext.insert(profile)

        // Install the chosen program (profile must exist first so the
        // installer can write the weekly schedule)
        if let programID = selectedProgramID,
           let program = ProgramCatalog.all.first(where: { $0.id == programID }) {
            ProgramInstaller.install(program, replaceSchedule: true, context: modelContext)
        }

        isOnboarding = false
    }
}

