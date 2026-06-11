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
    
    @AppStorage("cachedCoachAdvice") private var cachedAdvice: String = ""
    @AppStorage("cachedCoachTimestamp") private var cachedTimestamp: Double = 0
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCopied = false
    
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
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Calculating volume & consistency...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Analyzing muscle split...")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(height: 300)
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
        
        withAnimation { isCopied = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isCopied = false }
        }
    }
}
