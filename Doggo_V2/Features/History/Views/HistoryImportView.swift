//
//  HistoryImportView.swift
//  Doggo_V2
//
//  Created by Sorest on 2/5/26.
//


//
//  HistoryImportView.swift
//  Doggo
//
//  Created by Sorest on 1/19/26.
//

import SwiftUI
import SwiftData

struct HistoryImportView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query var allExercises: [Exercise]
    
    @State private var isProcessing = false
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    
    // Use the new CSV models
    @State private var importedSessions: [CSVImporter.ImportedSession] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    ProgressView("Parsing CSV...").scaleEffect(1.2)
                } else if !importedSessions.isEmpty {
                    reviewList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Import History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if !importedSessions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Import \(importedSessions.count)") { saveAll() }
                            .bold()
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in handleFileSelection(url) }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    var reviewList: some View {
        List {
            ForEach(importedSessions) { session in
                Section(header: HStack {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted)).bold()
                    Spacer()
                    Text(session.name).foregroundStyle(.secondary)
                }) {
                    ForEach(session.exercises) { ex in
                        HStack {
                            Text(ex.name).font(.headline)
                            Spacer()
                            Text("\(ex.sets.count) sets")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Import CSV Log").font(.title2).bold()
            Text("Select a 'Doggo_Workouts.csv' file to restore your history.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            
            Button("Select CSV File") { showFilePicker = true }
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
    }
    
    func handleFileSelection(_ url: URL) {
        print("▶️ Processing CSV: \(url)")
        isProcessing = true
        
        // 1. Extract Text
        guard let text = TextExtractor.extractText(from: url) else {
            errorMessage = "Could not read file."
            isProcessing = false
            return
        }
        
        // 2. Parse Deterministically (No AI)
        // Run on background thread to prevent UI freeze for large files
        DispatchQueue.global(qos: .userInitiated).async {
            let sessions = CSVImporter.parseCSV(from: text)
            
            DispatchQueue.main.async {
                print("✅ Parsed \(sessions.count) sessions from CSV")
                self.importedSessions = sessions
                self.isProcessing = false
                
                if sessions.isEmpty {
                    self.errorMessage = "No valid workout sessions found in this CSV."
                }
            }
        }
    }
    
    func saveAll() {
            for session in importedSessions {
                // 1. Create Session
                let newSession = WorkoutSession()
                newSession.date = session.date
                newSession.name = session.name
                newSession.duration = session.duration
                newSession.isCompleted = true // <--- CRITICAL FIX: Marks it as a "Past" workout
                
                modelContext.insert(newSession)
                
                var orderIndex = 0
                
                for exData in session.exercises {
                    // 2. Resolve Exercise
                    let exercise: Exercise
                    // Try exact match
                    if let match = allExercises.first(where: { $0.name.lowercased() == exData.name.lowercased() }) {
                        exercise = match
                    } else {
                        // Create New if not found
                        let newEx = Exercise(name: exData.name)
                        // Infer type based on data (heuristic)
                        if let firstSet = exData.sets.first, firstSet.distance != nil {
                            newEx.type = "Cardio"
                        }
                        modelContext.insert(newEx)
                        exercise = newEx
                    }
                    
                    // 3. Create Sets
                    for setData in exData.sets {
                        
                        let newSet = WorkoutSet(
                            weight: setData.weight,
                            reps: Int(setData.reps),
                            orderIndex: orderIndex,
                            unit: setData.unit
                        )
                        
                        // Handle Cardio Fields
                        if let dist = setData.distance { newSet.distance = dist }
                        if let time = setData.time { newSet.duration = time }
                        
                        newSet.exercise = exercise
                        newSet.workoutSession = newSession
                        
                        // CRITICAL FIX: Mark sets as completed too, or they might look "unchecked"
                        newSet.isCompleted = true
                        
                        modelContext.insert(newSet)
                        
                        orderIndex += 1
                    }
                }
            }
            dismiss()
        }
}
