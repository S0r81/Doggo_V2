//
//  Item.swift
//  Doggo_V2
//
//  Created by Sorest on 2/4/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
