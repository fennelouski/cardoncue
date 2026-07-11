//
//  AnimatedGradientBackground.swift
//  CardOnCue
//
//  Subtle, always-moving background: a few large blurred color blobs that drift
//  slowly behind the card list. Driven by TimelineView so it pauses when the
//  view is off-screen. Deployment target is iOS 17, so no MeshGradient.
//

import SwiftUI

struct AnimatedGradientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let blobColors: [Color] = [.appBlue, .appGreen, .appBeige, .appPrimary]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.appBackground
                if reduceMotion {
                    blobs(in: geo.size, t: 0) // frozen: honors Reduce Motion
                } else {
                    TimelineView(.animation) { timeline in
                        blobs(in: geo.size, t: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .ignoresSafeArea()
        // ponytail: a few blurred ellipses in a TimelineView is cheap; if it
        // ever shows up on battery, drop to one slow AngularGradient rotation.
    }

    private func blobs(in size: CGSize, t: Double) -> some View {
        ZStack {
            ForEach(blobColors.indices, id: \.self) { i in
                let phase = t / 19.0 + Double(i) * 1.7 // slow drift, staggered
                let x = (sin(phase) * 0.5 + 0.5) * size.width
                let y = (cos(phase * 0.8) * 0.5 + 0.5) * size.height
                Ellipse()
                    .fill(blobColors[i])
                    .frame(width: size.width * 0.85, height: size.height * 0.5)
                    .position(x: x, y: y)
            }
        }
        .blur(radius: 70)
        .opacity(0.35)
    }
}
