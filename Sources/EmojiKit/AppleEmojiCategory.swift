//
//  AppleEmojiCategory.swift
//  
//
//  Created by Niklas Amslgruber on 19.02.24.
//

import Foundation
import OrderedCollections

public class AppleEmojiCategory: Codable, Hashable {
    public static func == (lhs: AppleEmojiCategory, rhs: AppleEmojiCategory) -> Bool {
        lhs.name == rhs.name && lhs.emojis == rhs.emojis
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(emojis)
        hasher.combine(variations)
    }


    public enum Name: String, CaseIterable, Codable {
        case frequentlyUsed = "frequentlyUsed"
        case smileysAndPeople = "smileysAndPeople"
        case animalsAndNature = "animalsAndNature"
        case foodAndDrink = "foodAndDrink"
        case activity = "activity"
        case travelAndPlaces = "travelAndPlaces"
        case objects = "objects"
        case symbols = "symbols"
        case flags = "flags"

        public static var orderedCases: [Name] {
            return allCases.sorted(by: { $0.order < $1.order })
        }

        public var order: Int {
            switch self {
            case .frequentlyUsed:
                return 0
            case .smileysAndPeople:
                return 1
            case .animalsAndNature:
                return 2
            case .foodAndDrink:
                return 3
            case .activity:
                return 4
            case .travelAndPlaces:
                return 5
            case .objects:
                return 6
            case .symbols:
                return 7
            case .flags:
                return 8
            }
        }

        public var localizedName: String {
            NSLocalizedString(
                self.rawValue,
                tableName: "EmojiKitLocalizable",
                bundle: .module,
                comment: ""
            )
        }
    }

    public let name: Name
    public var emojis: OrderedDictionary<String, Emoji>
    public var variations: [String: [Emoji]]

    public init(name: Name, emojis: OrderedDictionary<String, Emoji>, variations: [String: [Emoji]]) {
        self.name = name
        self.emojis = emojis
        self.variations = variations
    }

}
