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

        print("🎉", "Successfully retrieved temporary URLs for version \(version.rawValue).\n")

        print("⚙️", "Starting to parse content...\n")

        var allCLDRAnnotations = [String: Emoji]()
        for locale in EmojiDownloader.supportedLocales {
            guard let cldrAnnotationsURL = await getURLForCLDRAnnotations(locale: locale) else {
                continue
            }

            guard let cldrAnnotationsDerivedURL = await getURLForCLDRAnnotationsDerived(locale: locale) else {
                continue
            }

            print("Trying CLDR data at \(cldrAnnotationsURL) for locale \(locale)\n")

            let cldrAnnotationsHandle = try FileHandle(forReadingFrom: cldrAnnotationsURL)
            guard let cldrAnnotationsData = try cldrAnnotationsHandle.readToEnd() else {
                print("⚠️", "Could not read CLDR annotations data for locale \(locale).\n")
                continue
            }

            let cldrAnnotationsMap = emojisMap(data: cldrAnnotationsData, locale: locale) ?? [:]

            print("Trying CLDR data at \(cldrAnnotationsDerivedURL) for locale \(locale)\n")

            let cldrAnnotationsDerivedHandle = try FileHandle(forReadingFrom: cldrAnnotationsDerivedURL)
            guard let cldrAnnotationsDerivedData = try cldrAnnotationsDerivedHandle.readToEnd() else {
                print("⚠️", "Could not read CLDR annotations derived data for locale \(locale).\n")
                continue
            }
            let cldrAnnotationsDerivedMap = emojisMap(data: cldrAnnotationsDerivedData, locale: locale) ?? [:]

            allCLDRAnnotations.merge(cldrAnnotationsMap) { (current, new) in
                let combinedKeywords = current.localizedKeywords.merging(new.localizedKeywords) { (current, _) in current }
                return Emoji(value: current.value, localizedKeywords: combinedKeywords)
            }

            allCLDRAnnotations.merge(cldrAnnotationsDerivedMap) { (current, new) in
                let combinedKeywords = current.localizedKeywords.merging(new.localizedKeywords) { (current, _) in current }
                return Emoji(value: current.value, localizedKeywords: combinedKeywords)
            }
        }

        let parser = UnicodeParser()

        do {
            let emojisByCategory: [UnicodeEmojiCategory] = try await parser.parseEmojiList(for: emojiListURL, emojisMap: allCLDRAnnotations)

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

    func emojisMap(data: Data, locale: String) -> [String: Emoji]? {
        let parser = XMLParser(data: data)
        let handler = CLDRAnnotationsXMLHandler(locale: locale)
        parser.delegate = handler

        if parser.parse() {
            return handler.emojisMap
        } else {
            print("Failed to parse XML for locale \(locale)\n")
            return nil
        }
    }

    static let supportedLocales = [
//        "af",
//        "am",
//        "ar",
//        "ar_SA",
//        "as",
//        "ast",
//        "az",
//        "be",
//        "bew",
//        "bg",
//        "bgn",
//        "bn",
//        "br",
//        "bs",
//        "ca",
//        "ccp",
//        "ceb",
//        "chr",
//        "ckb",
//        "cs",
//        "cv",
//        "cy",
//        "da",
//        "de",
//        "de_CH",
//        "doi",
//        "dsb",
//        "el",
        "en",
//        "en_001",
//        "en_AU",
//        "en_CA",
//        "en_GB",
//        "en_IN",
//        "es",
//        "es_419",
//        "es_MX",
//        "es_US",
//        "et",
//        "eu",
//        "fa",
//        "ff",
//        "ff_Adlm",
//        "fi",
//        "fil",
//        "fo",
//        "fr",
//        "fr_CA",
//        "ga",
//        "gd",
//        "gl",
//        "gu",
//        "ha",
//        "ha_NE",
//        "he",
//        "hi",
//        "hi_Latn",
//        "hr",
//        "hsb",
//        "hu",
//        "hy",
//        "ia",
//        "id",
//        "ig",
//        "is",
//        "it",
//        "ja",
//        "jv",
//        "ka",
//        "kab",
//        "kk",
//        "kl",
//        "km",
//        "kn",
//        "ko",
//        "kok",
//        "ku",
//        "ky",
//        "lb",
//        "lij",
//        "lo",
//        "lt",
//        "lv",
//        "mai",
//        "mi",
//        "mk",
//        "ml",
//        "mn",
//        "mni",
//        "mr",
//        "ms",
//        "mt",
//        "my",
//        "nb",
//        "ne",
//        "nl",
//        "nn",
//        "no",
//        "nso",
//        "oc",
//        "om",
//        "or",
//        "pa",
//        "pa_Arab",
//        "pcm",
//        "pl",
//        "ps",
//        "pt",
//        "pt_PT",
//        "qu",
//        "quc",
//        "rhg",
//        "rm",
//        "ro",
//        "root",
//        "ru",
//        "rw",
//        "sa",
//        "sat",
//        "sc",
//        "sd",
//        "si",
//        "sk",
//        "sl",
//        "so",
//        "sq",
//        "sr",
//        "sr_Cyrl",
//        "sr_Cyrl_BA",
//        "sr_Latn",
//        "sr_Latn_BA",
//        "su",
//        "sv",
//        "sw",
//        "sw_KE",
//        "ta",
//        "te",
//        "tg",
//        "th",
//        "ti",
//        "tk",
//        "tn",
//        "to",
//        "tr",
//        "tt",
//        "ug",
//        "uk",
//        "ur",
//        "uz",
//        "vi",
//        "wo",
//        "xh",
//        "yo",
//        "yo_BJ",
//        "yue",
//        "yue_Hans",
//        "zh",
//        "zh_Hant",
//        "zh_Hant_HK",
//        "zu"
    ]

    func getURLForCLDRAnnotations(locale: String) async -> URL? {
        return await load(urlString: "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/\(locale).xml")
    }

    func getURLForCLDRAnnotationsDerived(locale: String) async -> URL? {
        return await load(urlString: "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotationsDerived/\(locale).xml")
    }

    func getTemporaryURLForEmojiList(version: EmojiManager.Version) async -> URL? {
        if version == .v15 {
            return await load(urlString: "https://raw.githubusercontent.com/unicode-org/cldr/ed4f82917078fb71f093977a973b30a6151fa28b/tools/cldr-code/src/main/resources/org/unicode/cldr/util/data/emoji/emoji-test.txt")
        } else {
            return await load(urlString: "https://unicode.org/Public/emoji/\(version.versionIdentifier)/emoji-test.txt")
        }
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
                print("⚠️", "Failed with a non 200 HTTP status on \(urlString)")
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
