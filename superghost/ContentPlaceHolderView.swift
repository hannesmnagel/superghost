//
//  ContentPlaceHolderView.swift
//  superghost
//
//  Created by Hannes Nagel on 11/3/24.
//

import SwiftUI

struct ContentPlaceHolderView: View {
    let title: String
    let systemImage: String
    let description: String

    init(_ title: String, systemImage: String, description: String = "") {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        if #available(iOS 17.0, *){
            ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
        } else {
            VStack{
                Image(systemName: systemImage)
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 7)
                Text(title)
                    .font(.title2.bold())
                Text(description)
                    .frame(width: 360)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

        }
    }
}
