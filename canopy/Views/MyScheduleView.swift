import SwiftUI
import SwiftData

struct MyScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSavedItem.savedAt) private var savedItems: [UserSavedItem]

    var savedSessions: [UserSavedItem] {
        savedItems
            .filter { $0.scheduleItem != nil }
            .sorted { ($0.scheduleItem?.startTime ?? .distantPast) < ($1.scheduleItem?.startTime ?? .distantPast) }
    }

    var savedEvents: [UserSavedItem] {
        savedItems
            .filter { $0.event != nil && $0.scheduleItem == nil }
            .sorted { ($0.event?.startDate ?? .distantPast) < ($1.event?.startDate ?? .distantPast) }
    }

    var conflicts: [(ScheduleItem, ScheduleItem)] {
        let items = savedSessions.compactMap(\.scheduleItem)
        var result: [(ScheduleItem, ScheduleItem)] = []

        for i in 0..<items.count {
            for j in (i+1)..<items.count {
                let a = items[i]
                let b = items[j]
                if a.startTime < b.endTime && b.startTime < a.endTime
                    && !a.isCancelled && !b.isCancelled {
                    result.append((a, b))
                }
            }
        }
        return result
    }

    var groupedByDay: [(Date, [UserSavedItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: savedSessions) { item in
            calendar.startOfDay(for: item.scheduleItem?.startTime ?? Date())
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if savedSessions.isEmpty && savedEvents.isEmpty {
                    ContentUnavailableView(
                        "No Saved Events",
                        systemImage: "bookmark",
                        description: Text("Browse events and tap Save Event or bookmark individual sessions.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Conflict warnings
                            if !conflicts.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Schedule Conflicts", systemImage: "exclamationmark.triangle.fill")
                                        .font(.headline)
                                        .foregroundStyle(.orange)

                                    ForEach(Array(conflicts.enumerated()), id: \.offset) { _, pair in
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundStyle(.orange)
                                                .font(.caption)
                                            Text("\"\(pair.0.title)\" overlaps with \"\(pair.1.title)\"")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.orange.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }

                            // Grouped saved items
                            ForEach(groupedByDay, id: \.0) { day, items in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(day, format: .dateTime.weekday(.wide).month(.wide).day())
                                        .font(.headline)
                                        .padding(.horizontal)

                                    ForEach(items) { saved in
                                        if let item = saved.scheduleItem {
                                            if let event = item.event {
                                                NavigationLink(value: event) {
                                                    SavedItemRow(item: item, savedItem: saved) {
                                                        withAnimation {
                                                            NotificationManager.shared.removeReminder(for: item)
                                                            modelContext.delete(saved)
                                                            NotificationManager.shared.syncReminders(context: modelContext)
                                                        }
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            } else {
                                                SavedItemRow(item: item, savedItem: saved) {
                                                    withAnimation {
                                                        NotificationManager.shared.removeReminder(for: item)
                                                        modelContext.delete(saved)
                                                        NotificationManager.shared.syncReminders(context: modelContext)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // Saved events (no specific sessions)
                            if !savedEvents.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(savedEvents) { saved in
                                        if let event = saved.event {
                                            NavigationLink(value: event) {
                                                SavedEventRow(event: event, savedItem: saved) {
                                                    withAnimation {
                                                        modelContext.delete(saved)
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .navigationTitle("My Schedule")
        }
    }
}

struct SavedItemRow: View {
    let item: ScheduleItem
    let savedItem: UserSavedItem
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("\(item.startTime, format: .dateTime.hour().minute()) – \(item.endTime, format: .dateTime.hour().minute())")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.green)

                if let stage = item.stage {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Label(stage.name, systemImage: "music.mic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "bookmark.slash.fill")
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.title) from schedule")
            }

            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .strikethrough(item.isCancelled)

            if let event = item.event {
                Label(event.name, systemImage: "party.popper")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if item.isCancelled {
                Text("CANCELLED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .accessibilityLabel("This session is cancelled")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)\(item.isCancelled ? ", cancelled" : ""), \(item.startTime.formatted(.dateTime.hour().minute())) to \(item.endTime.formatted(.dateTime.hour().minute()))\(item.stage != nil ? " at \(item.stage!.name)" : "")\(item.event != nil ? ", \(item.event!.name)" : "")")
    }
}

struct SavedEventRow: View {
    let event: Event
    let savedItem: UserSavedItem
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Label(event.location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(event.startDate, format: .dateTime.month(.abbreviated).day())
                    Text("–")
                    Text(event.endDate, format: .dateTime.month(.abbreviated).day())
                }
                .font(.caption)
                .foregroundStyle(.green)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "bookmark.slash.fill")
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(event.name) from saved events")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.name) at \(event.location), \(event.startDate.formatted(.dateTime.month(.abbreviated).day())) to \(event.endDate.formatted(.dateTime.month(.abbreviated).day()))")
        .accessibilityHint("Double tap to view event details")
    }
}

#Preview {
    MyScheduleView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
