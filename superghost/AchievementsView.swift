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

    var body: some View {
        AsyncView {
            if let achievements = try? await GKAchievement.loadAchievements(),
               let achievementDescriptions = try? await GKAchievementDescription.loadAchievementDescriptions(){
                let achieved = achievementDescriptions.compactMap{achievementDescription in
                    if let achievement = achievements.first(where: {$0.identifier == achievementDescription.identifier}),
                    achievement.isCompleted{
                        (achievementDescription, achievement)
                    } else { nil }
                }
                let unachieved = achievementDescriptions.compactMap{achievementDescription in
                    let achievement = achievements.first(where: {$0.identifier == achievementDescription.identifier})
                    if achievement?.isCompleted == true {
                        return nil as (GKAchievementDescription, GKAchievement?)?
                    } else {
                        return (achievementDescription, achievement)
                    }
                }

                VStack{
                    Text("Achievements")
                        .font(AppearanceManager.leaderboardTitle)
                    ScrollView(.horizontal){
                        LazyHGrid(rows: [ GridItem(.fixed(200))]) {
                            ForEach(achieved, id: \.0.identifier) { achievement in
                                Button{
                                    GKAccessPoint.shared.trigger(achievementID: achievement.0.identifier)
                                } label: {
                                    AchievementView(achievement: achievement)
                                        .frame(width: 200)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(unachieved, id: \.0.identifier) { achievement in
                                Button{
                                    GKAccessPoint.shared.trigger(achievementID: achievement.0.identifier)
                                } label: {
                                    AchievementView(achievement: achievement)
                                        .frame(width: 200)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }

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
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.bcCapsule)
                    .padding()
                }
                .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
                .onDisappear{isExpanded = false}
            }
        } loading: {
            ContentPlaceHolderView("Loading Achievements...", systemImage: "crown")
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    AchievementsView()
}

extension GKAchievementDescription {
    @MainActor @ViewBuilder
    func asyncImage(achieved: Bool) -> some View {
        if achieved{
            AsyncView {
                await Task.detached{
                    try? await Image(uiImage: self.loadImage())
                        .resizable().scaledToFit().clipShape(.circle)
                }.value
            } loading: {
                Image(uiImage: Self.placeholderCompletedAchievementImage())
            }
        } else {
            Image(uiImage: Self.incompleteAchievementImage())
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
