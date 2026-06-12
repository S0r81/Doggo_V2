//
//  ImportSummarySheet.swift
//  Doggo_V2
//
//  Never import blindly: shows what the picked CSV contains and asks for
//  confirmation before anything touches the database.
//

import SwiftUI

struct ImportSummarySheet: View {
    let sessions: [CSVImporter.ImportedSession]
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var totalSets: Int {
        sessions.reduce(0) { $0 + $1.totalSets }
    }

    private var exerciseCount: Int {
        Set(sessions.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
    }

    private var dateRange: String {
        let dates = sessions.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return "—" }
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return "\(first.formatted(formatter)) – \(last.formatted(formatter))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "square.and.arrow.down.badge.checkmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)

                    Text("Found \(sessions.count) workout\(sessions.count == 1 ? "" : "s")")
                        .font(.title2.bold())

                    Text("\(exerciseCount) exercises · \(totalSets) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(dateRange)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, Spacing.xl)
                .accessibilityElement(children: .combine)

                // Preview of the first few sessions
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(4).enumerated()), id: \.element.id) { index, session in
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(session.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.totalSets) sets")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(Spacing.md)

                        if index < min(sessions.count, 4) - 1 {
                            Divider().padding(.leading, Spacing.md)
                        }
                    }

                    if sessions.count > 4 {
                        Text("+ \(sessions.count - 4) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, Spacing.md)
                    }
                }
                .cardSurface(cornerRadius: 12)
                .padding(.horizontal)

                Text("Workouts that already exist (same day, same exercise) will be skipped automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                Spacer()

                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    Label("Import \(sessions.count) Workout\(sessions.count == 1 ? "" : "s")", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)
                .padding(.bottom, Spacing.lg)
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
