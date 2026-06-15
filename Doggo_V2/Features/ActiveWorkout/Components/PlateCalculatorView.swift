//
//  PlateCalculatorView.swift
//  Doggo_V2
//
//  Half-sheet plate calculator: type a target weight, see the bar drawn with
//  the exact plates per side. Bar weight and available plates persist per
//  unit system, so a gym without 35s stays configured.
//

import SwiftUI

struct PlateCalculatorView: View {
    var initialTarget: Double = 0

    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    // Per-unit gym setup (bar preset + CSV of enabled plates)
    @AppStorage("barType") private var barTypeRaw: String = BarType.olympic.rawValue
    // The custom starting weight lives in its own Double key — keeping the
    // number out of the BarType enum means BarType stays a plain String case
    // that can never fail to decode. Persists across launches.
    @AppStorage("customBarWeight") private var customBarWeight: Double = 45
    @AppStorage("enabledPlatesLbs") private var enabledPlatesLbs: String = PlateCalculator.encode(PlateCalculator.standardPlatesLbs)
    @AppStorage("enabledPlatesKg") private var enabledPlatesKg: String = PlateCalculator.encode(PlateCalculator.standardPlatesKg)

    @State private var target: Double?
    @State private var showGymSetup = false
    @FocusState private var targetFocused: Bool

    // MARK: - Derived

    private var unitLabel: String { unitSystem.weightLabel }

    private var barType: BarType {
        BarType(rawValue: barTypeRaw) ?? .olympic
    }

    private var barWeight: Double {
        barType.resolvedWeight(for: unitSystem, customWeight: customBarWeight)
    }

    private var enabledPlates: [Double] {
        PlateCalculator.decode(unitSystem == .imperial ? enabledPlatesLbs : enabledPlatesKg)
    }

