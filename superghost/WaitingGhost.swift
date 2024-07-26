//
//  WaitingGhost.swift
//  superghost
//
//  Created by Hannes Nagel on 7/13/24.
//

import SwiftUI

struct WaitingGhost: View {
    @Environment(\.launchDate) var date

    var body: some View {
        TimelineView(.animation){context in

            let timeInterval = context.date.timeIntervalSince(date)
            let sineValue = sin(timeInterval * .pi / 2) // Adjust the frequency of the sine wave
            let cosineValue = cos(timeInterval * .pi / 2)

            let offsetX = CGFloat(sineValue)*30
            let rotationAngle = atan2(cosineValue, 1.0) * 20 / .pi

            Image(.ghost)
                .resizable()
                .scaledToFit()
                .visualEffect { content, geo in
                    content
                        .offset(x: offsetX)
                        .rotationEffect(.degrees(rotationAngle))
                        .offset(y: -geo.frame(in: .scrollView).minY*0.8 + geo.size.height/2)
                        .scaleEffect(0.8+geo.frame(in: .scrollView).minY/1000)
                }
                .padding(.vertical, 60)
                .padding(.bottom, 60)
        }
    }
}

#Preview {
    WaitingGhost()
        .modifier(PreviewModifier())
}
