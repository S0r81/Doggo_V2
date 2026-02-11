//
//  ContentView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let container: AppContainer
    
    @State private var selectedTab = 0
    
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
        }
        .tint(.blue)
    }
}
