import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = 0
    @State private var showPicker = false
    @State private var limit: Int = SharedStore.dailyLimit
    @State private var lock: Bool = SharedStore.lockEnabled
    @State private var requesting = false

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                intro.tag(0)
                permission.tag(1)
                setup.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color(.systemGroupedBackground))
        }
        .familyActivityPicker(isPresented: $showPicker,
                              selection: Binding(get: { model.screenTime.selection }, set: { model.screenTime.selection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { model.screenTime.saveSelection() } }
    }

    private func title(_ t: String, _ s: String) -> some View {
        VStack(spacing: 8) {
            Text(t).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(s).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 28)
        }
    }

    private var intro: some View {
        VStack(spacing: 28) {
            Spacer()
            AnimatedBrainView(rot: 0.04).frame(height: 240)
            title("Brain Health", "See what scrolling does to your brain. Pick the apps that drain you, set a daily limit, and watch your brain health on the home screen.")
            Spacer()
            Button { withAnimation { page = 1 } } label: { Text("Continue").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .padding(.horizontal, 24).padding(.bottom, 32)
        }
    }

    private var permission: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "hourglass").font(.system(size: 72, weight: .light)).foregroundStyle(.secondary)
            title("Screen Time access", "Brain Health uses Apple's Screen Time framework. Your usage stays on this device — the app only receives minute counts for the apps you choose.")
            if let err = model.screenTime.lastError, !model.screenTime.isAuthorized {
                Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
            VStack(spacing: 10) {
                if model.screenTime.isAuthorized {
                    Label("Authorised", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button { withAnimation { page = 2 } } label: { Text("Continue").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    Button {
                        requesting = true
                        Task {
                            _ = await model.screenTime.requestAuthorization()
                            requesting = false
                            if model.screenTime.isAuthorized { withAnimation { page = 2 } }
                        }
                    } label: { Text(requesting ? "Requesting…" : "Allow Screen Time").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(requesting)
                    Button { withAnimation { page = 2 } } label: { Text("Not now").frame(maxWidth: .infinity) }
                        .controlSize(.large)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
    }

    private var setup: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Label("Apps to track", systemImage: "square.grid.2x2")
                            Spacer()
                            Text(SharedStore.selectionCount == 0 ? "Choose" : "\(SharedStore.selectionCount) selected").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                    .disabled(!model.screenTime.isAuthorized)
                } footer: {
                    Text(model.screenTime.isAuthorized ? "Instagram, TikTok, YouTube — or whole categories like Social."
                                                       : "Available after Screen Time is authorised. Until then the app runs in demo mode.")
                }
                Section {
                    Picker("Daily limit", selection: $limit) {
                        ForEach(LimitOptions.all, id: \.self) { Text($0.asDuration).tag($0) }
                    }
                    Toggle("Block apps over the limit", isOn: $lock)
                } footer: {
                    Text("Brain health goes from 100% to 0% as you approach the limit. Blocking pauses the selected apps once it's reached.")
                }
            }
            .scrollContentBackground(.hidden)
            Button {
                SharedStore.dailyLimit = limit
                SharedStore.lockEnabled = lock
                if model.screenTime.isAuthorized { model.screenTime.startMonitoring() } else { SharedStore.demoMode = true }
                model.completeOnboarding()
            } label: { Text("Get started").frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .navigationTitle("Set up")
        .navigationBarTitleDisplayMode(.large)
    }
}

enum LimitOptions {
    static let all = [15, 30, 45, 60, 90, 120, 150, 180, 240]
}
