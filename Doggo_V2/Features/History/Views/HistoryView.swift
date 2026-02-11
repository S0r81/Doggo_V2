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
        List {
            if viewModel.sessions.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath")
            } else {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(destination: WorkoutDetailView(session: session)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.name)
                                    .font(.headline)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(session.duration / 60)) min")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .onDelete(perform: { indexSet in
                    deleteSession(at: indexSet, viewModel: viewModel)
                })
            }
        }
    }
    
    private func deleteSession(at offsets: IndexSet, viewModel: HistoryViewModel) {
        Task {
            for index in offsets {
                await viewModel.deleteSession(viewModel.sessions[index])
            }
        }
    }
}
