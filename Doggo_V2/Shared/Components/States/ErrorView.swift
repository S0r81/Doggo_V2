// FILE: Doggo_V2/Shared/Components/States/ErrorView.swift

import SwiftUI

struct ErrorView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    
    init(title: String, message: String, retryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry = retryAction {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ErrorView(
        title: "Connection Failed",
        message: "Unable to reach the server",
        retryAction: {}
    )
}
