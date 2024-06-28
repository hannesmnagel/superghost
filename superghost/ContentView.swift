//
//  ContentView.swift
//  superghost
//
//  Created by Hannes Nagel on 6/15/24.
//

import SwiftUI

struct ContentView: View {

    @State var isGameViewPresented = false

    @StateObject var viewModel = GameViewModel()

    let date = Date()
    @Namespace var namespace

    @State var joinGame = false

    var body: some View {
        Group{
            if isGameViewPresented{

                GameView(viewModel: viewModel, isPresented: $isGameViewPresented, namespace: namespace)
            } else {
                GeometryReader{geo in
                    VStack {
                        List{
                            Section{
                                StatsView()
                            } header: {
                                VStack{
                                    Group{
                                        Text("G") + Text("H") + Text("O") + Text("S") + Text("T")
                                    }
                                    .visualEffect { content, geo in
                                        content
                                            .offset(y: -geo.frame(in: .scrollView).minY + 50)
                                            .opacity(geo.frame(in: .scrollView).minY/20)
                                            .brightness(1)
                                    }
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
                                                    .offset(y: -geo.frame(in: .scrollView).minY*0.5 + geo.size.height/2)
                                                    .scaleEffect(1+geo.frame(in: .scrollView).minY/1000)
                                            }
                                            .matchedGeometryEffect(id: "ghost", in: namespace)
                                            .padding(.vertical, 60)
                                            .padding(.bottom, 60)
                                    }

                                    AsyncButton {
                                        try await viewModel.getTheGame()
                                        isGameViewPresented = true
                                    } label: {
                                        Text("Start")
                                    }
                                    .keyboardShortcut(.defaultAction)

                                    Button("Join a Game") {
                                        joinGame = true
                                    }

                                    AsyncButton {
                                        try await viewModel.hostGame()
                                        isGameViewPresented = true
                                    } label: {
                                        Text("Host a Game")
                                    }
                                }
                                .font(.title)
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                                .frame(height: geo.size.height*0.7, alignment: .bottom)
                                .padding(.bottom, 30)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .onOpenURL { url in
                        Task{
                            guard url.scheme == "superghost" else {
                                return
                            }
                            let gameId = url.lastPathComponent

                            try await viewModel.joinGame(with: gameId)
                            isGameViewPresented = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $joinGame){
            JoinGameView(viewModel: viewModel, isGameViewPresented: $isGameViewPresented)
        }
        .animation(.smooth, value: isGameViewPresented)
        .preferredColorScheme(.dark)
    }
}


struct StatsView: View {
    @AppStorage("gameStats") var games = [GameStat]()
    var body: some View {
        ForEach(games){game in
            HStack{
                Text(game.word)
                Spacer()
                Image(systemName: game.won ? "crown.fill" : "xmark")
                    .onLongPressGesture{games.removeAll()}
            }
            .listRowBackground(game.won ? Color.green.brightness(0.5).opacity(0.1) : Color.red.brightness(0.5).opacity(0.1))
        }
    }
}

#Preview {
    ContentView()
}

struct JoinGameView: View {
    @State private var gameId = ""
    let length = UUID().uuidString.count
    @State var viewModel: GameViewModel
    @Binding var isGameViewPresented: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack{
            Spacer()
            Text("Join an existing Game").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 5){
                Text("What's the Game ID?")
                    .font(.title)
                TextField("Game ID", text: $gameId)
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(30)
            Spacer()
            AsyncButton{
                try await joinGame()
            } label: {
                Text("Join")
            }
            .disabled(gameId.count != length)
            .font(.title)
        }
        .buttonStyle(.borderedProminent)
    }

    private func joinGame() async throws {
        guard gameId.count == length else {return}

        try await viewModel.joinGame(with: gameId)

        isGameViewPresented = true

        dismiss()
    }
}

struct AsyncButton<Label:View>: View {

    let action: () async throws -> Void
    @ViewBuilder let label: Label

    @State private var state = AsyncButtonState.main

    enum AsyncButtonState{
        case main, inProgress, success, failed
    }

    var body: some View {
        Button{
            Task{
                do{
                    state = .inProgress
                    try await action()
                    state = .success
                    try? await Task.sleep(for: .seconds(1))
                    state = .main
                } catch {
                    print(error)
                    state = .failed
                    try? await Task.sleep(for: .seconds(1))
                    state = .main
                }
            }
        } label: {
            switch state {
            case .main:
                label
            case .inProgress:
                ProgressView()
            case .success:
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
            }
        }
        .disabled(state == .inProgress)
    }
}
