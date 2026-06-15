//
//  PeptideCalculatorView.swift
//  Doggo_V2
//
//  Half-sheet reconstitution calculator — the peptide analogue of the plate
//  calculator. Type the vial size, water added, and desired dose, pick the
//  units (mg/IU vial, mcg/mg/IU dose), and see exactly how many syringe units
//  to pull, drawn on a U-100 syringe.
//

import SwiftUI

struct PeptideCalculatorView: View {
    /// Optional seed values when opened from a saved profile (mg vial / mcg dose).
    var seedMg: Double? = nil
    var seedWater: Double? = nil
    var seedDose: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    // Last-used values persist for the standalone calculator.
    @AppStorage("peptideCalcVial") private var vialAmount: Double = 5
    @AppStorage("peptideCalcWater") private var waterMl: Double = 2
    @AppStorage("peptideCalcDose") private var doseAmount: Double = 250
    @AppStorage("peptideCalcVialUnit") private var vialUnitRaw: String = PeptideMeasurementUnit.mg.rawValue
    @AppStorage("peptideCalcDoseUnit") private var doseUnitRaw: String = PeptideMeasurementUnit.mcg.rawValue

    @FocusState private var focusedField: Field?
    private enum Field { case vial, water, dose }

    private var accent: Color { Color.accent(for: userTheme) }

    // MARK: - Unit bindings (auto-keep vial/dose compatible)

    private var vialUnit: Binding<PeptideMeasurementUnit> {
        Binding(
            get: { PeptideMeasurementUnit(rawValue: vialUnitRaw) ?? .mg },
            set: { newValue in
                vialUnitRaw = newValue.rawValue
                // IU vials must be dosed in IU; switching away from IU restores mcg.
                if newValue == .iu {
                    doseUnitRaw = PeptideMeasurementUnit.iu.rawValue
                } else if doseUnitRaw == PeptideMeasurementUnit.iu.rawValue {
                    doseUnitRaw = PeptideMeasurementUnit.mcg.rawValue
                }
            }
        )
    }

    private var doseUnit: Binding<PeptideMeasurementUnit> {
        Binding(
            get: { PeptideMeasurementUnit(rawValue: doseUnitRaw) ?? .mcg },
            set: { doseUnitRaw = $0.rawValue }
        )
    }

    private var calc: PeptideCalculation {
        PeptideCalculator.calculate(
            vialAmount: vialAmount,
            vialUnit: vialUnit.wrappedValue,
            waterAddedMl: waterMl,
            doseAmount: doseAmount,
            doseUnit: doseUnit.wrappedValue
        )
    }

    private var hasInputs: Bool { vialAmount > 0 && waterMl > 0 && doseAmount > 0 }
    private var overFills: Bool { calc.isValid && calc.unitsToPull > 100 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    inputCard
                    resultArea
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Peptide Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    Spacer()
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear(perform: applySeeds)
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private func applySeeds() {
        if let seedMg { vialAmount = seedMg; vialUnitRaw = PeptideMeasurementUnit.mg.rawValue }
        if let seedWater { waterMl = seedWater }
        if let seedDose { doseAmount = seedDose; doseUnitRaw = PeptideMeasurementUnit.mcg.rawValue }
    }

    // MARK: - Inputs

    private var inputCard: some View {
        VStack(spacing: Spacing.md) {
            inputRow(title: "Vial Amount", value: $vialAmount, field: .vial) {
                unitPicker(selection: vialUnit, options: [.mg, .iu])
            }
            Divider()
            inputRow(title: "Water Added", value: $waterMl, field: .water) {
                Text("ml")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .leading)
                    .fixedSize()
            }
            Divider()
            inputRow(title: "Desired Dose", value: $doseAmount, field: .dose) {
                unitPicker(selection: doseUnit, options: [.mcg, .mg, .iu])
            }
        }
        .padding(Spacing.lg)
        .cardSurface(shadowed: true)
    }

    private func inputRow<Trailing: View>(
        title: String,
        value: Binding<Double>,
        field: Field,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // The number expands to fill, pushing the value flush against the
            // unit on its right.
            TextField("0", value: value, format: .number)
                .focused($focusedField, equals: field)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.title2, design: .rounded).bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
            // The unit holds its natural width and never gets compressed by
            // the expanding text field.
            trailing()
                .layoutPriority(1)
        }
    }

    private func unitPicker(selection: Binding<PeptideMeasurementUnit>, options: [PeptideMeasurementUnit]) -> some View {
        Picker("", selection: selection) {
            ForEach(options) { Text($0.label).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(accent)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Result

    @ViewBuilder
    private var resultArea: some View {
        if calc.isValid {
            resultCard
        } else if hasInputs && !calc.unitsCompatible {
            incompatibleNote
        } else {
            ContentUnavailableView(
                "Enter Your Vial Details",
                systemImage: "syringe",
                description: Text("Fill in the vial size, water, and dose to see your pull.")
            )
            .frame(height: 200)
        }
    }

    private var resultCard: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text("PULL TO")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Text("\(calc.roundedUnits)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: calc.roundedUnits)
                Text(calc.isExactTick ? "units" : "units (≈ \(PeptideCalculator.format(calc.unitsToPull)) exact)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SyringeVisual(units: min(calc.unitsToPull, 100), accent: accent)
                .padding(.horizontal, Spacing.sm)

            if overFills {
                Label("That dose needs more than a full U-100 syringe. Add more water or split the injection.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            statsGrid
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private var incompatibleNote: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Units Don't Match")
                .font(.headline)
            Text("\(vialUnit.wrappedValue.label.uppercased()) vials can only be dosed in the same family. Pair IU with IU, or mg with mg/mcg.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .cardSurface()
    }

    private var statsGrid: some View {
        let unit = calc.unitLabel
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: Spacing.md) {
            statTile("Concentration", "\(PeptideCalculator.format(calc.concentrationPerMl)) \(unit)/ml")
            statTile("Per Unit", "\(PeptideCalculator.format(calc.perUnitAmount)) \(unit)")
            statTile("Doses / Vial", "\(calc.dosesPerVial)")
            statTile("Volume", "\(PeptideCalculator.format(calc.volumeToPullMl)) ml")
        }
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}
