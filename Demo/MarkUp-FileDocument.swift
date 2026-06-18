//
//  MarkUp-FileDocument.swift
//  MarkUp
//
//  Created by Dimitri Fontaine on 15/06/2026.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import MarkdownEngineLite


extension UTType {
    static let markupMarkdown = UTType(importedAs: "net.daringfireball.markdown")
    static let textBundle = UTType(importedAs: "org.textbundle.package")
}


// MARK: - MarkdownDocument
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markupMarkdown, .textBundle] }
    static var writableContentTypes: [UTType] { [.markupMarkdown, .textBundle] }

    var text: String
    private var textBundleInfo: [String: Any]
    private var textBundleAssets: [String: Data]
    var hasEmbeddedAssets: Bool {
        !textBundleAssets.isEmpty
    }

    init(text: String = "# New document\n\nStart writing…") {
        self.text = text
        self.textBundleInfo = Self.defaultTextBundleInfo
        self.textBundleAssets = [:]
    }

    // Load
    init(configuration: ReadConfiguration) throws {
        if configuration.contentType == .textBundle || configuration.file.isDirectory {
            let bundle = try Self.readTextBundle(from: configuration.file)
            self.text = bundle.text
            self.textBundleInfo = bundle.info
            self.textBundleAssets = bundle.assets
            return
        }

        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.text = string
        self.textBundleInfo = Self.defaultTextBundleInfo
        self.textBundleAssets = [:]
    }

    // Save
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if configuration.contentType == .textBundle {
            return try textBundleFileWrapper()
        }

        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }

    func writeTextBundle(to url: URL) throws {
        let wrapper = try textBundleFileWrapper()
        try wrapper.write(
            to: url,
            options: [.atomic],
            originalContentsURL: nil
        )
    }

    private func textBundleFileWrapper() throws -> FileWrapper {
        var wrappers: [String: FileWrapper] = [:]

        wrappers["text.md"] = FileWrapper(
            regularFileWithContents: text.data(using: .utf8) ?? Data()
        )

        let info = mergedTextBundleInfo()
        let infoData = try JSONSerialization.data(
            withJSONObject: info,
            options: [.prettyPrinted, .sortedKeys]
        )
        wrappers["info.json"] = FileWrapper(regularFileWithContents: infoData)

        let assetWrappers = textBundleAssets.mapValues { data in
            FileWrapper(regularFileWithContents: data)
        }
        wrappers["assets"] = FileWrapper(directoryWithFileWrappers: assetWrappers)

        return FileWrapper(directoryWithFileWrappers: wrappers)
    }

    private func mergedTextBundleInfo() -> [String: Any] {
        var info = textBundleInfo
        info["version"] = 2
        info["type"] = "net.daringfireball.markdown"
        if info["transient"] == nil {
            info["transient"] = false
        }
        return info
    }

    mutating func addImageAsset(data: Data, originalFilename: String) -> String {
        let filename = uniqueAssetFilename(from: originalFilename)
        textBundleAssets[filename] = data
        return "assets/\(filename)"
    }

    func imageData(for path: String) -> Data? {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let assetName: String

        if normalizedPath.hasPrefix("assets/") {
            assetName = String(normalizedPath.dropFirst("assets/".count))
        } else {
            assetName = normalizedPath
        }

        return textBundleAssets[assetName]
    }

    private func uniqueAssetFilename(from filename: String) -> String {
        let sanitized = Self.sanitizedAssetFilename(from: filename)
        let url = URL(fileURLWithPath: sanitized)
        let baseName = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension

        var candidate = sanitized
        var index = 2

        while textBundleAssets[candidate] != nil {
            if pathExtension.isEmpty {
                candidate = "\(baseName)-\(index)"
            } else {
                candidate = "\(baseName)-\(index).\(pathExtension)"
            }
            index += 1
        }

        return candidate
    }

    private static func sanitizedAssetFilename(from filename: String) -> String {
        let fallback = "image.png"
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return fallback
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))

        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func readTextBundle(
        from wrapper: FileWrapper
    ) throws -> (text: String, info: [String: Any], assets: [String: Data]) {
        guard wrapper.isDirectory,
              let fileWrappers = wrapper.fileWrappers else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard let textWrapper = textFileWrapper(in: fileWrappers),
              let textData = textWrapper.regularFileContents,
              let text = String(data: textData, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let info = infoDictionary(from: fileWrappers["info.json"])
        let assets = assetData(from: fileWrappers["assets"])
        return (text, info, assets)
    }

    private static func textFileWrapper(
        in fileWrappers: [String: FileWrapper]
    ) -> FileWrapper? {
        if let wrapper = fileWrappers["text.md"] {
            return wrapper
        }
        if let wrapper = fileWrappers["text.markdown"] {
            return wrapper
        }

        return fileWrappers
            .sorted { $0.key < $1.key }
            .first { name, wrapper in
                name.lowercased().hasPrefix("text.") && wrapper.isRegularFile
            }?
            .value
    }

    private static func infoDictionary(from wrapper: FileWrapper?) -> [String: Any] {
        guard let data = wrapper?.regularFileContents,
              let object = try? JSONSerialization.jsonObject(with: data),
              let info = object as? [String: Any] else {
            return defaultTextBundleInfo
        }
        return info
    }

    private static func assetData(from wrapper: FileWrapper?) -> [String: Data] {
        guard let fileWrappers = wrapper?.fileWrappers else {
            return [:]
        }

        return fileWrappers.reduce(into: [:]) { result, item in
            guard item.value.isRegularFile,
                  let data = item.value.regularFileContents else {
                return
            }
            result[item.key] = data
        }
    }

    private static var defaultTextBundleInfo: [String: Any] {
        [
            "version": 2,
            "type": "net.daringfireball.markdown",
            "transient": false
        ]
    }
}
