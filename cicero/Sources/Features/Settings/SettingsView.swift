import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: CiceroSettings
    @State private var draftKey = ""
    @State private var showingAddHost = false

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                modelSection
                remoteSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddHost) {
                AddHostSheet { settings.addHost($0) }
            }
        }
    }

    private var apiKeySection: some View {
        Section {
            HStack {
                Text("Anthropic key")
                Spacer()
                Text(settings.hasAPIKey ? "Set" : "Not set")
                    .foregroundStyle(settings.hasAPIKey ? CiceroTheme.good : CiceroTheme.warn)
            }
            SecureField("sk-ant-…", text: $draftKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            HStack {
                Button("Save key") {
                    settings.setAPIKey(draftKey)
                    draftKey = ""
                }
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                if settings.hasAPIKey {
                    Button("Clear", role: .destructive) { settings.clearAPIKey() }
                }
            }
        } header: {
            Text("Agent")
        } footer: {
            Text("Stored in the iOS Keychain — never in the repo. Get a key at console.anthropic.com.")
        }
    }

    private var modelSection: some View {
        Section("Model") {
            Picker("Model", selection: $settings.modelID) {
                ForEach(AgentModel.all) { model in
                    Text(model.name).tag(model.id)
                }
            }
            Picker("Effort", selection: $settings.effort) {
                ForEach(AgentEffort.allCases) { effort in
                    Text(effort.label).tag(effort.rawValue)
                }
            }
        }
    }

    private var remoteSection: some View {
        Section {
            if settings.hosts.isEmpty {
                Text("No hosts yet").foregroundStyle(CiceroTheme.faint)
            } else {
                ForEach(settings.hosts) { host in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(host.name).font(CiceroTheme.ui(15, weight: .medium))
                        Text("\(host.username)@\(host.hostname):\(host.port)")
                            .font(CiceroTheme.mono(12))
                            .foregroundStyle(CiceroTheme.ink2)
                    }
                }
                .onDelete { settings.removeHosts(at: $0) }
            }
            Button {
                showingAddHost = true
            } label: {
                Label("Add host", systemImage: "plus")
            }
        } header: {
            Text("Remote machines")
        } footer: {
            Text("Configure dev boxes now; driving them from the phone (SSH / relay over your Tailnet) is the next milestone — see cicero/README.md.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion).foregroundStyle(CiceroTheme.ink2)
            }
            Text("Cicero — vibe coding in your pocket.")
                .font(CiceroTheme.ui(13))
                .foregroundStyle(CiceroTheme.ink2)
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// Sheet for adding a remote dev host.
private struct AddHostSheet: View {
    var onAdd: (RemoteHost) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. archbox)", text: $name)
                    .autocorrectionDisabled()
                TextField("Hostname or IP", text: $hostname)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Add host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(RemoteHost(
                            name: name.isEmpty ? hostname : name,
                            hostname: hostname.trimmingCharacters(in: .whitespaces),
                            username: username.trimmingCharacters(in: .whitespaces),
                            port: Int(port) ?? 22))
                        dismiss()
                    }
                    .disabled(hostname.trimmingCharacters(in: .whitespaces).isEmpty
                              || username.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
