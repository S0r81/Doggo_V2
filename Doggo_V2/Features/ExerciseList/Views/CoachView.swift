//
//  CoachView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct CoachView: View {
    let container: AppContainer
    let sessions: [WorkoutSession]
    
    @Environment(\.dismiss) var dismiss
    @Query var profiles: [UserProfile]
    @Query var routines: [Routine]

    @AppStorage("cachedCoachAdvice") private var cachedAdvice: String = ""
    @AppStorage("cachedCoachTimestamp") private var cachedTimestamp: Double = 0

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCopied = false

    // MARK: - Plan Tune-Up State
    @State private var isTuning = false
    @State private var tuneProposals: [ProgressionProposal] = []
    @State private var tuneError: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        ContentUnavailableView {
                            Label("Coach Unavailable", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Try Again") { generateReport(force: true) }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Coach's Report")
                                    .font(.title2).bold()
                                Spacer()
                                if cachedTimestamp > 0 {
                                    Text("Generated: \(Date(timeIntervalSince1970: cachedTimestamp).formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if cachedAdvice.isEmpty {
                                ContentUnavailableView("Ready to Coach", systemImage: "dumbbell.fill", description: Text("I will analyze your volume, consistency, and muscle split to give you specific advice."))
                                    .padding()
                            } else {
                                Text(LocalizedStringKey(cachedAdvice))
                                    .padding()
                                    .cardSurface(cornerRadius: 12)
                                    .contextMenu {
                                        Button {
                                            copyToClipboard()
                                        } label: {
                                            Label("Copy Report", systemImage: "doc.on.doc")
                                        }
                                    }
                            }

                            // MARK: - AI Plan Tune-Up
                            if !routines.isEmpty {
                                Button {
                                    tunePlan()
                                } label: {
                                    if isTuning {
                                        HStack {
                                            ProgressView().controlSize(.small)
                                            Text("Reviewing your plan…")
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, Spacing.sm)
                                    } else {
                                        Label("Tune My Plan", systemImage: "wand.and.stars")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Spacing.sm)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.purple)
                                .disabled(isTuning || isLoading)

                                Text("Proposes new target weights for your routines based on the last 4 weeks. You review every change before it applies.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { generateReport(force: true) }) {
                        Image(systemName: "sparkles")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Regenerate report")
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    if !cachedAdvice.isEmpty {
                        Button(action: copyToClipboard) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .disabled(isLoading)
                        .accessibilityLabel(isCopied ? "Copied" : "Copy report")
                    }
                    
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if cachedAdvice.isEmpty {
                generateReport(force: false)
            }
        }
        // MARK: - Plan Tune-Up Review
        .sheet(isPresented: Binding(
            get: { !tuneProposals.isEmpty },
            set: { if !$0 { tuneProposals = [] } }
        )) {
            ProgressionReviewSheet(title: "AI Plan Tune-Up", proposals: tuneProposals)
                .presentationDetents([.medium, .large])
        }
        .alert("Plan Tune-Up", isPresented: Binding(
            get: { tuneError != nil },
            set: { if !$0 { tuneError = nil } }
        )) {
            Button("OK", role: .cancel) { tuneError = nil }
        } message: {
            Text(tuneError ?? "")
        }
    }

    private func tunePlan() {
        isTuning = true
        Task {
            do {
                let proposals = try await PlanTuner.proposals(
                    routines: routines,
                    sessions: sessions,
                    client: container.aiClient
                )
                await MainActor.run {
                    isTuning = false
                    if proposals.isEmpty {
                        tuneError = "Your plan already looks dialed in — no changes proposed."
                    } else {
                        tuneProposals = proposals
                    }
                }
            } catch {
                await MainActor.run {
                    isTuning = false
                    tuneError = error.localizedDescription
                }
            }
        }
    }
    
    private var loadingView: some View {
        AILoadingView(
            title: "Analyzing your training…",
            subtitle: "Volume · consistency · muscle split"
        )
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func generateReport(force: Bool) {
        withAnimation {
            isLoading = true
            errorMessage = nil
            isCopied = false
        }
        
        Task {
            do {
                // NEW: Use split AI service
                let apiClient = container.aiClient
                let prompt = GeminiPromptBuilder.buildAnalysisPrompt(
                    sessions: sessions,
                    profile: profiles.first
                )
                
                let rawResponse = try await apiClient.sendRequest(prompt: prompt)
                
                // Check for rate limit in response
                if rawResponse.contains("Rate Limit") && !cachedAdvice.isEmpty {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                
                let analysis = GeminiResponseParser.parseAnalysis(rawResponse)
                
                await MainActor.run {
                    self.cachedAdvice = analysis
                    self.cachedTimestamp = Date().timeIntervalSince1970
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = cachedAdvice
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.snappy) { isCopied = true }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { isCopied = false }
        }
    }
}
