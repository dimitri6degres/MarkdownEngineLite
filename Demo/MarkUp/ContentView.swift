//
//  ContentView.swift
//  MarkUp
//
//  Created by Dimitri Fontaine on 12/06/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MarkdownEngineLite


struct ContentView: View {
    
    @Environment(\.dismiss) private var dismiss

    @Binding var document: MarkdownDocument
    let documentURL: URL?
    
    @State private var selectedRange: Range<String.Index>?
    @State private var mode: MarkdownEditorMode
    @State private var isImportingImage = false
    @State private var isExportingPDF = false
    @State private var shouldSuggestTextBundleExport = false
    @State private var imageImportError: String?
    @State private var pdfDocument = MarkdownPDFDocument(data: Data())
    @State private var pdfExportError: String?
    
    init(document: Binding<MarkdownDocument>, documentURL: URL?) {
        self._document = document
        self.documentURL = documentURL
        self._mode = State(initialValue: documentURL == nil ? .edit : .preview)
    }
    
    var body: some View {
        
        MarkdownEditor(
            title: documentURL?.deletingPathExtension().lastPathComponent ?? "Document",
            text: $document.text,
            mode: $mode,
            selectedRange: $selectedRange,
            configuration: MarkdownEditorConfiguration(
                showsPdfExporter: false,
                imageDataProvider: { path in
                    document.imageData(for: path)
                }
            )
        )
        
        .navigationTitle(documentURL?.lastPathComponent ?? "New document")
        .toolbar {
                           
            ToolbarItem {
                Button {
                    mode = mode == .edit ? .preview : .edit
                } label: {
                    Label {
                        Text(mode == .edit ? "Preview mode" : "Edit mode")
                    } icon: {
                        Image(mode == .edit ? "eye" : "pen")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
            ToolbarItem {
                Button {
                    isImportingImage = true
                } label: {
                    Label {
                        Text("Insert Image")
                    } icon: {
                        Image("import")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
            ToolbarItem {
                Button {
                    exportPDF()
                } label: {
                    Label {
                        Text("Export PDF")
                    } icon: {
                        Image("export")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            importImage(from: result)
        }
        .alert(
            "Image import failed",
            isPresented: Binding(
                get: { imageImportError != nil },
                set: { if !$0 { imageImportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageImportError ?? "")
        }
        .alert(
            "Convert to TextBundle?",
            isPresented: $shouldSuggestTextBundleExport
        ) {
            Button("Convert") {
                convertDocumentToTextBundle()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Markdown files cannot contain local images by themselves. Choose where to save a TextBundle copy, then MarkUp will open it for you.")
        }
        .fileExporter(
            isPresented: $isExportingPDF,
            document: pdfDocument,
            contentType: .pdf,
            defaultFilename: pdfExportFilename
        ) { result in
            if case .failure(let error) = result {
                pdfExportError = error.localizedDescription
            }
        }
        .alert(
            "PDF export failed",
            isPresented: Binding(
                get: { pdfExportError != nil },
                set: { if !$0 { pdfExportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pdfExportError ?? "")
        }
       
    }

    private func importImage(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let imagePath = document.addImageAsset(
                data: data,
                originalFilename: url.lastPathComponent
            )
            insertImageMarkdown(imagePath: imagePath, fallbackAltText: url.deletingPathExtension().lastPathComponent)
            suggestTextBundleExportIfNeeded()
        } catch {
            imageImportError = error.localizedDescription
        }
    }

    private func insertImageMarkdown(imagePath: String, fallbackAltText: String) {
        let range = selectedRange.flatMap { safeRange($0, in: document.text) }
        let selectedText = range.map { String(document.text[$0]) } ?? ""
        let altText = selectedText.isEmpty ? fallbackAltText : selectedText
        let markdown = "![\(altText)](\(imagePath))"

        if let range {
            let lowerOffset = document.text.distance(from: document.text.startIndex, to: range.lowerBound)
            document.text.replaceSubrange(range, with: markdown)
            let cursor = document.text.index(document.text.startIndex, offsetBy: lowerOffset + markdown.count)
            selectedRange = cursor..<cursor
        } else {
            let prefix = document.text.isEmpty || document.text.hasSuffix("\n") ? "" : "\n\n"
            let insertion = "\(prefix)\(markdown)\n"
            document.text.append(insertion)
            selectedRange = document.text.endIndex..<document.text.endIndex
        }
    }

    private func safeRange(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index>? {
        guard let lowerUTF16 = range.lowerBound.samePosition(in: text.utf16),
              let upperUTF16 = range.upperBound.samePosition(in: text.utf16),
              lowerUTF16 <= upperUTF16,
              let lowerBound = String.Index(lowerUTF16, within: text),
              let upperBound = String.Index(upperUTF16, within: text) else {
            return nil
        }

        return lowerBound..<upperBound
    }

    private func suggestTextBundleExportIfNeeded() {
        guard !isTextBundleDocument else {
            return
        }
        shouldSuggestTextBundleExport = true
    }

    private func convertDocumentToTextBundle() {
        let panel = NSSavePanel()
        panel.title = "Convert to TextBundle"
        panel.nameFieldStringValue = textBundleExportFilename
        panel.directoryURL = documentURL?.deletingLastPathComponent()
        panel.allowedContentTypes = [.textBundle]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let destinationURL = panel.url else {
                return
            }

            do {
                try document.writeTextBundle(to: destinationURL)
                NSWorkspace.shared.open(destinationURL)
                dismiss()
            } catch {
                imageImportError = error.localizedDescription
            }
        }
    }

    private func exportPDF() {
        do {
            pdfDocument = try MarkdownPDFExporter.document(
                markdown: document.text,
                configuration: MarkdownPDFExporter.Configuration(
                    imageDataProvider: { path in
                        document.imageData(for: path)
                    }
                )
            )
            Task { @MainActor in
                isExportingPDF = true
            }
        } catch {
            pdfExportError = error.localizedDescription
        }
    }

    private var isTextBundleDocument: Bool {
        documentURL?.pathExtension.lowercased() == "textbundle"
    }

    private var textBundleExportFilename: String {
        let baseName = documentURL?.deletingPathExtension().lastPathComponent ?? "Document"
        return "\(baseName).textbundle"
    }

    private var pdfExportFilename: String {
        let baseName = documentURL?.deletingPathExtension().lastPathComponent ?? "Document"
        return "\(baseName).pdf"
    }
    
}
