//
//  DashboardView.swift
//  Doggo_V2
//
//  Created by Sorest on 1/5/26.
//  Updated for Clean Architecture: 2026
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    let container: AppContainer
    @Binding var selectedTab: Int
    
    @State private var showCoach = false
    @State private var viewModel = DashboardViewModel()
    @State private var showFocusDetail = false
    @State private var showPlanner = false
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    
    // Sheets
    @State private var showSettings = false
    @State private var showProfile = false
    
    // Tab States for Paging
    @State private var consistencyPage: Int = 4 // Default to last (current week)
    @State private var volumePage: Int = 2      // Default to last (current month)
    
    // Fetch History
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var recentSessions: [WorkoutSession]
    
    @Query var profiles: [UserProfile]
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    quickActionsView
                    statsGridView
                    
                    // SWIPABLE CHARTS
                    weeklyConsistencyView
                    volumeTrendView
                    
                    recentBestsView
                    workoutFocusView
                    lastWorkoutView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            
            // Sheets
            .sheet(isPresented: $showSettings) {
                AppSettingsView().presentationDetents([.medium])
            }
            .sheet(isPresented: $showCoach) {
                CoachView(container: container, sessions: Array(recentSessions.prefix(30)))
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showProfile) {
                if let user = profiles.first {
                    ProfileSettingsView(profile: user)
                } else {
                    ContentUnavailableView("Profile Error", systemImage: "exclamationmark.triangle")
                }
            }
            .sheet(isPresented: $showPlanner) {
                WeeklyPlannerView(container: container)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
    
    // MARK: - Sub-Views
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let name = profiles.first?.name {
                    Text("\(viewModel.greetingMessage), \(name)".uppercased())
                        .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                } else {
                    Text(viewModel.greetingMessage.uppercased())
                        .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                }
                
                Text("Let's get to work.")
                    .font(.title).bold()
            }
            Spacer()
            
            Button(action: { showProfile = true }) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var quickActionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: { selectedTab = 2 }) {
                    QuickActionButton(title: "Log Workout", icon: "plus", color: .blue)
                }
                
                Button(action: { selectedTab = 1 }) {
                    QuickActionButton(title: "New Routine", icon: "list.bullet.clipboard", color: .purple)
                }
                
                Button(action: { showCoach = true }) {
                    QuickActionButton(title: "AI Coach", icon: "brain.head.profile", color: .orange)
                }
                
                Button(action: { showPlanner = true }) {
                    QuickActionButton(title: "Plan Week", icon: "calendar.badge.clock", color: .teal)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var statsGridView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            StatCard(title: "Workouts", value: "\(recentSessions.count)", icon: "dumbbell.fill", color: .blue)
            StatCard(title: "Volume", value: viewModel.getTotalVolume(from: recentSessions, preferredUnit: unitSystem.rawValue), icon: "chart.bar.fill", color: .green)
            StatCard(title: "Time", value: viewModel.getTotalDuration(from: recentSessions), icon: "clock.fill", color: .orange)
            StatCard(title: "Streak", value: "\(viewModel.getCurrentStreak(from: recentSessions)) Days", icon: "flame.fill", color: .red)
        }
        .padding(.horizontal)
    }
    
    // MARK: - PAGED Consistency Chart
    private var weeklyConsistencyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency").font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            let pages = viewModel.getConsistencyPages(from: recentSessions)
            
            if pages.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
            } else {
                TabView(selection: $consistencyPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading) {
                            Text(page.label)
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                            
                            Chart {
                                ForEach(page.days) { day in
                                    BarMark(
                                        x: .value("Day", day.day),
                                        y: .value("Workouts", day.count)
                                    )
                                    .foregroundStyle(LinearGradient(colors: day.count > 0 ? [.blue, .purple] : [.gray.opacity(0.2)], startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(6)
                                }
                            }
                            .chartYAxis(.hidden)
                        }
                        .padding()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 160)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - PAGED Volume Chart
    private var volumeTrendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                Text("Volume Trend")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            let pages = viewModel.getVolumePages(from: recentSessions)
            
            if pages.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
                    .frame(height: 150)
            } else {
                TabView(selection: $volumePage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading) {
                            Text(page.label)
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                            
                            Chart {
                                ForEach(page.weeks) { item in
                                    LineMark(
                                        x: .value("Week", item.weekLabel),
                                        y: .value("Volume", item.volume)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .symbol(Circle())
                                    .foregroundStyle(Color.green)
                                    
                                    AreaMark(
                                        x: .value("Week", item.weekLabel),
                                        y: .value("Volume", item.volume)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let vol = value.as(Double.self) {
                                            Text("\(Int(vol / 1000))k")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 200)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var recentBestsView: some View {
        if !recentSessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Heavy Lifts").font(.headline).padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.getRecentBests(from: recentSessions)) { best in
                            if let exercise = best.exercise {
                                NavigationLink(destination: ExerciseAnalyticsView(exercise: exercise)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                                            Text(best.exerciseName).font(.subheadline).bold().lineLimit(1)
                                        }
                                        Text("\(Int(best.weight)) \(best.unit)")
                                            .font(.title2).bold().monospacedDigit()
                                        Text(best.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .frame(width: 160)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var workoutFocusView: some View {
        WorkoutFocusCard(data: viewModel.getTopExercises(from: recentSessions))
    }
    
    private var lastWorkoutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Session").font(.headline)
                Spacer()
                NavigationLink(destination: HistoryView(container: container)) {
                    Text("History >").font(.subheadline).foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            
            if let last = recentSessions.first {
                NavigationLink(destination: WorkoutDetailView(session: last)) {
                    LastWorkoutHero(session: last)
                }
            } else {
                ContentUnavailableView("Start your journey", systemImage: "figure.run")
            }
        }
        .padding(.bottom, 40)
    }
}

struct AppSettingsView: View {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds: Int = 90
    @AppStorage("audioAlertsEnabled") private var audioAlertsEnabled: Bool = true
    @AppStorage("countdownTicksEnabled") private var countdownTicksEnabled: Bool = false
    
    // API Key State
    @State private var apiKey: String = ""
    @State private var isKeySaved: Bool = false
    
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    ) var allHistory: [WorkoutSession]
    
    @Environment(\.dismiss) var dismiss
    
    let restOptions = [30, 60, 90, 120, 180, 240, 300]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - AI Configuration
                Section {
                    SecureField("Enter Gemini API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if isKeySaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("API Key Active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(isKeySaved ? "Update Key" : "Save Key") {
                        if !apiKey.isEmpty {
                            KeychainManager.shared.save(key: apiKey)
                            isKeySaved = true
                            apiKey = "" // Clear text field for security
                        }
                    }
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("AI Coach Configuration")
                } footer: {
                    Text("Your API Key is stored securely in the device Keychain.")
                }
                
                // MARK: - Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $userTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Units
                Section("Units") {
                    Picker("System", selection: $unitSystem) {
                        Text("Imperial (lbs/mi)").tag(UnitSystem.imperial)
                        Text("Metric (kg/km)").tag(UnitSystem.metric)
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Timer
                Section("Timer") {
                    Picker("Default Rest Time", selection: $defaultRestSeconds) {
                        ForEach(restOptions, id: \.self) { seconds in
                            let min = seconds / 60
                            let sec = seconds % 60
                            if sec == 0 {
                                Text("\(min) min").tag(seconds)
                            } else {
                                Text("\(min)m \(sec)s").tag(seconds)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $audioAlertsEnabled) {
                        Label("Rest Timer Audio Alerts", systemImage: "speaker.wave.2.fill")
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $countdownTicksEnabled) {
                        Label("Countdown Ticks (Last 3s)", systemImage: "metronome")
                    }
                    .tint(.orange)
                    .disabled(!audioAlertsEnabled)
                    
                } header: {
                    Text("Audio & Haptics")
                } footer: {
                    if audioAlertsEnabled {
                        Text("Play a sound when the rest timer completes. Countdown ticks play during the last 3 seconds.")
                    } else {
                        Text("Enable audio alerts to hear when your rest timer finishes.")
                    }
                }
                
                Section("Data Management") {
                    if let csvURL = DataExporter.createCSVFile(from: allHistory) {
                        ShareLink(item: csvURL) {
                            Label("Export History to CSV", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Text("Unable to generate export").foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Text("Doggo App v2.0")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                // Check if key exists on load
                if let saved = KeychainManager.shared.retrieveKey(), !saved.isEmpty {
                    isKeySaved = true
                }
            }
        }
    }
}
