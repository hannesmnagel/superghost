//
//  ButtonBorderShapes.swift
//  superghost
//
//  Created by Hannes Nagel on 11/3/24.
//

import SwiftUI

extension ButtonBorderShape {
    static var bcCircle: Self {
        if #available(iOS 17.0, *){
            .circle
        } else {
            .roundedRectangle
        }
    }
}
