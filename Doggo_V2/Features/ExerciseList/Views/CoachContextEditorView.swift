//
//  CoachContextEditorView.swift
//  Doggo_V2
//
//  "What Coach knows" — a user-editable, persistent profile injected into every
//  Coach request (report + chat). Six categories, one independently editable /
//  deletable row per fact. Edits take effect on the very next Coach message
//  because both modes read CoachContextItem live (no app restart needed).
//

import SwiftUI
import SwiftData

struct CoachContextEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    @Query(sort: \CoachContextItem.sortOrder) private var items: [CoachContextItem]
    @FocusState private var focusedItem: UUID?

    private var activeCount: Int { CoachContextAssembler.activeCount(items) }

    var body: some View {
        NavigationStack {
            List {
                statusSection

                ForEach(CoachContextCategory.allCases) { category in
                    Section {
                        ForEach(itemsIn(category)) { item in
                            TextField(category.placeholder, text: binding(for: item), axis: .vertical)
                                .focused($focusedItem, equals: item.id)
                                .lineLimit(1...4)
                        }
                        .onDelete { offsets in delete(offsets, in: category) }

                        Button { addItem(to: category) } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.accent(for: userTheme))
                        }
                    } header: {
                        HStack {
                            Label(category.label, systemImage: category.icon)
                            Spacer()
                            let count = itemsIn(category).count
                            if count > 0 {
                                Text("\(count)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("What Coach Knows")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { purgeEmpties(); dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedItem = nil; try? modelContext.save() }
                }
            }
        }
    }

    // MARK: - Status / empty state

    @ViewBuilder
    private var statusSection: some View {
        Section {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                Text(activeCount == 0
                     ? "Coach isn't using any notes yet"
                     : "Coach is using \(activeCount) note\(activeCount == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(activeCount == 0 ? Color.secondary : Color.accent(for: userTheme))

            if items.isEmpty {
                Text("Add anything you want the Coach to remember — dietary needs, injuries, your equipment, schedule, or goals. It's woven into every report and every chat, so you never have to repeat yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data helpers

    private func itemsIn(_ category: CoachContextCategory) -> [CoachContextItem] {
        items
            .filter { $0.category == category }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    private func binding(for item: CoachContextItem) -> Binding<String> {
        Binding(
            get: { item.text },
            set: { item.text = $0; item.updatedAt = Date() }
        )
    }

    private func addItem(to category: CoachContextCategory) {
        let nextOrder = (itemsIn(category).map(\.sortOrder).max() ?? -1) + 1
        let new = CoachContextItem(category: category, text: "", sortOrder: nextOrder)
        modelContext.insert(new)
        try? modelContext.save()
        focusedItem = new.id
    }

    private func delete(_ offsets: IndexSet, in category: CoachContextCategory) {
        let group = itemsIn(category)
        for index in offsets where index < group.count {
            modelContext.delete(group[index])
        }
        try? modelContext.save()
    }

    /// Drop blank rows on the way out so they neither linger nor inflate the badge.
    private func purgeEmpties() {
        for item in items where item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}
