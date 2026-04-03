import SwiftUI

struct SpaceNeedleView: View {
    var height: CGFloat = 300
    var color: Color = .white

    var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / 240.0
            let scaleY = canvasSize.height / 600.0

            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: x * scaleX, y: y * scaleY)
            }

            // Antenna — thin spire with small crossbar
            var antenna = Path()
            antenna.move(to: pt(119, 0))
            antenna.addLine(to: pt(121, 0))
            antenna.addLine(to: pt(121, 60))
            antenna.addLine(to: pt(119, 60))
            antenna.closeSubpath()
            context.fill(antenna, with: .color(color))

            // Antenna crossbar
            var crossbar = Path()
            crossbar.move(to: pt(114, 30))
            crossbar.addLine(to: pt(126, 30))
            crossbar.addLine(to: pt(126, 32))
            crossbar.addLine(to: pt(114, 32))
            crossbar.closeSubpath()
            context.fill(crossbar, with: .color(color))

            // Top cap — small dome above the observation deck
            var topCap = Path()
            topCap.move(to: pt(100, 68))
            topCap.addQuadCurve(to: pt(140, 68), control: pt(120, 56))
            topCap.addLine(to: pt(142, 74))
            topCap.addLine(to: pt(98, 74))
            topCap.closeSubpath()
            context.fill(topCap, with: .color(color))

            // Upper observation windows — glass band
            var upperGlass = Path()
            upperGlass.move(to: pt(95, 74))
            upperGlass.addLine(to: pt(145, 74))
            upperGlass.addLine(to: pt(147, 84))
            upperGlass.addLine(to: pt(93, 84))
            upperGlass.closeSubpath()
            context.fill(upperGlass, with: .color(color))

            // Main saucer / observation deck — wide flying saucer shape
            var saucer = Path()
            saucer.move(to: pt(93, 84))
            saucer.addLine(to: pt(147, 84))
            // Flare out to full width
            saucer.addQuadCurve(to: pt(195, 95), control: pt(170, 86))
            saucer.addLine(to: pt(200, 100))
            // Underside curves back in with angled fins
            saucer.addLine(to: pt(195, 104))
            saucer.addQuadCurve(to: pt(150, 115), control: pt(175, 108))
            saucer.addLine(to: pt(90, 115))
            saucer.addQuadCurve(to: pt(45, 104), control: pt(65, 108))
            saucer.addLine(to: pt(40, 100))
            saucer.addLine(to: pt(45, 95))
            saucer.addQuadCurve(to: pt(93, 84), control: pt(70, 86))
            saucer.closeSubpath()
            context.fill(saucer, with: .color(color))

            // Underside detail — angled support ring
            var underRing = Path()
            underRing.move(to: pt(85, 115))
            underRing.addLine(to: pt(155, 115))
            underRing.addLine(to: pt(150, 122))
            underRing.addLine(to: pt(90, 122))
            underRing.closeSubpath()
            context.fill(underRing, with: .color(color))

            // Core shaft — upper section tapering down
            var upperShaft = Path()
            upperShaft.move(to: pt(108, 122))
            upperShaft.addLine(to: pt(132, 122))
            upperShaft.addLine(to: pt(128, 250))
            upperShaft.addLine(to: pt(112, 250))
            upperShaft.closeSubpath()
            context.fill(upperShaft, with: .color(color))

            // Lattice crossbars on the shaft
            let shaftCrossbars: [Double] = [145, 170, 195, 220]
            for y in shaftCrossbars {
                let leftX = 108.0 + (112.0 - 108.0) * ((y - 122.0) / (250.0 - 122.0))
                let rightX = 132.0 - (132.0 - 128.0) * ((y - 122.0) / (250.0 - 122.0))
                var bar = Path()
                bar.move(to: pt(leftX - 4, y))
                bar.addLine(to: pt(rightX + 4, y))
                bar.addLine(to: pt(rightX + 4, y + 2))
                bar.addLine(to: pt(leftX - 4, y + 2))
                bar.closeSubpath()
                context.fill(bar, with: .color(color))
            }

            // Lower shaft — continues tapering
            var lowerShaft = Path()
            lowerShaft.move(to: pt(112, 250))
            lowerShaft.addLine(to: pt(128, 250))
            lowerShaft.addLine(to: pt(125, 460))
            lowerShaft.addLine(to: pt(115, 460))
            lowerShaft.closeSubpath()
            context.fill(lowerShaft, with: .color(color))

            // More lattice crossbars on lower shaft
            let lowerCrossbars: [Double] = [280, 310, 340, 370, 400, 430]
            for y in lowerCrossbars {
                let leftX = 112.0 + (115.0 - 112.0) * ((y - 250.0) / (460.0 - 250.0))
                let rightX = 128.0 - (128.0 - 125.0) * ((y - 250.0) / (460.0 - 250.0))
                var bar = Path()
                bar.move(to: pt(leftX - 3, y))
                bar.addLine(to: pt(rightX + 3, y))
                bar.addLine(to: pt(rightX + 3, y + 2))
                bar.addLine(to: pt(leftX - 3, y + 2))
                bar.closeSubpath()
                context.fill(bar, with: .color(color))
            }

            // Three legs splaying out from the base
            // Left leg
            var leftLeg = Path()
            leftLeg.move(to: pt(115, 440))
            leftLeg.addLine(to: pt(118, 440))
            leftLeg.addQuadCurve(to: pt(35, 590), control: pt(75, 540))
            leftLeg.addLine(to: pt(25, 595))
            leftLeg.addLine(to: pt(22, 590))
            leftLeg.addQuadCurve(to: pt(115, 440), control: pt(65, 535))
            leftLeg.closeSubpath()
            context.fill(leftLeg, with: .color(color))

            // Right leg
            var rightLeg = Path()
            rightLeg.move(to: pt(122, 440))
            rightLeg.addLine(to: pt(125, 440))
            rightLeg.addQuadCurve(to: pt(218, 590), control: pt(175, 535))
            rightLeg.addLine(to: pt(215, 595))
            rightLeg.addLine(to: pt(205, 590))
            rightLeg.addQuadCurve(to: pt(122, 440), control: pt(165, 540))
            rightLeg.closeSubpath()
            context.fill(rightLeg, with: .color(color))

            // Center leg
            var centerLeg = Path()
            centerLeg.move(to: pt(117, 460))
            centerLeg.addLine(to: pt(123, 460))
            centerLeg.addLine(to: pt(122, 595))
            centerLeg.addLine(to: pt(118, 595))
            centerLeg.closeSubpath()
            context.fill(centerLeg, with: .color(color))

            // Ground line
            var ground = Path()
            ground.move(to: pt(15, 594))
            ground.addLine(to: pt(225, 594))
            ground.addLine(to: pt(225, 597))
            ground.addLine(to: pt(15, 597))
            ground.closeSubpath()
            context.fill(ground, with: .color(color))
        }
        .frame(width: height * 0.4, height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color(red: 0.1, green: 0.1, blue: 0.18)
            .ignoresSafeArea()
        SpaceNeedleView(height: 500, color: .white.opacity(0.3))
    }
}
