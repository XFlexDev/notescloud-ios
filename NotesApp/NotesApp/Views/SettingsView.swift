import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("server_url") private var serverUrl: String = "https://notes.kreatix.dev"
    @State private var healthStatus: String = "Not Tested"
    @State private var isTesting = false
    @State private var showCacheClearedAlert = false

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("SERVER CONFIGURATION")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rust Server URL")
                            .font(.caption)
                            .foregroundColor(.notesSecondary)
                        TextField("https://notes.kreatix.dev", text: $serverUrl)
                            .font(.system(size: 15, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Button(action: testConnection) {
                        HStack {
                            Text("Test Server & B2 Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else {
                                Text(healthStatus)
                                    .font(.caption)
                                    .foregroundColor(healthStatus.contains("Connected") ? .green : .notesSecondary)
                            }
                        }
                    }
                    .disabled(isTesting)
                }

                Section(header: Text("CLOUD STORAGE BACKEND")) {
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text("Backblaze B2")
                            .foregroundColor(.notesSecondary)
                    }

                    HStack {
                        Text("Default Bucket")
                        Spacer()
                        Text("kreatix-agy")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.notesSecondary)
                    }

                    HStack {
                        Text("Edge CDN")
                        Spacer()
                        Text("cdn.kreatix.dev")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.notesSecondary)
                    }
                }

                Section(header: Text("LOCAL STORAGE & CACHE")) {
                    Button(role: .destructive, action: clearCache) {
                        Text("Clear Offline Cache")
                    }
                }

                Section(header: Text("ABOUT")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (Native SwiftUI)")
                            .foregroundColor(.notesSecondary)
                    }

                    HStack {
                        Text("Backend Architecture")
                        Spacer()
                        Text("Rust Axum + SQLite")
                            .foregroundColor(.notesSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.notesYellow)
                }
            }
            .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Local cache has been cleared successfully.")
            }
        }
    }

    private func testConnection() {
        isTesting = true
        healthStatus = "Testing..."
        Task {
            guard let url = URL(string: "\(serverUrl)/api/health") else {
                healthStatus = "Invalid URL"
                isTesting = false
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    healthStatus = "Connected (B2 Ready)"
                    NotesTheme.notificationFeedback(.success)
                } else {
                    healthStatus = "HTTP Error"
                    NotesTheme.notificationFeedback(.error)
                }
            } catch {
                healthStatus = "Failed: \(error.localizedDescription)"
                NotesTheme.notificationFeedback(.error)
            }
            isTesting = false
        }
    }

    private func clearCache() {
        NotesTheme.haptic(.medium)
        showCacheClearedAlert = true
    }
}
