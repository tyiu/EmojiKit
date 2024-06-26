//
//  UnicodeEmojiCategory.swift
//  
//
//  Created by Niklas Amslgruber on 10.06.23.
//

import Foundation
import OrderedCollections

public class UnicodeEmojiCategory: Codable {

    public enum Name: String, CaseIterable, Codable {
        case flags = "Flags"
        case activities = "Activities"
        case components = "Component"
        case objects = "Objects"
        case travelAndPlaces = "Travel & Places"
        case symbols = "Symbols"
        case peopleAndBody = "People & Body"
        case animalsAndNature = "Animals & Nature"
        case foodAndDrink = "Food & Drink"
        case smileysAndEmotions = "Smileys & Emotion"

        var appleName: AppleEmojiCategory.Name? {
            switch self {
            case .flags:
                return .flags
            case .activities:
                return .activity
            case .components:
                return nil
            case .objects:
                return .objects
            case .travelAndPlaces:
                return .travelAndPlaces
            case .symbols:
                return .symbols
            case .peopleAndBody:
                return .smileysAndPeople
            case .animalsAndNature:
                return .animalsAndNature
            case .foodAndDrink:
                return .foodAndDrink
            case .smileysAndEmotions:
                return .smileysAndPeople
            }
        }
    }

    public let name: Name
    public let appleCategory: AppleEmojiCategory.Name?
    public var emojis: OrderedDictionary<String, Emoji>

    public init(name: Name, emojis: OrderedDictionary<String, Emoji>) {
        self.name = name
        self.appleCategory = name.appleName
        self.emojis = emojis
    }
}
