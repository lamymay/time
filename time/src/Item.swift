//
//  Item.swift
//  time
//
//  Created by may on 2025/12/25.
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
