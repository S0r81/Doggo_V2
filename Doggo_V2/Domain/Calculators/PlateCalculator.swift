//
//  PlateCalculator.swift
//  Doggo_V2
//
//  Pure plate-math: given a target weight, a bar, and the plates the gym
//  actually has, compute the optimal loadout per side (greedy, which is
//  optimal for standard plate denominations).
//

import Foundation

struct PlateCalculation {
    let targetWeight: Double
    let barWeight: Double
    /// Heaviest-first, one entry per physical plate on ONE side.
    let platesPerSide: [Double]

    var achievedWeight: Double {
        barWeight + 2 * platesPerSide.reduce(0, +)
    }

    var isExact: Bool { abs(achievedWeight - targetWeight) < 0.01 }

    /// How far below the target the closest loadout lands (0 when exact).
    var shortfall: Double { max(0, targetWeight - achievedWeight) }

    var targetBelowBar: Bool { targetWeight < barWeight - 0.01 }

    /// Plate → count, ordered heaviest first. ("2 × 45, 1 × 25")
    var groupedPlates: [(plate: Double, count: Int)] {
        Dictionary(grouping: platesPerSide, by: { $0 })
            .map { (plate: $0.key, count: $0.value.count) }
            .sorted { $0.plate > $1.plate }
    }
}

// MARK: - Bar Types

/// Standard barbell presets — most lifters know which bar they're holding,
/// not what it weighs.
enum BarType: String, CaseIterable, Identifiable {
    case olympic
    case womensOlympic
    case ezCurl
    case smithMachine
    case noBar
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .olympic: return "Standard Olympic"
        case .womensOlympic: return "Women's Olympic"
        case .ezCurl: return "EZ Curl"
        case .smithMachine: return "Smith Machine"
        case .noBar: return "Machine / No Bar"
        case .custom: return "Custom Weight"
        }
    }

    var caption: String {
        switch self {
        case .olympic: return "The 7ft bar on most racks and platforms"
        case .womensOlympic: return "Slightly shorter and thinner grip"
        case .ezCurl: return "The short zig-zag curl bar"
        case .smithMachine: return "Counterbalanced — varies by machine"
        case .noBar: return "Cables, pin-loaded or plate machines — no bar weight"
        case .custom: return "Leg press sleds & machines with their own starting weight"
        }
    }

    /// True when there's no implement weight to subtract — the plate math
    /// runs against the raw target.
    var isBarless: Bool { self == .noBar }

    /// True when the starting weight comes from a user-entered value rather
    /// than a fixed preset.
    var isCustom: Bool { self == .custom }

    /// The fixed starting weight for preset bars. `.custom` has no intrinsic
    /// weight — its value is supplied separately, so callers must use
    /// `resolvedWeight(for:customWeight:)` instead.
    func weight(for unit: UnitSystem) -> Double {
        switch self {
        case .olympic: return unit == .imperial ? 45 : 20
        case .womensOlympic: return unit == .imperial ? 35 : 15
        case .ezCurl: return unit == .imperial ? 20 : 10
        case .smithMachine: return unit == .imperial ? 15 : 7
        case .noBar: return 0
        case .custom: return 0
        }
    }

    /// Resolves the starting weight, pulling in the separately-stored custom
    /// value for `.custom`. Keeping the number out of the enum means BarType
    /// stays a plain String-backed RawRepresentable that can never fail to
    /// decode from @AppStorage. A negative or missing custom weight is clamped
    /// to 0 (a barless machine) rather than producing nonsense plate math.
    func resolvedWeight(for unit: UnitSystem, customWeight: Double) -> Double {
        switch self {
        case .custom: return max(0, customWeight)
        default: return weight(for: unit)
        }
    }
}

enum PlateCalculator {

    // MARK: - Standard Sets

    static let standardPlatesLbs: [Double] = [45, 35, 25, 10, 5, 2.5]
    static let standardPlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    static func standardPlates(for unit: UnitSystem) -> [Double] {
        unit == .imperial ? standardPlatesLbs : standardPlatesKg
    }

    static func defaultBar(for unit: UnitSystem) -> Double {
        BarType.olympic.weight(for: unit)
    }

    // MARK: - Calculation

    /// Greedy fill, heaviest plate first. For standard denominations this
    /// yields the minimum plate count and never overshoots the target.
    static func calculate(target: Double, barWeight: Double, availablePlates: [Double]) -> PlateCalculation {
        let perSideTarget = max(0, (target - barWeight) / 2)
        var remaining = perSideTarget
        var loadout: [Double] = []

        for plate in availablePlates.sorted(by: >) {
            while remaining >= plate - 0.001 {
                loadout.append(plate)
                remaining -= plate
            }
        }

        return PlateCalculation(
            targetWeight: target,
            barWeight: barWeight,
            platesPerSide: loadout
        )
    }

    // MARK: - Settings Persistence (CSV in AppStorage/UserDefaults)

    static func encode(_ plates: [Double]) -> String {
        plates.sorted(by: >).map { format($0) }.joined(separator: ",")
    }

    static func decode(_ csv: String) -> [Double] {
        csv.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// "45" not "45.0", but "2.5" stays "2.5".
    static func format(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(weight)
    }
}
