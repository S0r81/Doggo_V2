import SwiftUI

private struct AppContainerKey: EnvironmentKey {
    // We provide a dummy default, but it should always be injected at the root
    static let defaultValue: AppContainer? = nil
}

extension EnvironmentValues {
    var appContainer: AppContainer? {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
