import SwiftUI

struct SplashView: View {
    @State private var dropOffset: CGFloat = -500
    @State private var squish: CGFloat = 1.0
    @State private var bounceScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var logoOpacity: Double = 1.0
    @State private var textOffset: CGFloat = 500
    @State private var textOpacity: Double = 0
    @State private var skylineOpacity: Double = 0
    @State private var skylineOffset: CGFloat = 30

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18)
                .ignoresSafeArea()

            GeometryReader { geo in
                let centerY = geo.size.height / 2
                let pinX = geo.size.width / 3 - 20
                let textX = pinX + (geo.size.width - pinX) / 2

                ZStack {
                    // Space Needle silhouette — fades in on the right
                    Image("SpaceNeedleSilhouette")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geo.size.height * 1.5)
                        .opacity(0.07)
                        .position(x: geo.size.width * 0.65, y: geo.size.height * 0.3)
                        .opacity(skylineOpacity)
                        .offset(y: skylineOffset)

                    // Pin drops at 1/3 across
                    Image("CanopyPin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 160)
                        .scaleEffect(x: 1.0, y: squish)
                        .scaleEffect(bounceScale)
                        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                        .position(x: pinX, y: centerY)
                        .offset(y: dropOffset)

                    // Text slides in from right, same Y as icon
                    VStack(spacing: 6) {
                        Text("Canopy")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("One app for every event")
                            .font(.subheadline)
                            .foregroundStyle(.mint.opacity(0.7))
                    }
                    .opacity(textOpacity)
                    .position(x: textX, y: centerY)
                    .offset(x: textOffset)
                }
            }
        }
        .opacity(logoOpacity)
        .onAppear {
            animate()
        }
    }

    private func animate() {
        // Phase 1: Drop down
        withAnimation(.easeIn(duration: 0.4)) {
            dropOffset = 0
        }

        // Phase 2: Squish on impact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.3)) {
                squish = 0.75
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    squish = 1.0
                    bounceScale = 1.08
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        bounceScale = 1.0
                    }
                }
            }
        }

        // Phase 3: Fast spin that decelerates to a stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeOut(duration: 1.2)) {
                rotation = 1800
            }
        }

        // Phase 3b: Space Needle fades in and drifts up slightly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 2.0)) {
                skylineOpacity = 1.0
                skylineOffset = 0
            }
        }

        // Phase 4: Text slides in from right and screeches to a stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            textOpacity = 1.0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                textOffset = 0
            }
        }

        // Phase 5: Fade out — give time to read
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                logoOpacity = 0
            }
        }
    }
}

