//
//  HistoryView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    let container: AppContainer
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var showImportSheet = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    historyContent(viewModel: viewModel)
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import history")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        guard let vm = viewModel else { return }
                        Task {
                            await vm.createManualEntry()
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add manual entry")
                }
            }
            .sheet(isPresented: $showImportSheet) {
                HistoryImportView()
            }
            .onAppear {
                if viewModel == nil {
                    let vm = container.makeHistoryViewModel()
                    self.viewModel = vm
                    
                    Task {
                        await vm.loadHistory()
                        await vm.performSilentCleanup()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func historyContent(viewModel: HistoryViewModel) -> some View {
        let sections = monthSections(viewModel.sessions)

        List {
            if viewModel.sessions.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath")
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(sections, id: \.month) { section in
                    Section(section.title) {
                        ForEach(section.sessions) { session in
                            NavigationLink(destination: WorkoutDetailView(session: session)) {
                                historyRow(session)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteSession(session) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search workouts")
    }

    private func historyRow(_ session: WorkoutSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sessionSummary(session))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(Int(session.duration / 60)) min")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private func sessionSummary(_ session: WorkoutSession) -> String {
        let exerciseCount = Set(session.sets.compactMap { $0.exercise?.id }).count
        return "\(exerciseCount) exercises · \(session.sets.count) sets"
    }

    // MARK: - Month Grouping
    private struct MonthSection {
        let month: Date
        let title: String
        let sessions: [WorkoutSession]
    }

    private func monthSections(_ sessions: [WorkoutSession]) -> [MonthSection] {
        let filtered = searchText.isEmpty
            ? sessions
            : sessions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { session in
            calendar.date(from: calendar.dateComponents([.year, .month], from: session.date)) ?? session.date
        }

        return grouped
            .map { month, sessions in
                MonthSection(
                    month: month,
                    title: month.formatted(.dateTime.month(.wide).year()),
                    sessions: sessions.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.month > $1.month }
    }
}
