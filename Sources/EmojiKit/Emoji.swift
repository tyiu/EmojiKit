//
//  Emoji.swift
//
//
//  Created by Terry Yiu on 6/2/24.
//

import Foundation

public struct Emoji: Codable, Hashable {
    public let value: String
    public let localizedKeywords: [String: [String]]

    public init(value: String, localizedKeywords: [String: [String]]) {
        self.value = value
        self.localizedKeywords = localizedKeywords
    }
}
