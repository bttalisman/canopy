import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @State private var showingClearConfirmation = false

    private var hasAPIKey: Bool {
        let key = Secrets.ticketmasterAPIKey
        return !key.isEmpty && key != "YOUR_KEY_HERE"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Event Data") {
                    HStack {
                        Label("Ticketmaster API", systemImage: "key")
                        Spacer()
                        if hasAPIKey {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Label("Not set", systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }

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
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Toggle("Quiet Hours (10PM–8AM)", isOn: .constant(false))
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
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image("CanopyLogo")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Text("Canopy")
                                .font(.headline)
                            Text("One app for every event.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
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
