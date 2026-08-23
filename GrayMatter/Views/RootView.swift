import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.onboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: model.onboarded)
    }
}
