import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("ticketmasterAPIKey") private var apiKey = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @Query private var events: [Event]
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Ticketmaster API Key", systemImage: "key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        SecureField("Enter API key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("Get a free key at developer.ticketmaster.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Event Data")
                } footer: {
                    if apiKey.isEmpty {
                        Label("No API key set — the Discover tab won't fetch events.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("API key saved. Pull to refresh in Discover to fetch events.", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section("Data") {
                    HStack {
                        Text("Cached Events")
                        Spacer()
                        Text("\(events.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear All Events", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Quiet Hours (10PM–8AM)", isOn: $quietHoursEnabled)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 MVP")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("City")
                        Spacer()
                        Text("Seattle, WA")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Data Source")
                        Spacer()
                        Text("Ticketmaster Discovery API")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Label("Canopy — One app for every event.", systemImage: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear All Events?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    clearAllEvents()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all cached events. You can re-fetch them from Ticketmaster.")
            }
        }
    }

    private func clearAllEvents() {
        do {
            try modelContext.delete(model: UserSavedItem.self)
            try modelContext.delete(model: ScheduleItem.self)
            try modelContext.delete(model: MapPin.self)
            try modelContext.delete(model: Stage.self)
            try modelContext.delete(model: Event.self)
        } catch {
            print("Failed to clear events: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
