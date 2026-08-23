import SwiftUI

/// Picks a challenge, runs it, and grants the unlock on success.
struct ChallengeFlowView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ChallengeKind = .breathe
    @State private var passed = false

    var body: some View {
        Screen {
            if passed {
                success
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Label(kind.title, systemImage: kind.symbol)
                            .font(.display(18)).foregroundStyle(.white)
                        Spacer()
                        Button { reroll() } label: {
                            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Theme.textDim)
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 22)
                    Text("Pass this and you get \(SharedStore.unlockMinutes) minutes. No shortcuts.")
                        .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 4)
                    Group {
                        switch kind {
                        case .breathe: BreatheChallenge(onDone: pass)
                        case .math: MathChallenge(onDone: pass)
                        case .type: TypeChallenge(onDone: pass)
                        case .hold: HoldChallenge(onDone: pass)
                        case .walk: WalkChallenge(onDone: pass)
                        case .random: EmptyView()
                        }
                    }
                    .id(kind)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { kind = resolveKind(SharedStore.challengeKind) }
    }

    private func resolveKind(_ k: ChallengeKind) -> ChallengeKind {
        k == .random ? (ChallengeKind.allCases.filter { $0 != .random }.randomElement() ?? .breathe) : k
    }

    private func reroll() {
        let others = ChallengeKind.allCases.filter { $0 != .random && $0 != kind }
        kind = others.randomElement() ?? .math
    }

    private func pass() {
        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
        model.grantUnlock()
        withAnimation(.spring) { passed = true }
    }

    private var success: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(Theme.acid.opacity(0.15)).frame(width: 200, height: 200)
                BrainView(rot: max(0, model.snap.rot - 0.1)).frame(width: 150, height: 150)
            }
            Text("Unlocked").font(.display(36)).foregroundStyle(.white)
            if let u = model.lastUnlockGranted {
                Text("Scroll until \(u.formatted(date: .omitted, time: .shortened)). Then it locks again. Set a mental timer — or don't, the brain will tell you.")
                    .font(.system(.body, design: .rounded)).foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            PrimaryButton(title: "Go scroll, you animal", symbol: "arrow.up.right") { dismiss() }
                .padding(.horizontal, 24).padding(.bottom, 30)
        }
    }
}

// MARK: - Breathe (4-7-8 × 3)

struct BreatheChallenge: View {
    var onDone: () -> Void
    private let phases: [(String, Double)] = [("Inhale", 4), ("Hold", 7), ("Exhale", 8)]
    private let rounds = 3
    @State private var round = 0
    @State private var phaseIdx = 0
    @State private var remaining: Double = 4
    @State private var scale: CGFloat = 0.55
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().fill(Theme.violet.opacity(0.18)).frame(width: 260, height: 260)
                Circle().fill(LinearGradient(colors: [Theme.violet, Theme.pink], startPoint: .top, endPoint: .bottom))
                    .frame(width: 220, height: 220).scaleEffect(scale)
                    .shadow(color: Theme.violet.opacity(0.5), radius: 30)
                VStack {
                    Text(phases[phaseIdx].0).font(.display(28)).foregroundStyle(.white)
                    Text("\(Int(ceil(remaining)))").font(.display(20)).foregroundStyle(.white.opacity(0.8))
                }
            }
            Text("Round \(round + 1) of \(rounds) · 4-7-8 breathing").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.textDim)
            Spacer()
        }
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        applyPhase()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            remaining -= 0.1
            if remaining <= 0 {
                phaseIdx += 1
                if phaseIdx >= phases.count {
                    phaseIdx = 0; round += 1
                    if round >= rounds { timer?.invalidate(); onDone(); return }
                }
                applyPhase()
            }
        }
    }

    private func applyPhase() {
        remaining = phases[phaseIdx].1
        let target: CGFloat = phaseIdx == 0 ? 1.0 : (phaseIdx == 1 ? 1.0 : 0.55)
        withAnimation(.easeInOut(duration: phases[phaseIdx].1)) { scale = target }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

// MARK: - Math (5 in a row)

struct MathChallenge: View {
    var onDone: () -> Void
    @State private var a = 0
    @State private var b = 0
    @State private var op = "+"
    @State private var answer = ""
    @State private var correct = 0
    @State private var shake = 0
    @FocusState private var focused: Bool
    private let needed = 5

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<needed, id: \.self) { i in
                    Capsule().fill(i < correct ? Theme.acid : .white.opacity(0.12)).frame(height: 6)
                }
            }.padding(.horizontal, 40)
            Text("\(a) \(op) \(b) = ?").font(.display(48)).foregroundStyle(.white)
                .modifier(Shake(trigger: shake))
            TextField("answer", text: $answer)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .font(.display(34))
                .foregroundStyle(Theme.acid)
                .focused($focused)
                .submitLabel(.go)
                .onSubmit(check)
                .padding(.horizontal, 40)
            PrimaryButton(title: "Check") { check() }.padding(.horizontal, 40)
            Text("\(needed) correct in a row. A wrong answer resets the streak.")
                .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
            Spacer()
        }
        .onAppear { next(); focused = true }
    }

    private func next() {
        let ops = ["+", "-", "×"]
        op = ops.randomElement()!
        switch op {
        case "+": a = Int.random(in: 17...89); b = Int.random(in: 17...89)
        case "-": a = Int.random(in: 40...99); b = Int.random(in: 11...(a - 1))
        default: a = Int.random(in: 6...14); b = Int.random(in: 6...14)
        }
        answer = ""
    }

    private var expected: Int { op == "+" ? a + b : (op == "-" ? a - b : a * b) }

    private func check() {
        guard let v = Int(answer.trimmingCharacters(in: .whitespaces)) else { return }
        if v == expected {
            correct += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if correct >= needed { onDone(); return }
        } else {
            correct = 0
            shake += 1
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        next()
    }
}

