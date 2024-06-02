//
//  File.swift
//  
//
//  Created by Niklas Amslgruber on 10.06.23.
//

import Foundation
import ArgumentParser
import EmojiKit

#if os(macOS)
struct EmojiDownloader: ParsableCommand, AsyncParsableCommand {

    static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "download",
        abstract: "Downloads a list of all available emojis and their counts from unicode.rog for the respective unicode version"
    )

    @Argument var path: String
    @Option(name: .shortAndLong) var version: EmojiManager.Version = .v15

    private func getPath() -> String {
        #if DEBUG
        var url = URL(filePath: #file)
        url = url.deletingLastPathComponent().deletingLastPathComponent()
        url.append(path: "EmojiKit/Resources")

        return url.absoluteString
        #else
        return path
        #endif
    }

    func run() async throws {
        print("⚙️", "Starting to download all emojis for version \(version.rawValue) from unicode.org...\n")

        guard let emojiListURL = await getTemporaryURLForEmojiList(version: version) else {
            print("⚠️", "Could not get content from unicode.org. The emoji list is not available.\n")
            return
        }

        guard let emojiCountsURL = await getTemporaryURLForEmojiCounts(version: version) else {
            print("⚠️", "Could not get content from unicode.org. The emoji count file is not available.\n")
            return
        }

        guard let cldrAnnotationsURL = await getURLForCLDRAnnotations() else {
            return
        }

        guard let cldrAnnotationsDerivedURL = await getURLForCLDRAnnotationsDerived() else {
            return
        }

        print("🎉", "Successfully retrieved temporary URLs for version \(version.rawValue).\n")

        print("⚙️", "Starting to parse content...\n")

        print("Trying CLDR data at \(cldrAnnotationsURL)\n")

        let cldrAnnotationsHandle = try FileHandle(forReadingFrom: cldrAnnotationsURL)
        guard let cldrAnnotationsData = try cldrAnnotationsHandle.readToEnd() else {
            print("⚠️", "Could not read CLDR annotations data.\n")
            return
        }

        let cldrAnnotationsMap = emojisMap(data: cldrAnnotationsData) ?? [:]

        print("Trying CLDR data at \(cldrAnnotationsDerivedURL)\n")

        let cldrAnnotationsDerivedHandle = try FileHandle(forReadingFrom: cldrAnnotationsDerivedURL)
        guard let cldrAnnotationsDerivedData = try cldrAnnotationsDerivedHandle.readToEnd() else {
            print("⚠️", "Could not read CLDR annotations derived data.\n")
            return
        }
        let cldrAnnotationsDerivedMap = emojisMap(data: cldrAnnotationsDerivedData) ?? [:]

        let allCLDRAnnotationsMap = cldrAnnotationsMap.merging(cldrAnnotationsDerivedMap) { (current, _) in current }

        let parser = UnicodeParser()

        do {
            let emojisByCategory: [UnicodeEmojiCategory] = try await parser.parseEmojiList(for: emojiListURL, emojisMap: allCLDRAnnotationsMap)

            let emojiCounts: [UnicodeEmojiCategory.Name: Int] = parser.parseCountHTML(for: emojiCountsURL)

            for category in emojisByCategory {
                assert(emojiCounts[category.name] == category.emojis.count)
            }

            print("🎉", "Successfully parsed emojis and matched counts to the count file.\n")

            save(data: emojisByCategory, for: version)

            print("🎉", "Successfully saved emojis to file.\n")

        } catch {
            print("⚠️", "Could not parse emoji lists or emoji counts. Process failed with: \(error).\n")
        }
    }

    func emojisMap(data: Data) -> [String: Emoji]? {
        print("emojisMap\n")
        let parser = XMLParser(data: data)
        let handler = CLDRAnnotationsXMLHandler()
        parser.delegate = handler

        if parser.parse() {
            return handler.emojisMap
        } else {
            print("Failed to parse XML\n")
            return nil
        }
    }

    func getURLForCLDRAnnotations() async -> URL? {
        return await load(urlString: "https://raw.githubusercontent.com/unicode-org/cldr/c1dc8c7ef6584668345cf741e51b1722d8114bc8/common/annotations/en.xml")
    }

    func getURLForCLDRAnnotationsDerived() async -> URL? {
        return await load(urlString: "https://raw.githubusercontent.com/unicode-org/cldr/c1dc8c7ef6584668345cf741e51b1722d8114bc8/common/annotationsDerived/en.xml")
    }

    func getTemporaryURLForEmojiList(version: EmojiManager.Version) async -> URL? {
        return await load(urlString: "https://unicode.org/Public/emoji/\(version.versionIdentifier)/emoji-test.txt")
    }

    func getTemporaryURLForEmojiCounts(version: EmojiManager.Version) async -> URL? {
        return await load(urlString: "https://www.unicode.org/emoji/charts-\(version.versionIdentifier)/emoji-counts.html")
    }

    private func load(urlString: String) async -> URL? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        let session = URLSession(configuration: .default)

        do {
            let (tmpFileURL, response) = try await session.download(from: url)

            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200 else {
                print("⚠️", "Failed with a non 200 HTTP status")
                return nil
            }
            return tmpFileURL
        } catch {
            print("⚠️", error)
            return nil
        }
    }

    private func save(data: [UnicodeEmojiCategory], for: EmojiManager.Version) {
        let directory = getPath()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let result = try? encoder.encode(data) else {
            print("⚠️", "Couldn't encode emoji categories.")
            return
        }

        var filePath = URL(filePath: directory)
        filePath.append(path: "\(version.fileName).json")
        let jsonString = String(data: result, encoding: .utf8)

        print("⚙️", "Saving emojis to file \(filePath.absoluteString)...\n")

        if FileManager.default.fileExists(atPath: filePath.absoluteString) == false {
            FileManager.default.createFile(atPath: filePath.absoluteString, contents: nil)
        }

        do {
            try jsonString?.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("⚠️", error)
        }
    }
}
#endif
extension EmojiManager.Version: ExpressibleByArgument {}
