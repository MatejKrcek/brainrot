import SwiftUI

/// Websites typed in by hand that stay blocked all day in Safari, Chrome and other browsers.
struct BlockedSitesView: View {
    @EnvironmentObject var model: AppModel
    @State private var sites: [String] = BlockedSites.all
    @State private var input = ""
    @State private var error: String?
    @State private var requesting = false
    @FocusState private var focused: Bool

    private var authorized: Bool { model.screenTime.isAuthorized }

    var body: some View {
        Form {
            if !authorized {
                Section {
                    Button(requesting ? "Opening…" : "Allow Screen Time access") { requestAccess() }
                        .disabled(requesting)
                } footer: {
                    Text("iOS only lets Brain Health block websites with Screen Time access.")
                }
            }

            Section {
                HStack {
                    TextField("instagram.com", text: $input)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || !authorized)
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("Add a website")
            } footer: {
                Text("Paste a link or type a domain. The whole site is blocked, including its subpages.")
            }

            Section {
                if sites.isEmpty {
                    Text("No websites yet").foregroundStyle(.secondary)
                }
                ForEach(sites, id: \.self) { domain in
                    Label(domain, systemImage: "globe")
                }
                .onDelete { offsets in
                    for i in offsets { BlockedSites.remove(sites[i]) }
                    sync()
                }
            } header: {
                Text("Blocked all day")
            } footer: {
                Text("Blocked in Safari, Chrome and every other browser on this iPhone, regardless of your daily limit. Swipe left to remove. Up to \(BlockedSites.maxCount) websites.")
            }
        }
        .navigationTitle("Blocked websites")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        guard authorized else { return }
        guard BlockedSites.normalize(input) != nil else {
            error = "That doesn't look like a website. Try something like youtube.com."
            return
        }
        guard BlockedSites.add(input) else {
            error = "You can block up to \(BlockedSites.maxCount) websites."
            return
        }
        input = ""
        error = nil
        focused = false
        sync()
    }

    private func sync() {
        sites = BlockedSites.all
        WebsiteBlocker.apply()
    }

    private func requestAccess() {
        requesting = true
        Task {
            _ = await model.screenTime.requestAuthorization()
            requesting = false
            if authorized { WebsiteBlocker.apply() }
        }
    }
}
