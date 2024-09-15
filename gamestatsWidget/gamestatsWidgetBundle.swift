//
//  gamestatsWidgetBundle.swift
//  gamestatsWidget
//
//  Created by Hannes Nagel on 7/16/24.
//

import WidgetKit
import SwiftUI

@main
struct gamestatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        gamestatsWidget()
    }
}

import GameKit

extension GKAccessPoint{
    func trigger(achievementID: String){
        //Do nothing
    }
}
