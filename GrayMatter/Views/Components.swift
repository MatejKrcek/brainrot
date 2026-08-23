import SwiftUI

/// Inset-grouped style card, like a Form section but usable inside a ScrollView.
struct Card<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// A label/value row with the standard list look.
struct Row<Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(.secondary).frame(width: 22) }
            Text(title)
            Spacer()
            trailing.foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}

struct Divider2: View {
    var body: some View { Divider().padding(.leading, 0) }
}
