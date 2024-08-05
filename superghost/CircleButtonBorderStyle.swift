//
//  CircleButtonBorderStyle.swift
//  superghost
//
//  Created by Hannes Nagel on 8/5/24.
//

import SwiftUI

extension ButtonBorderShape{
    static var bcCircle: ButtonBorderShape {
        if #available(iOS 17.0, *){
            ButtonBorderShape.circle
        } else {
            ButtonBorderShape.roundedRectangle
        }
    }
}
