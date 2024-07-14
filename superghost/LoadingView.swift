//
//  LoadingView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct LoadingView: View {
    let date = Date()
    let namespace: Namespace.ID

    var body: some View {

        VStack {
            GeometryReader{geo in
                TimelineView(.animation){context in
                    let timeInterval = context.date.timeIntervalSince(date)
                    let sineValue = sin(timeInterval * .pi) // Adjust the frequency of the sine wave
                    let cosineValue = cos(timeInterval * .pi / 2)

                    let offsetY = CGFloat(sineValue)*25
                    let offsetX = CGFloat(cosineValue)*15

                    Image(.ghost)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .offset(x: offsetX, y: offsetY)
                        .matchedGeometryEffect(id: "ghost", in: namespace)
                    Circle()
                        .fill()
                        .scaleEffect(y: 0.2)
                        .scaleEffect(max(0,offsetY/40))
                        .blur(radius: 3)
                        .opacity(max(0.2, offsetY/50))
                        .offset(x: offsetX)
                }
                .position(x: geo.size.width/2)
                .offset(y: geo.size.height/2)
            }
        }
        .offset(y: 40)
    }
}


#Preview {
    @Namespace var namespace
    return LoadingView(namespace: namespace)
        .border(.red)
        .frame(width: 400, height: 700)
        .modifier(PreviewModifier())
}

