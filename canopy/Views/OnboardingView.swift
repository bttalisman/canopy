import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    VStack(spacing: 24) {
                        Spacer()

                        CanopyPinView(size: 100)

                        Text("Canopy")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text(CityConfig.onboardingSubtitle)
                            .font(.title3)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))

                        Text("Festivals, concerts, fairs, expos —\nall in one place.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.5))

                        Spacer()
                        Spacer()
                    }
                    .tag(0)

                    // Page 2: Features
                    VStack(spacing: 20) {
                        Spacer()

                        Text("Everything you need")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 20) {
                            featureRow(
                                icon: "calendar.badge.clock",
                                color: .green,
                                title: "Discover & Schedule",
                                subtitle: "Browse events, save sessions, get reminders"
                            )

                            featureRow(
                                icon: "map.fill",
                                color: .blue,
                                title: "Venue Maps",
                                subtitle: "Interactive maps with stages, food, restrooms"
                            )

                            featureRow(
                                icon: "bus.fill",
                                color: .orange,
                                title: "Transit Directions",
                                subtitle: "Real-time bus arrivals and route planning"
                            )

                            featureRow(
                                icon: "bell.badge.fill",
                                color: .purple,
                                title: "Stay Updated",
                                subtitle: "Push notifications for schedule changes"
                            )
                        }
                        .padding(.horizontal, 32)

                        Spacer()
                        Spacer()
                    }
                    .tag(1)

                    // Page 3: Permissions + Get Started
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)

                        Text("Better with your location")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Canopy uses your location to show\nnearby transit options and venue maps.\nYou can change this anytime in Settings.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        Button {
                            withAnimation {
                                isComplete = true
                            }
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 32)

                        Spacer()
                            .frame(height: 40)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Skip button (pages 0 and 1 only)
                if currentPage < 2 {
                    Button("Skip") {
                        withAnimation {
                            isComplete = true
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
