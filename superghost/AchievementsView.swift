//
//  AchievementsView.swift
//  superghost
//
//  Created by Hannes Nagel on 9/5/24.
//

import SwiftUI
import GameKit


struct AchievementsView: View {
    @State private var isExpanded = false
    @ObservedObject var gkStore = GKStore.shared

    var body: some View {
        VStack{
            Text("Achievements")
                .font(AppearanceManager.leaderboardTitle)
            ScrollView(.horizontal){
                LazyHGrid(rows: [ GridItem(.fixed(200))]) {
                    if let achievedAchievements = gkStore.achievedAchievements {
                        ForEach(achievedAchievements, id: \.0.identifier) { achievement in
                            Button{
                                GKAccessPoint.shared.trigger(achievementID: achievement.0.identifier){}
                            } label: {
                                AchievementView(achievement: achievement)
                                    .frame(width: 200)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
                        }
                    }
                    if let unachievedAchievements = gkStore.unachievedAchievements {
                        ForEach(unachievedAchievements, id: \.0.identifier) { achievement in
                            Button{
                                GKAccessPoint.shared.trigger(achievementID: achievement.0.identifier){}
                            } label: {
                                AchievementView(achievement: achievement)
                                    .frame(width: 200)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .plain))
                        }
                    }
                }
                .id([gkStore.unachievedAchievements?.debugDescription, gkStore.achievedAchievements?.debugDescription])

            }
            Button{
                GKAccessPoint.shared.trigger(state: .achievements){}
            } label: {
                HStack{
                    Text("More")
                    Image(systemName: "ellipsis")
                }
                .contentShape(.rect)
            }
            .buttonStyle(AppearanceManager.HapticStlye(buttonStyle: .bordered))
            .buttonBorderShape(.capsule)
            .padding()
        }
        .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
        .onDisappear{isExpanded = false}
    }
}

#Preview {
    AchievementsView()
}

extension GKAchievementDescription {
    @MainActor @ViewBuilder
    func asyncImage(achieved: Bool) -> some View {
        if achieved{
            AsyncProfileImageView {
                try await withCheckedThrowingContinuation { con in
                    self.loadImage { image, error in
                        if let image {
                            con.resume(returning: Image(uiImage: image))
                        } else {
                            con.resume(throwing: error ?? NSError(domain: "Ouch", code: 0))
                        }
                    }
                }
            } loading: {
                Image(uiImage: Self.placeholderCompletedAchievementImage())
            }
        } else {
            Image(uiImage: Self.incompleteAchievementImage())
        }
    }
    struct AsyncProfileImageView<Loading: View>: View {
        let closure: () async throws -> Image
        @State var image: Image?
        @ViewBuilder let loading: Loading

        var body: some View {
            if let image {
                image
                    .resizable().scaledToFit().clipShape(.circle)
            } else {
                loading
            }
        }
    }
}

struct AchievementView: View {
    let achievement: (GKAchievementDescription,GKAchievement?)

    var body: some View {
        let isCompleted = achievement.1?.isCompleted ?? false
        VStack {
            achievement.0.asyncImage(achieved: isCompleted)
                .frame(width: 100, height: 100)
                .padding(2)
                .background(.gray.gradient)
                .clipShape(.circle)

            Text(achievement.0.title)
                .lineLimit(2)
                .font(.headline)
            Text(isCompleted ? achievement.0.achievedDescription : achievement.0.unachievedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke())
    }
}
