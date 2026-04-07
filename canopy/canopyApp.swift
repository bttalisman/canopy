import SwiftUI
import SwiftData
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.registerToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
}

@main
struct canopyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @State private var showSplash = true

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingView(isComplete: $hasCompletedOnboarding)
            } else if showSplash {
                SplashView()
                    .onAppear {
                        // Defer the splash dismissal; do NOT kick off any
                        // heavy work (permissions, network, SwiftData queries)
                        // until after the animation finishes so the main
                        // thread stays clear for the splash render loop.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                MainTabView()
                    .transition(.opacity)
                    .onAppear {
                        // Now that the splash is gone, do post-launch work.
                        NotificationManager.shared.requestPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationManager.shared.syncReminders(context: modelContext)
                        }
                    }
            }
        }
        .preferredColorScheme(colorScheme)
    }
}
