//
//  EmojiManager.swift
//  Travely
//
//  Created by Niklas Amslgruber on 13.06.23.
//

import Foundation
import OrderedCollections

public typealias EmojiCategory = AppleEmojiCategory

public enum EmojiManager {

    public enum Version: Double {
        case v13_1 = 13.1
        case v14 = 14
        case v15 = 15
        case v15_1 = 15.1

        public var fileName: String {
            return "emojis_v\(versionIdentifier)"
        }

        public var versionIdentifier: String {
            switch self {
            case .v13_1:
                return "13.1"
            case .v14:
                return "14.0"
            case .v15:
                return "15.0"
            case .v15_1:
                return "15.1"
            }
        }

        public static func getSupportedVersion() -> Version {
            if #available(iOS 17.4, *) {
                return .v15_1
            } else if #available(iOS 16.4, *) {
                return .v15
            } else if #available(iOS 15.4, *) {
                return .v14
            } else {
                return .v13_1
            }
        }
    }

    // When skin tone modifiers are stripped from some emojis,
    // they don't have the same Unicode scalar values as the neutral version.
    // We need to maintain a manual mapping so that the lists of variations are accurate.
    private static let emojiSpecialMapping: [[UInt32]: UInt32] = [
        [0x1FAF1, 0x200D, 0x1FAF2]: 0x1F91D, // 🤝 handshake
        [0x1F469, 0x200D, 0x1F91D, 0x200D, 0x1F469]: 0x1F46D, // 👭 women holding hands
        [0x1F469, 0x200D, 0x1F91D, 0x200D, 0x1F468]: 0x1F46B, // 👫 woman and man holding hands
        [0x1F468, 0x200D, 0x1F91D, 0x200D, 0x1F468]: 0x1F46C, // 👬 men holding hands
        [0x1F9D1, 0x200D, 0x2764, 0x200D, 0x1F48B, 0x200D, 0x1F9D1]: 0x1F48F, // 💏 kiss: person, person
        [0x1F9D1, 0x200D, 0x2764, 0x200D, 0x1F9D1]: 0x1F491, // 💑 couple with heart: person, person
    ]

    private static func uint32ToEmoji(_ value: UInt32) -> String? {
        // Create a Unicode scalar from the UInt32 value
        guard let scalar = UnicodeScalar(value) else {
            print("Invalid Unicode scalar value")
            return nil
        }

        // Create a Character from the Unicode scalar
        let character = Character(scalar)

        // Convert the Character to a String and return it
        return String(character)
    }

    /// Returns all emojis for a specific version
    /// - Parameters:
    ///   - version: The specific version you want to fetch (default: the highest supported version for a device's iOS version)
    ///   - showAllVariations: Some emojis include skin type variations which increases the number of emojis drastically. (default: only the yellow neutral emojis are returned)
    ///   - url: Specify the location of the `emoji_v<version_number>.json` files if needed (default: bundle resource path)
    /// - Returns: Array of categories with all emojis that are assigned to each category
    public static func getAvailableEmojis(version: Version = .getSupportedVersion(), showAllVariations: Bool = false, at url: URL? = nil) -> [EmojiCategory] {
        let fileUrl = url ?? Bundle.module.url(forResource: version.fileName, withExtension: "json")
        if let url = fileUrl, let content = try? Data(contentsOf: url), let result = try? JSONDecoder().decode([UnicodeEmojiCategory].self, from: content) {
            var filteredEmojis: [UnicodeEmojiCategory] = []
            var appleCategories: [AppleEmojiCategory] = []
            for category in result {
                var variations = [String: [Emoji]]()
                var supportedEmojis = OrderedDictionary<String, Emoji>()
                category.emojis.forEach {
                    if isNeutralEmoji(for: $0.key) {
                        supportedEmojis[$0.key] = $0.value
                    } else if showAllVariations {
                        let unqualifiedNeutralEmoji = unqualifiedNeutralEmoji(for: $0.key)

                        if let variationsForEmoji = variations[unqualifiedNeutralEmoji] {
                            variations[unqualifiedNeutralEmoji] = variationsForEmoji + [$0.value]
                        } else {
                            variations[unqualifiedNeutralEmoji] = [$0.value]
                        }
                    }
                }

                let unicodeCategory = UnicodeEmojiCategory(name: category.name, emojis: supportedEmojis)
                filteredEmojis.append(unicodeCategory)

                if shouldMergeCategory(category), let index = appleCategories.firstIndex(where: { $0.name == .smileysAndPeople }) {
                    if category.name == .smileysAndEmotions {
                        let oldEmojis = appleCategories[index].emojis
                        appleCategories[index].emojis = supportedEmojis
                        appleCategories[index].emojis.merge(oldEmojis) { (current, _) in current }

                        let oldVariations = appleCategories[index].variations
                        appleCategories[index].variations = variations
                        appleCategories[index].variations.merge(oldVariations) { (current, _) in current }
                    } else {
                        appleCategories[index].emojis.merge(supportedEmojis) { (current, _) in current }
                        appleCategories[index].variations.merge(variations) { (current, _) in current }
                    }
                } else {
                    guard let appleCategory = unicodeCategory.appleCategory else {
                        continue
                    }
                    appleCategories.append(AppleEmojiCategory(name: appleCategory, emojis: supportedEmojis, variations: variations))
                }
            }
            return appleCategories.sorted(by: { $0.name.order < $1.name.order })
        }
        return []
    }

    private static func shouldMergeCategory(_ category: UnicodeEmojiCategory) -> Bool {
        return category.name == .smileysAndEmotions || category.name == .peopleAndBody
    }

    private static let skinToneRange: ClosedRange<UInt32> = 0x1F3FB...0x1F3FF

    public static func isNeutralEmoji(for emojiValue: String) -> Bool {
        return emojiValue.unicodeScalars.allSatisfy { !skinToneRange.contains($0.value) }
    }

    public static func isSkinToneModifier(scalar: Unicode.Scalar) -> Bool {
        return skinToneRange.contains(scalar.value)
    }

    public static func neutralEmoji(for emojiValue: String) -> String {
        let filteredScalars = emojiValue.unicodeScalars.filter { !isSkinToneModifier(scalar: $0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    public static func unqualifiedNeutralEmoji(for emoji: String) -> String {
        let variationSelector: Character = "\u{FE0F}"
        var unqualifiedEmoji = ""

        for scalar in neutralEmoji(for: emoji).unicodeScalars {
            let character = Character(scalar)
            if character != variationSelector {
                unqualifiedEmoji.append(character)
            }
        }

        let unicodeScalars = unqualifiedEmoji.unicodeScalars.map { $0.value }
        if let actualUnqualifiedNeutralScalar = emojiSpecialMapping[unicodeScalars],
           let actualUnqualifiedNeutralEmoji = uint32ToEmoji(actualUnqualifiedNeutralScalar) {
            return String(actualUnqualifiedNeutralEmoji)
        }

        return unqualifiedEmoji
    }
}
