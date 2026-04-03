import SwiftUI

struct PerformerProfileView: View {
    let item: ScheduleItem

    private var links: [(label: String, url: String)] {
        guard let json = item.performerLinks,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }
        return array.compactMap { dict in
            guard let label = dict["label"], let url = dict["url"] else { return nil }
            return (label: label, url: url)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performer image
                if let imageURL = item.performerImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .clipped()
                        case .failure:
                            performerInitials
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 250)
                                .overlay(ProgressView())
                        @unknown default:
                            performerInitials
                        }
                    }
                } else {
                    performerInitials
                }

                VStack(spacing: 16) {
                    // Name
                    Text(item.performerName ?? item.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Session info
                    HStack(spacing: 16) {
                        Label(item.startTime.formatted(.dateTime.hour().minute()), systemImage: "clock")
                        if let stage = item.stage {
                            Label(stage.name, systemImage: "music.mic")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)

                    // Bio
                    if let bio = item.performerBio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Social links
                    if !links.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(links, id: \.url) { link in
                                if let url = URL(string: link.url) {
                                    Link(destination: url) {
                                        Label(link.label, systemImage: iconForLink(link.label))
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemGray6))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .accessibilityLabel("\(link.label) for \(item.performerName ?? item.title)")
                                    .accessibilityHint("Opens in browser")
                                }
                            }
                        }
                    }

                    // Description from the schedule item
                    if !item.itemDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About this set")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(item.itemDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(item.performerName ?? item.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var performerInitials: some View {
        let name = item.performerName ?? item.title
        let initials = name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined()
        return ZStack {
            LinearGradient(
                colors: [.green.opacity(0.3), .green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.green.opacity(0.6))
        }
        .frame(height: 180)
        .accessibilityHidden(true)
    }

    private func iconForLink(_ label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("instagram") { return "camera" }
        if lower.contains("twitter") || lower.contains("x.com") { return "at" }
        if lower.contains("spotify") { return "music.note" }
        if lower.contains("youtube") { return "play.rectangle" }
        if lower.contains("tiktok") { return "video" }
        if lower.contains("facebook") { return "person.2" }
        if lower.contains("soundcloud") { return "waveform" }
        if lower.contains("bandcamp") { return "music.note.list" }
        return "link"
    }
}
