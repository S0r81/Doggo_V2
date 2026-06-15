//
//  ContentView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let container: AppContainer
    
    @State private var selectedTab = 0
    
    // MARK: - THEME FIX 1: Listen to the setting
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Tab 0: Dashboard
            DashboardView(container: container, selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 1: Routines
            RoutineListView(selectedTab: $selectedTab, container: container)
                .tabItem {
                    Label("Lift", systemImage: "dumbbell.fill")
                }
                .tag(1)
            
            // Tab 2: Active Workout
            ActiveWorkoutView(container: container)
                .tabItem {
                    Label("Workout", systemImage: "waveform.path.ecg")
                }
                .tag(2)

            // Tab 3: Progress
            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            // Tab 4: Peptides
            PeptideDashboardView(container: container)
                .tabItem {
                    Label("Peptides", systemImage: "syringe.fill")
                }
                .tag(4)

            // Tab 5: Nutrition / Diet
            NutritionTabView()
                .tabItem {
                    Label("Diet", systemImage: "fork.knife")
                }
                .tag(5)
        }
        // MARK: - THEME FIX 2: Apply Global Accent
        // Instead of .tint(.blue), we ask the theme for the color
        .tint(Color.accent(for: userTheme))
        
        // MARK: - THEME FIX 3: Force Dark Mode for Nordic
        // Nordic is a dark theme. If we don't force .dark, iOS renders black text on dark grey background (unreadable).
        .preferredColorScheme(userTheme == .light ? .light : .dark)
    }
}
