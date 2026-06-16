//
//  MarkUp-FileDocument.swift
//  MarkUp
//
//  Created by Dimitri Fontaine on 15/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownEngineLite


private extension UTType {
    static let markupMarkdown = UTType(importedAs: "net.daringfireball.markdown")
}


// MARK: - MarkdownDocument
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markupMarkdown] }
    static var writableContentTypes: [UTType] { [.markupMarkdown] }

    var text: String

    init(text: String = "# New document\n\nStart writing…") {
        self.text = text
    }

    // Load
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            self.text = string
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    // Save
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}
