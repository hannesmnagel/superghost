//
//  Messages.swift
//  superghost
//
//  Created by Hannes Nagel on 8/4/24.
//

import SwiftUI

struct Messagable: ViewModifier {
    @ObservedObject var model = MessageModel.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack{
                    if let message = model.message.first {
                        Color.black
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea()
                            .transition(.opacity)
                        HStack{
                            Text(message)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .clipShape(.capsule)

                            Image(.ghostHeadingLeft)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300)
                                .padding(50)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                        .task(id: message){
                            try? await Task.sleep(for: .seconds(message.count/10))
                                model.message = Array(model.message.dropFirst())
                            }
                    }
                }
                .animation(.smooth, value: model.message)
            }
    }
}

final class MessageModel: ObservableObject {
    private init(){}
    static let shared = MessageModel()

    @Published var message = [String]()
}

func showMessage(_ message: String) {
    MessageModel.shared.message.append(message)
}
