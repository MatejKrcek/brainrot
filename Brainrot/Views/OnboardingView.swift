import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = 0
    @State private var showPicker = false
    @State private var limit: Double = Double(SharedStore.dailyLimit)
    @State private var mode: GuardMode = SharedStore.mode
    @State private var requesting = false

    var body: some View {
        Screen {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    intro.tag(0)
                    how.tag(1)
                    permission.tag(2)
                    apps.tag(3)
                    rules.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: Binding(get: { model.screenTime.selection }, set: { model.screenTime.selection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { model.screenTime.saveSelection() } }
    }

    private func header(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.display(34)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(sub).font(.system(.body, design: .rounded)).foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
    }

    private var intro: some View {
        VStack(spacing: 28) {
            Spacer()
            AnimatedBrainView(rot: 0.05).frame(width: 260, height: 260)
            header("Your brain.\nOn Reels.", "Brainrot tracks Instagram, TikTok & YouTube Shorts and rots a brain on your home screen as you scroll. Stop the rot before lunch.")
            Spacer()
            PrimaryButton(title: "Let's see the damage") { withAnimation { page = 1 } }
                .padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private var how: some View {
        VStack(spacing: 28) {
            Spacer()
            HStack(spacing: -10) {
                BrainView(rot: 0).frame(width: 110, height: 110)
                BrainView(rot: 0.5).frame(width: 110, height: 110)
                BrainView(rot: 1).frame(width: 110, height: 110)
            }
            header("How it works", "")
            VStack(alignment: .leading, spacing: 14) {
                step("1", "Pick the apps that rot you.", "Reels, TikTok, Shorts — whatever your thumb craves.")
                step("2", "Your brain rots as minutes pile up.", "Live on the home screen & lock screen widgets.")
                step("3", "Locked apps cost a challenge.", "Breathe, do math, walk, hold still — then you get \(SharedStore.unlockMinutes) minutes.")
            }.padding(.horizontal, 28)
            Spacer()
            PrimaryButton(title: "Next") { withAnimation { page = 2 } }
                .padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private func step(_ n: String, _ t: String, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(n).font(.display(16)).foregroundStyle(.black)
                .frame(width: 30, height: 30).background(Circle().fill(Theme.acid))
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(.white)
                Text(s).font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.textDim)
            }
        }
    }

    private var permission: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "hourglass.circle.fill").font(.system(size: 96)).foregroundStyle(Theme.acid)
            header("Screen Time access", "Brainrot uses Apple's Screen Time API. Usage never leaves your phone — Apple won't even let the app read it directly; only the widgets get a minute count.")
            if model.screenTime.isAuthorized {
                Chip(text: "Authorized", symbol: "checkmark.seal.fill", tint: Theme.acid)
            } else if let err = model.screenTime.lastError {
                Text(err).font(.footnote).foregroundStyle(Theme.pink).multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
            VStack(spacing: 10) {
                if model.screenTime.isAuthorized {
                    PrimaryButton(title: "Next") { withAnimation { page = 3 } }
                } else {
                    PrimaryButton(title: requesting ? "Asking…" : "Allow Screen Time") {
                        requesting = true
                        Task { _ = await model.screenTime.requestAuthorization(); requesting = false
                            if model.screenTime.isAuthorized { withAnimation { page = 3 } } }
                    }
                    GhostButton(title: "Skip (demo mode, no real tracking)") { withAnimation { page = 4 } }
                }
            }.padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private var apps: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "square.grid.2x2.fill").font(.system(size: 90)).foregroundStyle(Theme.pink)
            header("What rots you?", "Pick Instagram, TikTok, YouTube… or whole categories like Social. These get tracked and locked.")
            Chip(text: SharedStore.selectionCount == 0 ? "Nothing selected yet" : "\(SharedStore.selectionCount) selected",
                 symbol: SharedStore.selectionCount == 0 ? "exclamationmark.circle" : "checkmark.circle.fill",
                 tint: SharedStore.selectionCount == 0 ? Theme.pink : Theme.acid)
            Spacer()
            VStack(spacing: 10) {
                PrimaryButton(title: "Choose apps", symbol: "plus") { showPicker = true }
                GhostButton(title: "Next") { withAnimation { page = 4 } }
                    .opacity(SharedStore.selectionCount == 0 ? 0.4 : 1)
                    .disabled(SharedStore.selectionCount == 0)
            }.padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private var rules: some View {
        VStack(spacing: 24) {
            Spacer()
            header("Set the rules", "You can change these any time.")
            VStack(spacing: 12) {
                ForEach(GuardMode.allCases) { m in
                    Button { mode = m } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(.white)
                                Text(m.subtitle).font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                            Image(systemName: mode == m ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(mode == m ? Theme.acid : Theme.textDim)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(mode == m ? Theme.acid.opacity(0.6) : Theme.cardStroke)))
                    }.buttonStyle(.plain)
                }
                Card {
                    HStack {
                        Text("Daily limit").font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(Int(limit).asDuration).font(.display(18)).foregroundStyle(Theme.acid)
                    }
                    Slider(value: $limit, in: 15...240, step: 5)
                    Text("100% rot = the limit. Liquefaction beyond it.")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                }
            }.padding(.horizontal, 24)
            Spacer()
            PrimaryButton(title: "Start rotting responsibly") {
                SharedStore.mode = mode
                SharedStore.dailyLimit = Int(limit)
                if model.screenTime.isAuthorized { model.screenTime.startMonitoring() }
                else { SharedStore.demoMode = true }
                model.completeOnboarding()
            }.padding(.horizontal, 24).padding(.bottom, 40)
        }
    }
}
