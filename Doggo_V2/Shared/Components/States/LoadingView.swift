// FILE: Doggo_V2/Shared/Components/States/LoadingView.swift

import SwiftUI

struct LoadingView: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LoadingView(message: "Generating workout...")
}
