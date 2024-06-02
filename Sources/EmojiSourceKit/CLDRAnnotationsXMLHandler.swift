//
//  CLDRAnnotationsXMLHandler.swift
//
//
//  Created by Terry Yiu on 6/2/24.
//

import Foundation
import EmojiKit

class CLDRAnnotationsXMLHandler: NSObject, XMLParserDelegate {
    var currentElement = ""
    var currentEmoji: Emoji?
    var emojis = [Emoji]()
    var currentEmojiValue = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "annotation" && attributeDict["type"] != "tts" {
           if let cp = attributeDict["cp"] {
               currentEmoji = Emoji(value: cp, keywords: [])
               currentEmojiValue = ""
            }
        }
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "annotation" {
            currentEmojiValue += string.trim()
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "annotation" {
            if let emoji = currentEmoji {
                let values = currentEmojiValue.split(separator: "|").map { $0.trim() }
                emojis.append(Emoji(value: emoji.value, keywords: values))
            }
        }
        currentElement = ""
        currentEmojiValue = ""
        currentEmoji = nil
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parse error: \(parseError.localizedDescription)\n")
    }

    var emojisMap: [String: Emoji] {
        emojis.reduce(into: [String: Emoji]()) { $0[$1.value] = $1 }
    }
}

extension Character {
    var isEmoji: Bool { unicodeScalars.contains(where: { $0.properties.isEmoji }) }
}
