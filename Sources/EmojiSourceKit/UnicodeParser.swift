//
//  UnicodeParser.swift
//  
//
//  Created by Niklas Amslgruber on 12.06.23.
//

import Foundation
import SwiftSoup
import EmojiKit
import OrderedCollections

class UnicodeParser {

    enum Tags: String {
        case comment = "#"
        case group = "# group:"
        case unqualified
        case minimallyQualified = "minimally-qualified"
    }

    func parseEmojis(for fileUrl: URL) async throws {
        URLSession.shared.dataTask(with: fileUrl) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to download data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Parse the downloaded XML data
            self.parseXML(data: data)
        }
    }

    func parseXML(data: Data) {
        let parser = XMLParser(data: data)
        let handler = CLDRAnnotationsXMLHandler()
        parser.delegate = handler
        parser.parse()
    }

    func parseEmojiList(for fileUrl: URL, emojisMap: [String: Emoji]) async throws -> [UnicodeEmojiCategory] {
        let handle = try FileHandle(forReadingFrom: fileUrl)
        var currentGroup: UnicodeEmojiCategory.Name = .activities
        var emojisByGroup: [UnicodeEmojiCategory.Name: OrderedDictionary<String, Emoji>] = [:]

        for try await line in handle.bytes.lines {

            /// Skip comments, but keep groups
            if isLine(line, ofType: .comment), isLine(line, ofType: .group) == false {
                continue
            }

            /// Get current group
            if isLine(line, ofType: .group) {
                let name = line.split(separator: ":")
                let categoryName = name.last?.trim() ?? ""
                guard let category = UnicodeEmojiCategory.Name(rawValue: categoryName) else {
                    continue
                }
                currentGroup = category
                emojisByGroup[category] = [:]
            }

            /// Split line into list of entries
            let lineComponents = line.split(separator: ";")

            /// Get hex-string from components
            guard let hexString = lineComponents.map({ $0.trim() }).first else {
                continue
            }

            /// Check if category exists
            guard lineComponents.count > 1 else {
                continue
            }

            let category = lineComponents[1].trim()

            /// Remove `unqualified` or `minimally-qualified` entries
            guard (isLine(category, ofType: .unqualified) || isLine(category, ofType: .minimallyQualified)) == false else {
                continue
            }

            let hexComponents = hexString.split(separator: " ")

            /// Check for multi-hex emojis
            if hexComponents.count > 1 {
                let multiHexEmoji = hexComponents.compactMap({ $0.asEmoji() }).joined()

                if multiHexEmoji.isEmpty == false {
                    if let mapLookup = emojisMap[makeEmojiUnqualified(emoji: multiHexEmoji)] {
                        if mapLookup.keywords.isEmpty == true {
                            print("Could not find keywords in emojis map for multiHex: \(multiHexEmoji)\n")
                        }
                        emojisByGroup[currentGroup]?[multiHexEmoji] = Emoji(value: multiHexEmoji, keywords: mapLookup.keywords)
                    } else {
                        print("Could not find in emojis map at all for multiHex: \(multiHexEmoji)\n")
                        emojisByGroup[currentGroup]?[multiHexEmoji] = Emoji(value: multiHexEmoji, keywords: [])
                    }
                }
            } else {
                if let unicode = hexString.asEmoji(), unicode.isEmpty == false {
                    if let mapLookup = emojisMap[makeEmojiUnqualified(emoji: unicode)] {
                        emojisByGroup[currentGroup]?[unicode] = Emoji(value: unicode, keywords: mapLookup.keywords)
                    } else {
                        emojisByGroup[currentGroup]?[unicode] = Emoji(value: unicode, keywords: [])
                    }
                }
            }
        }
        try handle.close()

        var result: [UnicodeEmojiCategory] = []

        for category in UnicodeEmojiCategory.Name.allCases {
            result.append(UnicodeEmojiCategory(name: category, emojis: emojisByGroup[category] ?? OrderedDictionary<String, Emoji>()))
        }
        return result
    }

    func makeEmojiUnqualified(emoji: String) -> String {
        let variationSelector: Character = "\u{FE0F}"
        var unqualifiedEmoji = ""

        for scalar in emoji.unicodeScalars {
            let character = Character(scalar)
            if character != variationSelector {
                unqualifiedEmoji.append(character)
            }
        }

        return unqualifiedEmoji
    }

    func parseCountHTML(for url: URL) -> [UnicodeEmojiCategory.Name: Int] {
        do {
            let html = try String(contentsOf: url)
            let doc: Document = try SwiftSoup.parse(html)

            guard let table = try doc.select("table").first() else {
                return [:]
            }

            let rows: Elements = try table.select("tbody tr")
            let categories = rows.first
            let totals = rows.last

            guard let categories, let totals, let categoryEntries = try? categories.select("th"), let countEntries = try? totals.select("th") else {
                return [:]
            }

            var categoryNames: [UnicodeEmojiCategory.Name] = []
            var countNumbers: [Int] = []

            for categoryElement in categoryEntries {
                if categoryElement == categoryEntries.first || categoryElement == categoryEntries.last {
                    continue
                }
                guard let text = try? categoryElement.text(), let category = UnicodeEmojiCategory.Name(rawValue: text) else {
                    continue
                }
                categoryNames.append(category)
            }

            for countElement in countEntries {
                if countElement == countEntries.first || countElement == countEntries.last {
                    continue
                }
                guard let text = try? countElement.text(), let number = Int(text) else {
                    continue
                }
                countNumbers.append(number)
            }

            var result: [UnicodeEmojiCategory.Name: Int] = [:]

            for (index, categoryName) in categoryNames.enumerated() {
                result[categoryName] = countNumbers[index]
            }

            return result
        } catch {
            print("Error parsing HTML: \(error)")
        }

        return [:]
    }

    private func isLine(_ line: String, ofType type: Tags) -> Bool {
        return line.starts(with: type.rawValue)
    }
}
