import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("appearanceMode") private var appearanceMode = 0 // 0=system, 1=light, 2=dark
    @AppStorage("eventSortOrder") private var eventSortOrder = 0 // 0=date, 1=distance
    @AppStorage("searchRadiusMiles") private var searchRadiusMiles = 30.0
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            List {
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

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Event Sort Order") {
                    Picker("Sort By", selection: $eventSortOrder) {
                        Text("Date").tag(0)
                        Text("Distance").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Discovery Radius") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Search within")
                            Spacer()
                            Text("\(Int(searchRadiusMiles)) miles")
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                        Slider(value: $searchRadiusMiles, in: 5...50, step: 5)
                            .tint(.green)
                        HStack {
                            Text("5 mi")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("50 mi")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Controls how far Ticketmaster searches for events. Curated events always show regardless of radius.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .accessibilityHint("Controls session reminders and push notifications")
                    Toggle("Quiet Hours (10PM–8AM)", isOn: $quietHoursEnabled)
                        .disabled(!notificationsEnabled)
                        .foregroundStyle(notificationsEnabled ? .primary : .secondary)
                        .accessibilityHint(notificationsEnabled ? "Silences notifications between 10 PM and 8 AM" : "Enable notifications first")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("City")
                        Spacer()
                        Text(CityConfig.settingsCityLabel)
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
        // Delete individually to avoid batch delete constraint issues
        let savedItems = (try? modelContext.fetch(FetchDescriptor<UserSavedItem>())) ?? []
        for item in savedItems { modelContext.delete(item) }

        let scheduleItems = (try? modelContext.fetch(FetchDescriptor<ScheduleItem>())) ?? []
        for item in scheduleItems { modelContext.delete(item) }

        let pins = (try? modelContext.fetch(FetchDescriptor<MapPin>())) ?? []
        for pin in pins { modelContext.delete(pin) }

        let stages = (try? modelContext.fetch(FetchDescriptor<Stage>())) ?? []
        for stage in stages { modelContext.delete(stage) }

        let events = (try? modelContext.fetch(FetchDescriptor<Event>())) ?? []
        for event in events { modelContext.delete(event) }

        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
