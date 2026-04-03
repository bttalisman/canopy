import SwiftUI

struct CanopyPinView: View {
    var size: CGFloat = 50

    // SVG viewBox is 1024x1024, pin content roughly spans x:360-664, y:120-780
    // We'll scale from SVG coordinates to the requested size

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 320.0
            // Offset so the pin is centered: SVG pin center is ~512, width ~304
            // We map SVG x range [352, 668] → [0, 316] and y range [120, 780] → [0, 660]
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: (x - 352) * scale, y: (y - 120) * scale)
            }

            // Pin gradient: #4ade80 → #16a34a
            let pinGradient = Gradient(colors: [
                Color(red: 0.29, green: 0.87, blue: 0.50),  // #4ade80
                Color(red: 0.086, green: 0.64, blue: 0.29)  // #16a34a
            ])

            // Pin body: M512 780 L400 500 Q360 400 400 310 Q440 220 512 200 Q584 220 624 310 Q664 400 624 500 Z
            var pinPath = Path()
            pinPath.move(to: pt(512, 780))
            pinPath.addLine(to: pt(400, 500))
            pinPath.addQuadCurve(to: pt(400, 310), control: pt(360, 400))
            pinPath.addQuadCurve(to: pt(512, 200), control: pt(440, 220))
            pinPath.addQuadCurve(to: pt(624, 310), control: pt(584, 220))
            pinPath.addQuadCurve(to: pt(624, 500), control: pt(664, 400))
            pinPath.closeSubpath()

            context.opacity = 0.9
            context.fill(
                pinPath,
                with: .linearGradient(
                    pinGradient,
                    startPoint: pt(512, 120),
                    endPoint: pt(512, 780)
                )
            )
            context.opacity = 1.0

            context.opacity = 1.0

            // Main leaf (right): M512 200 Q560 120 620 140 Q660 160 640 220 Q620 260 560 240 Q530 230 512 200 Z
            let leafGradient = Gradient(colors: [
                Color(red: 0.525, green: 0.937, blue: 0.675), // #86efac
                Color(red: 0.133, green: 0.773, blue: 0.369)  // #22c55e
            ])

            var leafPath = Path()
            leafPath.move(to: pt(512, 200))
            leafPath.addQuadCurve(to: pt(620, 140), control: pt(560, 120))
            leafPath.addQuadCurve(to: pt(640, 220), control: pt(660, 160))
            leafPath.addQuadCurve(to: pt(560, 240), control: pt(620, 260))
            leafPath.addQuadCurve(to: pt(512, 200), control: pt(530, 230))
            leafPath.closeSubpath()

            context.opacity = 0.9
            context.fill(
                leafPath,
                with: .linearGradient(
                    leafGradient,
                    startPoint: pt(512, 180),
                    endPoint: pt(660, 180)
                )
            )

            // Leaf vein: M512 200 Q530 160 520 140
            var veinPath = Path()
            veinPath.move(to: pt(512, 200))
            veinPath.addQuadCurve(to: pt(520, 140), control: pt(530, 160))
            context.opacity = 0.6
            context.stroke(veinPath, with: .color(Color(red: 0.086, green: 0.64, blue: 0.29)), lineWidth: 2.5 * scale)

            context.opacity = 1.0

            // Second smaller leaf (left): M512 200 Q460 130 420 160 Q400 180 420 220 Q440 250 480 230 Q500 220 512 200 Z
            var leaf2Path = Path()
            leaf2Path.move(to: pt(512, 200))
            leaf2Path.addQuadCurve(to: pt(420, 160), control: pt(460, 130))
            leaf2Path.addQuadCurve(to: pt(420, 220), control: pt(400, 180))
            leaf2Path.addQuadCurve(to: pt(480, 230), control: pt(440, 250))
            leaf2Path.addQuadCurve(to: pt(512, 200), control: pt(500, 220))
            leaf2Path.closeSubpath()

            context.opacity = 0.7
            context.fill(leaf2Path, with: .color(Color(red: 0.29, green: 0.87, blue: 0.50)))
        }
        .frame(width: size * 0.485, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 30) {
        CanopyPinView(size: 120)
        CanopyPinView(size: 60)
        CanopyPinView(size: 40)
    }
    .padding()
    .background(Color(.systemBackground))
}
