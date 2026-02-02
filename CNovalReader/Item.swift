//
//  Item.swift
//  CNovalReader
//
//  Created by 陈凯瑞 on 2026/2/2.
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
