import SwiftUI
import FamilyControls

/// First-run wizard. Six gated steps: welcome, Screen Time (required), apps (at least one), websites,
/// daily limit, widget. Buttons drive navigation; there is no swiping past a step that isn't done.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    /// `--step=N` (screenshots) opens the wizard on that step.
    @State private var step: Step = {
        let n = CommandLine.arguments.first { $0.hasPrefix("--step=") }.flatMap { Int($0.dropFirst("--step=".count)) }
        return n.flatMap(Step.init(rawValue:)) ?? .welcome
    }()
    @State private var forward = true
    @State private var showPicker = false
    @State private var limit: Int = SharedStore.dailyLimit
    @State private var lock: Bool = SharedStore.lockEnabled
    @State private var requesting = false
    @State private var sites: [String] = BlockedSites.all
    @State private var siteInput = ""
    @State private var siteError: String?
    @FocusState private var siteFocused: Bool

    private enum Step: Int, CaseIterable { case welcome, screenTime, apps, websites, limit, widget }

    private var authorized: Bool { model.screenTime.isAuthorized }
    private var hasApps: Bool { SharedStore.selectionCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .familyActivityPicker(headerText: "Pick the apps that count against your brain",
                              isPresented: $showPicker,
                              selection: Binding(get: { model.screenTime.selection }, set: { model.screenTime.selection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { model.screenTime.saveSelection(); model.refresh() } }
    }

    // MARK: Navigation

    private var header: some View {
        HStack {
            Button { go(back: true) } label: { Image(systemName: "chevron.left").font(.body.weight(.semibold)) }
                .opacity(step == .welcome ? 0 : 1)
                .disabled(step == .welcome)
            Spacer()
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color(.systemFill))
                        .frame(width: s == step ? 22 : 8, height: 8)
                }
            }
            .animation(.snappy, value: step)
            Spacer()
            Image(systemName: "chevron.left").font(.body.weight(.semibold)).opacity(0)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
    }

    private func go(back: Bool = false) {
        let next = back ? step.rawValue - 1 : step.rawValue + 1
        guard let target = Step(rawValue: next) else { return }
        forward = !back
        withAnimation(.easeInOut(duration: 0.3)) { step = target }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .screenTime: screenTime
        case .apps: apps
        case .websites: websites
        case .limit: limitStep
        case .widget: widget
        }
    }

    // MARK: Shared pieces

    private func title(_ t: String, _ s: String) -> some View {
        VStack(spacing: 8) {
            Text(t).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(s).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }

    private func primary(_ label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(disabled)
    }

    private var footerPadding: EdgeInsets { EdgeInsets(top: 8, leading: 24, bottom: 24, trailing: 24) }

    // MARK: 1. Welcome

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            AnimatedBrainView(rot: 0.04).frame(height: 240)
            title("Brain Health", "See what scrolling does to your brain. Pick the apps that drain you, set a daily limit, and watch your brain on the Home Screen.")
            Spacer()
            VStack(spacing: 12) {
                primary("Set up") { go() }
                Text("Takes about a minute.").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(footerPadding)
        }
    }

    // MARK: 2. Screen Time (required)

    private var screenTime: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "hourglass").font(.system(size: 72, weight: .light)).foregroundStyle(.secondary)
            title("Allow Screen Time", "Brain Health counts minutes and blocks apps through Apple's Screen Time. Without it the app can't do anything, so this step is required.")
            VStack(alignment: .leading, spacing: 10) {
                bullet("lock.shield", "Your usage never leaves this iPhone.")
                bullet("eye.slash", "The app only gets minute counts for the apps you pick.")
                bullet("hand.raised", "iOS asks you once; you can change it later in Settings › Screen Time.")
            }
            .padding(.horizontal, 32)
            if let err = model.screenTime.lastError, !authorized {
                Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
            VStack(spacing: 10) {
                if authorized {
                    Label("Screen Time allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    primary("Continue") { go() }
                } else {
                    primary(requesting ? "Asking iOS…" : "Allow Screen Time", disabled: requesting) {
                        requesting = true
                        Task {
                            let ok = await model.screenTime.requestAuthorization()
                            requesting = false
                            if ok { go() }
                        }
                    }
                    #if targetEnvironment(simulator)
                    Button("Simulator: continue without Screen Time") { SharedStore.demoMode = true; go() }
                        .font(.footnote)
                    #endif
                }
            }
            .padding(footerPadding)
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: 3. Apps (at least one)

    private var apps: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "square.grid.2x2").font(.system(size: 72, weight: .light)).foregroundStyle(.secondary)
            title("Pick the apps that drain you", "Instagram, TikTok, YouTube, or a whole category like Social. Only these apps are counted and blocked.")
            Button { showPicker = true } label: {
                HStack {
                    Label("Choose apps", systemImage: "plus.circle.fill")
                    Spacer()
                    Text(hasApps ? "\(SharedStore.selectionCount) selected" : "None yet").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .tint(.primary)
            .disabled(!authorized)
            .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 10) {
                primary("Continue", disabled: !hasApps) { go() }
                if !hasApps {
                    Text(authorized ? "Pick at least one app to continue." : "Screen Time isn't allowed, so the picker can't open.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                #if targetEnvironment(simulator)
                if !authorized { Button("Simulator: skip") { go() }.font(.footnote) }
                #endif
            }
            .padding(footerPadding)
        }
    }

    // MARK: 4. Websites (optional, blocked all day)

    private var websites: some View {
        VStack(spacing: 0) {
            title("Block websites completely", "Sites on this list are blocked all day in Safari, Chrome and every other browser. No limit, no unblock window: zero minutes.")
                .padding(.top, 12)
            Form {
                Section {
                    HStack {
                        TextField("instagram.com", text: $siteInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($siteFocused)
                            .submitLabel(.done)
                            .onSubmit(addSite)
                        Button("Add", action: addSite)
                            .disabled(siteInput.trimmingCharacters(in: .whitespaces).isEmpty || !authorized)
                    }
                    if let siteError {
                        Text(siteError).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Add a website")
                } footer: {
                    Text("Paste a link or type a domain. Optional; you can add more later in Settings.")
                }
                if !sites.isEmpty {
                    Section("Blocked all day") {
                        ForEach(sites, id: \.self) { Label($0, systemImage: "globe") }
                            .onDelete { offsets in
                                for i in offsets { BlockedSites.remove(sites[i]) }
                                syncSites()
                            }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            primary(sites.isEmpty ? "Skip" : "Continue") { siteFocused = false; go() }
                .padding(footerPadding)
        }
    }

    private func addSite() {
        guard authorized else { return }
        guard BlockedSites.normalize(siteInput) != nil else {
            siteError = "That doesn't look like a website. Try something like youtube.com."; return
        }
        guard BlockedSites.add(siteInput) else {
            siteError = "You can block up to \(BlockedSites.maxCount) websites."; return
        }
        siteInput = ""; siteError = nil
        syncSites()
    }

    private func syncSites() {
        sites = BlockedSites.all
        if authorized { WebsiteBlocker.apply() }
    }

    // MARK: 5. Limit & blocking

    private var limitStep: some View {
        VStack(spacing: 0) {
            title("Set your daily limit", "Brain health goes from 100% at zero usage to 0% at the limit.")
                .padding(.top, 12)
            Form {
                Section {
                    Picker("Daily limit", selection: $limit) {
                        ForEach(LimitOptions.all, id: \.self) { Text($0.asDuration).tag($0) }
                    }
                    Toggle("Block apps over the limit", isOn: $lock)
                } footer: {
                    Text("With blocking on, the apps you picked show a Brain Health screen once the limit is reached. You can unblock for 15 minutes from the app if you really need to.")
                }
            }
            .scrollContentBackground(.hidden)
            primary("Continue") {
                SharedStore.dailyLimit = limit
                SharedStore.lockEnabled = lock
                go()
            }
            .padding(footerPadding)
        }
    }

    // MARK: 6. Widgets

    private var widget: some View {
        VStack(spacing: 28) {
            Spacer()
            HStack(spacing: 14) {
                widgetTile(name: "Screen time") {
                    HStack(spacing: 8) {
                        AnimatedBrainView(rot: 0).frame(width: 56, height: 48)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("100%").font(.title3.bold())
                            Text("\(limit.asDuration) left").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                widgetTile(name: "Brain") {
                    AnimatedBrainView(rot: 0.12).frame(width: 96, height: 82)
                }
            }
            title("Two widgets come with the app", "Screen time shows your brain with today's minutes and what's left. Brain is the brain alone. Both update as you use the tracked apps, and both work on the Lock Screen too.")
            VStack(alignment: .leading, spacing: 10) {
                bullet("1.circle", "Long-press an empty spot on the Home Screen.")
                bullet("2.circle", "Tap + (or Edit) in the top corner.")
                bullet("3.circle", "Search for Brain Health and pick Screen time or Brain.")
            }
            .padding(.horizontal, 32)
            Spacer()
            primary("Get started") { finish() }
                .padding(footerPadding)
        }
    }

    private func widgetTile<Content: View>(name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
                .frame(width: 140, height: 120)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func finish() {
        SharedStore.dailyLimit = limit
        SharedStore.lockEnabled = lock
        if authorized {
            model.screenTime.startMonitoring()
            WebsiteBlocker.apply()
        } else {
            SharedStore.demoMode = true
        }
        model.completeOnboarding()
        model.reloadWidgets(force: true)
    }
}

enum LimitOptions {
    static let all = [15, 30, 45, 60, 90, 120, 150, 180, 240]
}
