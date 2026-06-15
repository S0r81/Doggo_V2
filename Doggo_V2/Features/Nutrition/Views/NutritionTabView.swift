//
//  NutritionTabView.swift
//  Doggo_V2
//
//  Routes the Diet tab: query the active NutritionProfile and show the
//  dashboard if one exists, otherwise the intake questionnaire. When
//  onboarding saves a profile, this @Query refreshes and swaps to the
//  dashboard automatically — no manual navigation needed.
//

import SwiftUI
import SwiftData

struct NutritionTabView: View {
    @Query(sort: \NutritionProfile.createdAt, order: .reverse)
    private var profiles: [NutritionProfile]

    var body: some View {
        if let profile = profiles.first {
            NutritionDashboardView(profile: profile)
        } else {
            NutritionOnboardingView(allowsCancel: false)
        }
    }
}
