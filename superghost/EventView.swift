//
//  EventView.swift
//  superghost
//
//  Created by Melanie Nagel   on 9/16/24.
//

import SwiftUI

struct EventView: View {
    @CloudStorage("doubleXPuntil") private var xpBoostUntil = Date.distantPast
    let isSunday = Calendar.current.component(.weekday, from: .now) == 1
    @State private var showEnd = false
        
    var body: some View {
        if showEnd {
            Image(.ghostExploding)
                .resizable()
                .scaledToFit()
                .padding()
                .transition(.scale)
                .task{
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation{
                        showEnd = false
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
        } else if isSunday && xpBoostUntil > .now {
            Section{
                VStack{
                    Text("4x XP Boost!!")
                        .font(.title.bold())
                    Text("It's over in ") + Text(xpBoostUntil, style: .timer).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .task {
                    try? await Task.sleep(for: .seconds((xpBoostUntil.timeIntervalSinceNow-1).magnitude))
                    withAnimation{
                        showEnd = true
                    }
                }
            }
        } else if isSunday || xpBoostUntil > .now {
            Section{
                VStack{
                    Text("It's Double XP!!")
                        .font(.title.bold())
                    if isSunday{
                        Text("All day long. You could win the leaderboard, you know?")
                    } else {
                        Text("It's over in ") + Text(xpBoostUntil, style: .timer).monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .task {
                    if xpBoostUntil > .now {
                        try? await Task.sleep(for: .seconds((xpBoostUntil.timeIntervalSinceNow-1).magnitude))
                        withAnimation{
                            showEnd = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    EventView()
}
