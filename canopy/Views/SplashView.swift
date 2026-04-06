import SwiftUI

struct LetterState {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var rotation: Double = 0
    var opacity: Double = 1
}

struct SplashView: View {
    @State private var dropOffset: CGFloat = -500
    @State private var dropSpin: Double = 0
    @State private var squish: CGFloat = 1.0
    @State private var bounceScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var logoOpacity: Double = 1.0
    @State private var textOffset: CGFloat = 500
    @State private var textOpacity: Double = 0
    @State private var skylineOpacity: Double = 0
    @State private var skylineOffset: CGFloat = 30
    @State private var pinExplode = LetterState()
    @State private var letterStates: [LetterState] = []
    @State private var taglineStates: [LetterState] = []
    @State private var exploding = false

    private let titleText = Array("Canopy")
    private let taglineText = Array("One app for every event")

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18)
                .ignoresSafeArea()

            GeometryReader { geo in
                let centerY = geo.size.height / 2
                let pinX = geo.size.width / 3 - 20
                let textX = pinX + (geo.size.width - pinX) / 2

                ZStack {
                    // Space Needle silhouette
                    Image("SpaceNeedleSilhouette")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geo.size.height * 1.5)
                        .opacity(0.07)
                        .position(x: geo.size.width * 0.65, y: geo.size.height * 0.3)
                        .opacity(skylineOpacity)
                        .offset(y: skylineOffset)

                    // Pin
                    Image("CanopyPin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 160)
                        .scaleEffect(x: 1.0, y: squish)
                        .scaleEffect(bounceScale)
                        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                        .offset(x: pinExplode.offsetX, y: pinExplode.offsetY)
                        .rotationEffect(.degrees(pinExplode.rotation))
                        .opacity(pinExplode.opacity)
                        .position(x: pinX, y: centerY)
                        .offset(y: dropOffset)

                    // Text — either normal or exploding letters
                    if !exploding {
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
                                .foregroundStyle(.orange)
                        }
                        .opacity(textOpacity)
                        .position(x: textX, y: centerY)
                        .offset(x: textOffset)
                    } else {
                        // Exploding title letters
                        HStack(spacing: 0) {
                            ForEach(Array(titleText.enumerated()), id: \.offset) { i, char in
                                let state = i < letterStates.count ? letterStates[i] : LetterState()
                                Text(String(char))
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green, .mint, .green],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: state.offsetX, y: state.offsetY)
                                    .rotationEffect(.degrees(state.rotation))
                                    .opacity(state.opacity)
                            }
                        }
                        .position(x: textX, y: centerY)

                        // Exploding tagline letters
                        HStack(spacing: 0) {
                            ForEach(Array(taglineText.enumerated()), id: \.offset) { i, char in
                                let state = i < taglineStates.count ? taglineStates[i] : LetterState()
                                Text(String(char))
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                    .offset(x: state.offsetX, y: state.offsetY)
                                    .rotationEffect(.degrees(state.rotation))
                                    .opacity(state.opacity)
                            }
                        }
                        .position(x: textX, y: centerY + 30)
                    }
                }
            }
        }
        .opacity(logoOpacity)
        .onAppear {
            // Initialize letter states
            letterStates = titleText.map { _ in LetterState() }
            taglineStates = taglineText.map { _ in LetterState() }
            animate()
        }
    }

    private func animate() {
        // Phase 1: Drop down
        withAnimation(.easeIn(duration: 0.4)) {
            dropOffset = 0
        }

        // Continuous spin: starts fast during fall, decelerates to stop after landing
        withAnimation(.easeOut(duration: 1.2)) {
            rotation = 2160
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

        // Phase 3b: Space Needle fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 2.0)) {
                skylineOpacity = 1.0
                skylineOffset = 0
            }
        }

        // Phase 4: Text slides in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            textOpacity = 1.0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                textOffset = 0
            }
        }

        // Phase 5: Letters explode outward
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            exploding = true

            // Explode each title letter with random direction
            for i in 0..<letterStates.count {
                let delay = Double.random(in: 0...0.15)
                let dirX = CGFloat.random(in: -500...500)
                let dirY = CGFloat.random(in: -800...400)
                let spin = Double.random(in: -720...720)

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeIn(duration: 0.6)) {
                        letterStates[i].offsetX = dirX
                        letterStates[i].offsetY = dirY
                        letterStates[i].rotation = spin
                        letterStates[i].opacity = 0
                    }
                }
            }

            // Explode each tagline letter
            for i in 0..<taglineStates.count {
                let delay = Double.random(in: 0.05...0.25)
                let dirX = CGFloat.random(in: -400...400)
                let dirY = CGFloat.random(in: -600...500)
                let spin = Double.random(in: -540...540)

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeIn(duration: 0.5)) {
                        taglineStates[i].offsetX = dirX
                        taglineStates[i].offsetY = dirY
                        taglineStates[i].rotation = spin
                        taglineStates[i].opacity = 0
                    }
                }
            }

            // Explode the pin too
            let pinDirX = CGFloat.random(in: -300...300)
            let pinDirY = CGFloat.random(in: -600 ... -200)
            let pinSpin = Double.random(in: -540...540)
            withAnimation(.easeIn(duration: 0.6)) {
                pinExplode.offsetX = pinDirX
                pinExplode.offsetY = pinDirY
                pinExplode.rotation = pinSpin
                pinExplode.opacity = 0
            }

            // Also fade skyline
            withAnimation(.easeOut(duration: 0.4)) {
                skylineOpacity = 0
            }
        }

        // Phase 6: Final fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                logoOpacity = 0
            }
        }
    }
}
