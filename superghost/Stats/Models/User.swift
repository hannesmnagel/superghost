//
//  User.swift
//  superghost
//
//  Created by Hannes Nagel on 7/10/24.
//

import Foundation

struct User: Codable {
    var id = UUID().uuidString

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}