    private var calculation: PlateCalculation? {
        guard let target, target > 0 else { return nil }
        return PlateCalculator.calculate(
            target: target,
            barWeight: barWeight,
            availablePlates: enabledPlates
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    targetInput
                    resultArea
                    gymSetup
                }
                .padding(.vertical, Spacing.lg)
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if initialTarget > 0 { target = initialTarget }
                else { targetFocused = true }
            }
        }
    }

    // MARK: - Target Input

    private var targetInput: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Target", value: $target, format: .number)
                .focused($targetFocused)
                .keyboardType(.decimalPad)
                .font(.system(.largeTitle, design: .rounded).bold())
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160)

            Text(unitLabel)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    // MARK: - Result

    @ViewBuilder
    private var resultArea: some View {
        if let calc = calculation {
            if calc.targetBelowBar {
                ContentUnavailableView(
                    "Below Bar Weight",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The bar alone weighs \(PlateCalculator.format(calc.barWeight)) \(unitLabel).")
                )
                .frame(height: 160)
            } else {
                VStack(spacing: Spacing.lg) {
                    BarbellVisual(
                        platesPerSide: calc.platesPerSide,
                        unit: unitSystem,
                        showBar: !barType.isBarless
                    )
                    .frame(height: 130)
                    .padding(.horizontal)

                    plateSummary(calc)
                }
            }
        } else {
            ContentUnavailableView(
                "Enter a Target Weight",
                systemImage: "scalemass",
                description: Text("Type the total weight you want on the bar.")
            )
            .frame(height: 160)
        }
    }

    @ViewBuilder
    private func plateSummary(_ calc: PlateCalculation) -> some View {
        VStack(spacing: Spacing.sm) {
            if calc.platesPerSide.isEmpty {
                Text(barType.isBarless ? "No plates needed" : "Empty bar — no plates needed")
                    .font(.headline)
            } else {
                Text("Per side")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.sm) {
                    ForEach(calc.groupedPlates, id: \.plate) { group in
                        Text("\(group.count) × \(PlateCalculator.format(group.plate))")
                            .font(.headline)
                            .monospacedDigit()
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }

            if calc.isExact {
                Label("\(PlateCalculator.format(calc.achievedWeight)) \(unitLabel) total", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Label(
                    "Closest: \(PlateCalculator.format(calc.achievedWeight)) \(unitLabel) — \(PlateCalculator.format(calc.shortfall)) \(unitLabel) short",
                    systemImage: "exclamationmark.circle"
                )
                .font(.subheadline)
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Gym Setup

    private var gymSetup: some View {
        DisclosureGroup(isExpanded: $showGymSetup) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Bar guide — pick the bar you're holding, not a number
                Text("Your Bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(BarType.allCases) { type in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Button {
                            withAnimation(.snappy) { barTypeRaw = type.rawValue }
                        } label: {
                            HStack(spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(rowTitle(for: type))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(type.caption)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: barType == type ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(barType == type ? Color.accentColor : Color.secondary.opacity(0.4))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(barType == type ? .isSelected : [])

                        // Reveal the custom-weight field directly under the row.
                        if type.isCustom && barType == .custom {
                            customWeightField
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }

                Divider()

                // Available plates
                Text("Available Plates")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(PlateCalculator.standardPlates(for: unitSystem), id: \.self) { plate in
                    Toggle("\(PlateCalculator.format(plate)) \(unitLabel)", isOn: plateBinding(plate))
                }
            }
            .padding(.top, Spacing.sm)
        } label: {
            Label("Gym Setup", systemImage: "gearshape")
                .font(.headline)
        }
        .padding(.horizontal)
    }

    /// "Standard Olympic · 45 lbs". For custom, reflects the live entered value.
    private func rowTitle(for type: BarType) -> String {
        let weight = type.isCustom ? customBarWeight : type.weight(for: unitSystem)
        return "\(type.label) · \(PlateCalculator.format(weight)) \(unitLabel)"
    }

    /// Decimal entry for machines with their own starting weight. Edits flow
    /// straight into `customBarWeight` (@AppStorage), so the result, summary,
    /// and barbell visual all recompute reactively and the value persists.
    private var customWeightField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Weight", value: $customBarWeight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.headline.monospacedDigit())
                .frame(maxWidth: 110)
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.sm)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Text(unitLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    private func plateBinding(_ plate: Double) -> Binding<Bool> {
        Binding(
            get: { enabledPlates.contains(plate) },
            set: { isOn in
                var plates = enabledPlates
                if isOn {
                    if !plates.contains(plate) { plates.append(plate) }
                } else {
                    plates.removeAll { $0 == plate }
                }
                let encoded = PlateCalculator.encode(plates)
                if unitSystem == .imperial { enabledPlatesLbs = encoded }
                else { enabledPlatesKg = encoded }
            }
        )
    }
}

// MARK: - Barbell Drawing

/// Side view of one loaded sleeve: shaft → collar shoulder → plates
/// (heaviest innermost) → empty sleeve with end cap.
struct BarbellVisual: View {
    let platesPerSide: [Double]
    let unit: UnitSystem
    /// When false (Machine / No Bar), the shaft, collar, sleeve and end cap
    /// are dropped — just a loaded post is drawn.
    var showBar: Bool = true

    private var maxStandard: Double {
        PlateCalculator.standardPlates(for: unit).max() ?? 45
    }

    var body: some View {
        HStack(spacing: 3) {
            if showBar {
                // Bar shaft (toward the lifter)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.gray)
                    .frame(width: 44, height: 12)

                // Collar shoulder
                RoundedRectangle(cornerRadius: 2)
                    .fill(.gray)
                    .frame(width: 9, height: 30)
            } else {
                // Machine post base — anchors the plate stack without a bar.
                RoundedRectangle(cornerRadius: 2)
                    .fill(.gray)
                    .frame(width: 8, height: 34)
            }

            // Plates, heaviest first
            ForEach(Array(platesPerSide.enumerated()), id: \.offset) { _, plate in
                RoundedRectangle(cornerRadius: 3)
                    .fill(plateColor(plate))
                    .frame(width: plateWidth(plate), height: plateHeight(plate))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.black.opacity(0.15), lineWidth: 1)
                    )
            }

            if showBar {
                // Remaining empty sleeve
                RoundedRectangle(cornerRadius: 2)
                    .fill(.gray.opacity(0.55))
                    .frame(height: 12)
                    .frame(minWidth: 20, maxWidth: 70)

                // End cap
                RoundedRectangle(cornerRadius: 2)
                    .fill(.gray)
                    .frame(width: 6, height: 18)
            } else {
                // Pin retainer cap at the end of the loaded post.
                RoundedRectangle(cornerRadius: 2)
                    .fill(.gray)
                    .frame(width: 6, height: 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func plateHeight(_ plate: Double) -> CGFloat {
        // Smallest plates ~38pt, the biggest standard plate 120pt
        38 + CGFloat(plate / maxStandard) * 82
    }

    private func plateWidth(_ plate: Double) -> CGFloat {
        let big: Double = unit == .imperial ? 35 : 15
        let medium: Double = unit == .imperial ? 10 : 5
        if plate >= big { return 18 }
        if plate >= medium { return 13 }
        return 9
    }

    /// Loosely follows competition color coding so loads are scannable.
    private func plateColor(_ plate: Double) -> Color {
        if unit == .imperial {
            switch plate {
            case 45...: return .blue
            case 35..<45: return .yellow
            case 25..<35: return .green
            case 10..<25: return Color(white: 0.85)
            case 5..<10: return .red
            default: return Color(white: 0.6)
            }
        } else {
            switch plate {
            case 25...: return .red
            case 20..<25: return .blue
            case 15..<20: return .yellow
            case 10..<15: return .green
            case 5..<10: return Color(white: 0.85)
            case 2.5..<5: return .red
            default: return Color(white: 0.6)
            }
        }
    }

    private var accessibilityDescription: String {
        guard !platesPerSide.isEmpty else { return "Empty barbell" }
        let grouped = Dictionary(grouping: platesPerSide, by: { $0 })
            .sorted { $0.key > $1.key }
            .map { "\($0.value.count) \(PlateCalculator.format($0.key))s" }
            .joined(separator: ", ")
        return "Barbell loaded per side with \(grouped)"
    }
}

#Preview {
    PlateCalculatorView(initialTarget: 225)
}
