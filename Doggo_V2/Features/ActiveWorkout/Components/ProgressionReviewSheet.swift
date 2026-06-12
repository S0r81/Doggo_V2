//
//  ProgressionReviewSheet.swift
//  Doggo_V2
//
//  Post-workout (and AI plan-tune) proposal review. Nothing mutates the
//  routine templates until the user taps Apply.
//

import SwiftUI
import SwiftData

struct ProgressionReviewSheet: View {
    let title: String
    let proposals: [ProgressionProposal]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedIDs: Set<UUID>

    init(title: String = "Next Session", proposals: [ProgressionProposal]) {
        self.title = title
        self.proposals = proposals
        _selectedIDs = State(initialValue: Set(proposals.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(proposals) { proposal in
                        proposalRow(proposal)
                    }
                } header: {
                    Text("Proposed changes")
                } footer: {
                    Text("Applied changes update each exercise's target weight for your next session. Uncheck anything you'd rather keep as-is.")
                }

                Section {
                    Button {
                        let accepted = proposals.filter { selectedIDs.contains($0.id) }
                        ProgressionEngine.apply(accepted, context: modelContext)
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    } label: {
                        Label("Apply \(selectedIDs.count) Change\(selectedIDs.count == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func proposalRow(_ proposal: ProgressionProposal) -> some View {
        let isSelected = selectedIDs.contains(proposal.id)

        Button {
            withAnimation(.snappy) {
                if isSelected { selectedIDs.remove(proposal.id) }
                else { selectedIDs.insert(proposal.id) }
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon(for: proposal.kind))
                    .font(.title3)
                    .foregroundStyle(color(for: proposal.kind))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(proposal.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: Spacing.xs) {
                        Text("\(PlateCalculator.format(proposal.currentWeight)) → \(PlateCalculator.format(proposal.proposedWeight)) \(proposal.unit)")
                            .font(.subheadline.bold())
                            .monospacedDigit()
                            .foregroundStyle(color(for: proposal.kind))
                    }

                    Text(proposal.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func icon(for kind: ProgressionProposal.Kind) -> String {
        switch kind {
        case .increase: return "arrow.up.circle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .aiTune: return "wand.and.stars"
        }
    }

    private func color(for kind: ProgressionProposal.Kind) -> Color {
        switch kind {
        case .increase: return .green
        case .deload: return .orange
        case .aiTune: return .purple
        }
    }
}
