import SwiftUI
import SwiftData

struct MyScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSavedItem.savedAt) private var savedItems: [UserSavedItem]

    var sortedByTime: [UserSavedItem] {
        savedItems
            .filter { $0.scheduleItem != nil }
            .sorted { ($0.scheduleItem?.startTime ?? .distantPast) < ($1.scheduleItem?.startTime ?? .distantPast) }
    }

    var conflicts: [(ScheduleItem, ScheduleItem)] {
        let items = sortedByTime.compactMap(\.scheduleItem)
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
        let grouped = Dictionary(grouping: sortedByTime) { item in
            calendar.startOfDay(for: item.scheduleItem?.startTime ?? Date())
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if savedItems.isEmpty {
                    ContentUnavailableView(
                        "No Saved Sessions",
                        systemImage: "bookmark",
                        description: Text("Browse events and tap the bookmark icon to save sessions to your schedule.")
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
                                            SavedItemRow(item: item, savedItem: saved) {
                                                withAnimation {
                                                    NotificationManager.shared.removeReminder(for: item)
                                                    modelContext.delete(saved)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
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
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

#Preview {
    MyScheduleView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
