//
//  Image.swift
//  superghost
//
//  Created by Hannes Nagel on 1/12/25.
//

import SwiftUI


#if os(macOS)
extension Image {
    public init(uiImage: NSImage){
        self.init(nsImage: uiImage)
    }
}
#endif
