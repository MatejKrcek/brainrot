import SwiftUI

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.cardStroke))
            )
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Theme.acid
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.display(17, weight: .heavy))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(tint))
            .shadow(color: tint.opacity(0.35), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var symbol: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.display(15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = .white
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(Theme.textDim)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = .white
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.display(22)).foregroundStyle(tint).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.cardStroke)))
    }
}

struct Screen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            content
        }
    }
}
