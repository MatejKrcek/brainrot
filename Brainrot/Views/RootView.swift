import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.onboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: model.onboarded)
    }
}

struct MainTabView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView(selection: $model.tab) {
            DashboardView()
                .tabItem { Label("Brain", systemImage: "brain.head.profile") }
                .tag(Tab.brain)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(Tab.stats)
            CoachView()
                .tabItem { Label("Dr. Brain", systemImage: "stethoscope") }
                .tag(Tab.coach)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .toolbarBackground(Theme.bg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $model.showChallenge) {
            ChallengeFlowView()
                .environmentObject(model)
                .presentationDragIndicator(.visible)
        }
    }
}
