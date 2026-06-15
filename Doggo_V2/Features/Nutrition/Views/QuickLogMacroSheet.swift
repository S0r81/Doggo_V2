//
//  QuickLogMacroSheet.swift
//  Doggo_V2
//
//  Compact half-sheet for logging a single macro's grams. Appends to today's
//  DailyMacroLog via the @ModelActor (find-or-append), fires a success haptic,
//  and dismisses.
//

import SwiftUI
import SwiftData

/// The three trackable macros, shared by the rings and the quick-log sheet.
enum MacroKind: String, CaseIterable, Identifiable {
    case protein, carbs, fats
    var id: String { rawValue }

    var label: String {
        switch self {
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fats: return "Fat"
        }
    }

    var color: Color {
        switch self {
        case .protein: return .blue
        case .carbs: return .orange
        case .fats: return .yellow
        }
    }
}

struct QuickLogMacroSheet: View {
    let macro: MacroKind
    let profileID: PersistentIdentifier
    let container: ModelContainer

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    @State private var amount: Int?
    @State private var isLogging = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private var accent: Color { Color.accent(for: userTheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text("How much did you eat?")
                    .font(.headline)

                HStack(spacing: Spacing.sm) {
                    TextField("0", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                    Text("g \(macro.label)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button(action: log) {
                    HStack(spacing: Spacing.sm) {
                        if isLogging { ProgressView().tint(.white) }
                        Text("Log \(macro.label)").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(macro.color)
                .disabled(isLogging || (amount ?? 0) <= 0)

                Spacer(minLength: 0)
            }
            .padding(Spacing.xl)
            .navigationTitle("Log \(macro.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .onAppear { focused = true }
            .alert("Couldn’t Log", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
    }

    private func log() {
        guard let value = amount, value > 0 else { return }
        isLogging = true
        let repository = NutritionRepository(modelContainer: container)
        let id = profileID
        let p = macro == .protein ? value : 0
        let c = macro == .carbs ? value : 0
        let f = macro == .fats ? value : 0
        Task {
            do {
                _ = try await repository.logDailyMacros(profileID: id, protein: p, carbs: c, fats: f, date: Date())
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isLogging = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLogging = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
