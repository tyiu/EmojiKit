//
//  Emoji.swift
//
//
//  Created by Terry Yiu on 6/2/24.
//

import Foundation

public struct Emoji: Codable, Hashable {
    public let value: String
    public let keywords: [String]

    public init(value: String, keywords: [String]) {
        self.value = value
        self.keywords = keywords
    }
}
