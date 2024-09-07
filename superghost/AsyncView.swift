//
//  AsyncView.swift
//  superghost
//
//  Created by Hannes Nagel on 9/5/24.
//

import SwiftUI

struct AsyncView<Content: View, Loading: View>: View {
    @State var content: Content?
    @ViewBuilder let loading: Loading
    let contentClosure: () async -> Content
    init(@ViewBuilder content: @escaping () async -> Content, loading: () -> Loading) {
        self.content = nil
        self.loading = loading()
        contentClosure = content
    }

    var body: some View {
        if let content{
            content
        } else {
            loading
                .task {
                    content = await contentClosure()
                }
        }
    }
}
