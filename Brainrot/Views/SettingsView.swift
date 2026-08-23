import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var limit: Double = Double(SharedStore.dailyLimit)
    @State private var mode: GuardMode = SharedStore.mode
    @State private var unlockMinutes: Int = SharedStore.unlockMinutes
    @State private var challenge: ChallengeKind = SharedStore.challengeKind
    @State private var language: String = SharedStore.coachLanguage
    @State private var apiKey: String = AICoach.apiKey ?? ""
    @State private var showPicker = false
    @State private var confirmReset = false

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings").font(.display(34)).foregroundStyle(.white).padding(.top, 8)

                    // Screen Time
                    Card {
                        SectionTitle(text: "Screen Time")
                        HStack {
                            Image(systemName: model.screenTime.isAuthorized ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundStyle(model.screenTime.isAuthorized ? Theme.acid : Theme.pink)
                            Text(model.screenTime.isAuthorized ? "Authorized" : "Not authorized")
                                .font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(.white)
                            Spacer()
                            if !model.screenTime.isAuthorized {
                                Button("Allow") { Task { _ = await model.screenTime.requestAuthorization() } }
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                            }
                        }
                        if model.screenTime.isAuthorized {
                            Toggle(isOn: Binding(get: { SharedStore.isMonitoring },
                                                 set: { on in on ? model.screenTime.startMonitoring() : model.screenTime.stopMonitoring(); model.refresh() })) {
                                Text("Track & lock selected apps").font(.system(.body, design: .rounded)).foregroundStyle(.white)
                            }.tint(Theme.acid)
                            Button { showPicker = true } label: {
                                HStack {
                                    Text("Tracked apps").font(.system(.body, design: .rounded)).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(SharedStore.selectionCount) selected").foregroundStyle(Theme.textDim)
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.textDim)
                                }
                            }
                        }
                        if let err = model.screenTime.lastError {
                            Text(err).font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.pink)
                        }
                    }

                    // Rules
                    Card {
                        SectionTitle(text: "Rules")
                        Picker("Mode", selection: $mode) {
                            ForEach(GuardMode.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        Text(mode.subtitle).font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
                        HStack {
                            Text("Daily limit").font(.system(.body, design: .rounded)).foregroundStyle(.white)
                            Spacer()
                            Text(Int(limit).asDuration).font(.display(16)).foregroundStyle(Theme.acid)
                        }
                        Slider(value: $limit, in: 15...240, step: 5)
                        HStack {
                            Text("Unlock window").font(.system(.body, design: .rounded)).foregroundStyle(.white)
                            Spacer()
                            Picker("", selection: $unlockMinutes) {
                                ForEach([15, 30, 45], id: \.self) { Text("\($0) min").tag($0) }
                            }.pickerStyle(.menu)
                        }
                        Text("iOS enforces a 15-minute minimum for unlock windows.")
                            .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                    }

                    // Challenge
                    Card {
                        SectionTitle(text: "Challenge")
                        ForEach(ChallengeKind.allCases) { k in
                            Button { challenge = k } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: k.symbol).frame(width: 24).foregroundStyle(Theme.acid)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(k.title).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(.white)
                                        Text(k.blurb).font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                                    }
                                    Spacer()
                                    Image(systemName: challenge == k ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(challenge == k ? Theme.acid : Theme.textDim)
                                }.padding(.vertical, 4)
                            }.buttonStyle(.plain)
                        }
                    }

                    // Coach
                    Card {
                        SectionTitle(text: "Dr. Brain")
                        Picker("Language", selection: $language) {
                            Text("Čeština").tag("cs"); Text("English").tag("en")
                        }.pickerStyle(.segmented)
                        SecureField("Anthropic API key (sk-ant-…)", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                        Text("Optional. Stored in the Keychain, used only to call api.anthropic.com for verdicts. Without it you get built-in roasts.")
                            .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                    }

                    // Widgets
                    Card {
                        SectionTitle(text: "Widgets")
                        Text("Long-press the home screen → + → Brainrot. Small, medium and large, plus lock-screen circle / rectangle / inline. They refresh as minutes tick.")
                            .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
                    }

                    // Danger zone
                    Card {
                        SectionTitle(text: "Demo & reset")
                        Button("Seed demo history") { model.demoSeedHistory() }
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Button("Reset everything", role: .destructive) { confirmReset = true }
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }

                    Text("Brainrot v1.0 · made for one specific brain")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 18).padding(.bottom, 30)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: Binding(get: { model.screenTime.selection }, set: { model.screenTime.selection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { model.screenTime.saveSelection(); model.refresh() } }
        .onChange(of: limit) { _, v in SharedStore.dailyLimit = Int(v); applyRules() }
        .onChange(of: mode) { _, v in SharedStore.mode = v; applyRules() }
        .onChange(of: unlockMinutes) { _, v in SharedStore.unlockMinutes = v }
        .onChange(of: challenge) { _, v in SharedStore.challengeKind = v }
        .onChange(of: language) { _, v in SharedStore.coachLanguage = v }
        .onChange(of: apiKey) { _, v in Keychain.set(v.trimmingCharacters(in: .whitespacesAndNewlines), for: AICoach.keychainKey) }
        .confirmationDialog("Reset all data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) {
                model.screenTime.stopMonitoring()
                SharedStore.resetAll()
                model.onboarded = false
                model.refresh()
            }
        } message: { Text("History, streak, settings and app selection will be wiped. The brain gets a fresh start. You don't.") }
    }

    private func applyRules() {
        if model.screenTime.isAuthorized && SharedStore.isMonitoring { ShieldController.reconcile() }
        model.refresh()
    }
}
