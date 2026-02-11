// FILE: Doggo_V2/Shared/Components/States/EmptyStateView.swift

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    EmptyStateView(
        icon: "dumbbell.fill",
        title: "No Workouts Yet",
        message: "Start your fitness journey",
        actionTitle: "Start Workout",
        action: {}
    )
}
