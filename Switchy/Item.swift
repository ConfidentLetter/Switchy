//
//  Item.swift
//  Switchy
//
//  Created by Cayden M. Ching on 8/14/25.
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
