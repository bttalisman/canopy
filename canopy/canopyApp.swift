import SwiftUI
import SwiftData

@main
struct canopyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self,
            Stage.self,
            ScheduleItem.self,
            MapPin.self,
            UserSavedItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If the store is incompatible (e.g. schema changed), delete and recreate
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            // Also remove journal/wal files
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .onAppear {
                        NotificationManager.shared.requestPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            }
        }
    }
}
