//
//  DashboardView.swift
//  Doggo_V2
//
//  Created by Sorest on 1/5/26.
//  Updated for Animations: 2026
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
    @State private var dashboardSegment: String? = nil
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    
    // Sheets
    @State private var showSettings = false
    @State private var showProfile = false
    
    // Tab States for Paging
    @State private var consistencyPage: Int = 4
    @State private var volumePage: Int = 2
    
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
                    // MARK: - ANIMATED SECTIONS
                    
                    headerView
                        .animateEntry(index: 0)
                    
                    quickActionsView
                        .animateEntry(index: 1)
                    
                    statsGridView
                        .animateEntry(index: 2)
                    
                    // SWIPABLE CHARTS
                    weeklyConsistencyView
                        .animateEntry(index: 3)
                    
                    volumeTrendView
                        .animateEntry(index: 4)
                    
                    recentBestsView
                        .animateEntry(index: 5)
                    
                    workoutFocusView
                        .animateEntry(index: 6)
                    
                    lastWorkoutView
                        .animateEntry(index: 7)
                }
                .padding(.bottom, 20)
            }
            // MARK: - THEME FIX: Use Dynamic Background
            // Was: .background(Color(uiColor: .systemGroupedBackground))
            .background(Color.background(for: userTheme))
            
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
                    .accessibilityLabel("Settings")
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
                    // Use Accent Color (Cyan in Nordic)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(BouncyButtonStyle())
            .accessibilityLabel("Open profile")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var quickActionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: { selectedTab = 2 }) {
                    // Note: You hardcoded colors here (.blue, .purple).
                    // If you want these to match the theme strictly, change them to Color.accentColor
                    QuickActionButton(title: "Log Workout", icon: "plus", color: .blue)
                }
                .buttonStyle(BouncyButtonStyle())
                
                Button(action: { selectedTab = 1 }) {
                    QuickActionButton(title: "New Routine", icon: "list.bullet.clipboard", color: .purple)
                }
                .buttonStyle(BouncyButtonStyle())
                
                Button(action: { showCoach = true }) {
                    QuickActionButton(title: "AI Coach", icon: "brain.head.profile", color: .orange)
                }
                .buttonStyle(BouncyButtonStyle())
                
                Button(action: { showPlanner = true }) {
                    QuickActionButton(title: "Plan Week", icon: "calendar.badge.clock", color: .teal)
                }
                .buttonStyle(BouncyButtonStyle())
            }
            .padding(.horizontal)
        }
    }
    
    private var statsGridView: some View {
        // "Total" prefixes make clear these are all-time numbers, not weekly ones.
        LazyVGrid(columns: columns, spacing: 16) {
            StatCard(title: "Total Workouts", value: "\(recentSessions.count)", icon: "dumbbell.fill", color: .blue)
            StatCard(title: "Total Volume", value: viewModel.getTotalVolume(from: recentSessions, preferredUnit: unitSystem.rawValue), icon: "chart.bar.fill", color: .green)
            StatCard(title: "Total Time", value: viewModel.getTotalDuration(from: recentSessions), icon: "clock.fill", color: .orange)
            StatCard(title: "Current Streak", value: "\(viewModel.getCurrentStreak(from: recentSessions)) Days", icon: "flame.fill", color: .red)
        }
        .padding(.horizontal)
    }
    
    // MARK: - PAGED Consistency Chart
    private var weeklyConsistencyView: some View {
        let pages = viewModel.getConsistencyPages(from: recentSessions)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency").font(.headline)
                Spacer()
                if !pages.isEmpty {
                    ChartPagerControl(page: $consistencyPage, labels: pages.map(\.label))
                }
            }
            .padding(.horizontal)

            if pages.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
            } else {
                TabView(selection: $consistencyPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading) {
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
                .cardSurface()
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - PAGED Volume Chart
    private var volumeTrendView: some View {
        let pages = viewModel.getVolumePages(from: recentSessions)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                Text("Volume Trend")
                    .font(.headline)
                Spacer()
                if !pages.isEmpty {
                    ChartPagerControl(page: $volumePage, labels: pages.map(\.label))
                }
            }
            .padding(.horizontal)

            if pages.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
                    .frame(height: 150)
            } else {
                TabView(selection: $volumePage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(alignment: .leading) {
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
                .cardSurface()
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
                                // Consolidated: one canonical exercise screen
                                // (ExerciseAnalyticsView duplicated this with different math)
                                NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
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
                                    .cardSurface()
                                }
                                .buttonStyle(BouncyButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var workoutFocusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weekly Focus", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showFocusDetail = true
                } label: {
                    HStack(spacing: 2) {
                        Text("Details")
                        Image(systemName: "chevron.right").font(.caption2.bold())
                    }
                }
                .font(.caption).bold().foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal)
            
            let calendar = Calendar.current
            let now = Date()
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let weeklySessions = recentSessions.filter { $0.date >= startOfWeek }
            
            let weeklyStats = viewModel.getTopExercises(from: weeklySessions)
            
            if weeklyStats.isEmpty {
                ContentUnavailableView("No Logged Sets", systemImage: "dumbbell")
                    .frame(height: 120)
                    .cardSurface(cornerRadius: 12)
                    .padding(.horizontal)
            } else {
                WorkoutFocusCard(data: weeklyStats, selectedSegment: $dashboardSegment)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showFocusDetail) {
            WorkoutFocusDetailView(allSessions: recentSessions)
        }
    }
    
    private var lastWorkoutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Session").font(.headline)
                Spacer()
                NavigationLink(destination: HistoryView(container: container)) {
                    HStack(spacing: 2) {
                        Text("History")
                        Image(systemName: "chevron.right").font(.caption2.bold())
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal)
            
            if let last = recentSessions.first {
                NavigationLink(destination: WorkoutDetailView(session: last)) {
                    LastWorkoutHero(session: last)
                }
                .buttonStyle(BouncyButtonStyle())
            } else {
                ContentUnavailableView("Start your journey", systemImage: "figure.run")
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Chart Pager Control
// Chevron paging for the swipeable chart cards. The page dots are hidden on the
// TabViews, so without this there is no visible hint that more pages exist.
struct ChartPagerControl: View {
    @Binding var page: Int
    let labels: [String]

    private var clampedPage: Int { min(max(page, 0), labels.count - 1) }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { page = clampedPage - 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.bold())
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .disabled(clampedPage <= 0)
            .accessibilityLabel("Previous period")

            Text(labels[clampedPage])
                .font(.caption).bold()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 80)

            Button {
                withAnimation { page = clampedPage + 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .disabled(clampedPage >= labels.count - 1)
            .accessibilityLabel("Next period")
        }
        .foregroundStyle(Color.accentColor)
    }
}

// (AppSettingsView remains unchanged from your code)
// ...

// (AppSettingsView struct remains unchanged)
struct AppSettingsView: View {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds: Int = 90
    @AppStorage("audioAlertsEnabled") private var audioAlertsEnabled: Bool = true
    @AppStorage("countdownTicksEnabled") private var countdownTicksEnabled: Bool = false
    
    // API Key State
    @AppStorage("aiProvider") private var aiProviderRaw: String = AIProvider.gemini.rawValue
    @AppStorage("openRouterModel") private var openRouterModel: String = ""
    @State private var apiKey: String = ""
    @State private var isKeySaved: Bool = false

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .gemini
    }

    private func refreshKeyStatus() {
        let saved = KeychainManager.shared.retrieveKey(for: selectedProvider)
        isKeySaved = !(saved ?? "").isEmpty
    }
    
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
                    Picker("Provider", selection: $aiProviderRaw) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.label).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    // OpenRouter routes to any model — let the user pick the slug
                    if selectedProvider == .openrouter {
                        TextField("Model (e.g. \(OpenRouterAPIClient.defaultModel))", text: $openRouterModel)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.callout.monospaced())
                    }

                    SecureField(selectedProvider.keyPlaceholder, text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if isKeySaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("\(selectedProvider.shortLabel) API Key Active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Remove", role: .destructive) {
                                KeychainManager.shared.deleteKey(for: selectedProvider)
                                isKeySaved = false
                            }
                            .font(.caption)
                        }
                    }

                    Button(isKeySaved ? "Update Key" : "Save Key") {
                        if !apiKey.isEmpty {
                            KeychainManager.shared.save(key: apiKey, for: selectedProvider)
                            isKeySaved = true
                            apiKey = "" // Clear text field for security
                        }
                    }
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("AI Coach Configuration")
                } footer: {
                    if selectedProvider == .openrouter {
                        Text("Each provider has its own key, stored securely in the device Keychain. \(selectedProvider.keyHelpText). Leave the model blank to let OpenRouter pick automatically, or enter any slug from openrouter.ai/models.")
                    } else {
                        Text("Each provider has its own key, stored securely in the device Keychain. \(selectedProvider.keyHelpText).")
                    }
                }
                .onChange(of: aiProviderRaw) { _, _ in
                    apiKey = ""
                    refreshKeyStatus()
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
                refreshKeyStatus()
            }
        }
    }
}