struct Shake: GeometryEffect {
    var trigger: Int
    var animatableData: CGFloat { get { CGFloat(trigger) } set { trigger = Int(newValue) } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 6), y: 0))
    }
}

// MARK: - Type the vow

struct TypeChallenge: View {
    var onDone: () -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    private let vows = [
        "I am choosing to scroll for a few minutes and then I will put the phone down.",
        "My attention is the most valuable thing I own and I am renting it out for free.",
        "Nothing in this feed will matter tomorrow, but my focus will.",
        "I will close the app when the timer ends. I mean it this time."
    ]
    @State private var vow = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Type this exactly:").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.textDim)
            Text(vow).font(.display(22, weight: .bold)).foregroundStyle(.white)
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            TextField("Start typing…", text: $text, axis: .vertical)
                .lineLimit(3...5)
                .font(.system(.body, design: .rounded))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                .padding(.horizontal, 24)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .onChange(of: text) { old, new in
                    // Block paste: more than 2 characters at once is suspicious.
                    if new.count - old.count > 2 { text = old; return }
                    if normalize(new) == normalize(vow) { onDone() }
                }
            progress
            Spacer()
        }
        .onAppear { vow = vows.randomElement()!; focused = true }
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var progress: some View {
        let n = normalize(vow), t = normalize(text)
        let matched = zip(n, t).prefix { $0 == $1 }.count
        return Text("\(matched)/\(n.count) characters")
            .font(.system(.footnote, design: .rounded).monospacedDigit())
            .foregroundStyle(matched == t.count ? Theme.textDim : Theme.pink)
    }
}

// MARK: - Hold still (30 s)

struct HoldChallenge: View {
    var onDone: () -> Void
    @State private var holding = false
    @State private var progress: Double = 0
    @State private var timer: Timer?
    private let seconds: Double = 30

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 14).frame(width: 240, height: 240)
                Circle().trim(from: 0, to: progress)
                    .stroke(AngularGradient(colors: [Theme.acid, Theme.pink], center: .center), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 240, height: 240)
                Circle().fill(holding ? Theme.acid : Theme.card).frame(width: 180, height: 180)
                    .scaleEffect(holding ? 0.95 : 1)
                    .animation(.spring(duration: 0.25), value: holding)
                VStack {
                    Text(holding ? "\(Int(ceil(seconds - progress * seconds)))" : "HOLD")
                        .font(.display(holding ? 44 : 30)).foregroundStyle(holding ? .black : .white)
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding { begin() } }
                .onEnded { _ in cancel() })
            Text("Press and hold for 30 seconds. Let go and it resets.\nLook at something that isn't a screen.")
                .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim).multilineTextAlignment(.center)
            Spacer()
        }
        .onDisappear { timer?.invalidate() }
    }

    private func begin() {
        holding = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            progress += 0.05 / seconds
            if progress >= 1 { timer?.invalidate(); onDone() }
        }
    }

    private func cancel() {
        guard holding else { return }
        holding = false
        timer?.invalidate()
        if progress < 1 { withAnimation { progress = 0 }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }
}

// MARK: - Walk (60 steps)

struct WalkChallenge: View {
    var onDone: () -> Void
    @StateObject private var counter = StepCounter()
    private let goal = 60

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.walk.motion").font(.system(size: 80)).foregroundStyle(Theme.acid)
                .symbolEffect(.pulse)
            Text("\(min(counter.steps, goal)) / \(goal)").font(.display(54)).foregroundStyle(.white)
                .contentTransition(.numericText())
            Text("steps").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.textDim)
            ProgressView(value: Double(min(counter.steps, goal)), total: Double(goal))
                .tint(Theme.acid).padding(.horizontal, 60)
            if counter.unavailable {
                Text("Step counting isn't available here. Reroll for another challenge (↻ top right).")
                    .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.pink).multilineTextAlignment(.center).padding(.horizontal)
            } else {
                Text("Phone in hand or pocket. Go get water. Come back.")
                    .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
            }
            Spacer()
        }
        .onAppear { counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.steps) { _, s in if s >= goal { counter.stop(); onDone() } }
    }
}
