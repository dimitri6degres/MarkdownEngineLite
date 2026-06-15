//
//  MarkUp-FileDocument.swift
//  MarkUp
//
//  Created by Dimitri Fontaine on 15/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownEngineLite


// Safe Markdown UTType fallback for platforms where `.markdown` may be unavailable
private extension UTType {
    static var safeMarkdown: UTType {
        if let md = UTType(filenameExtension: "md") {
            return md
        }
        return .plainText
    }
}


// MARK: - MarkdownDocument
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.safeMarkdown, .plainText] }
    static var writableContentTypes: [UTType] { [.safeMarkdown, .plainText] }

    var text: String
    var mode: MarkdownEditorMode //= .edit

    init(text: String = "# New document\n\nStart writing…") {
        self.text = text
        self.mode = .edit
    }

    // Load
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            self.text = string
            self.mode = .preview
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

