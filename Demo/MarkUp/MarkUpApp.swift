//
//  MarkUpApp.swift
//  MarkUp
//
//  Created by Dimitri Fontaine on 12/06/2026.
//

import SwiftUI


@main
struct MarkUpApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, documentURL: file.fileURL)
                .frame(minWidth: 980, minHeight: 720)
        }
        .commands {
            PrintMarkdownCommands()
        }
    }
}

private struct PrintMarkdownDocumentKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var printMarkdownDocument: (() -> Void)? {
        get { self[PrintMarkdownDocumentKey.self] }
        set { self[PrintMarkdownDocumentKey.self] = newValue }
    }
}

private struct PrintMarkdownCommands: Commands {
    @FocusedValue(\.printMarkdownDocument) private var printMarkdownDocument

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Print...") {
                printMarkdownDocument?()
            }
            .keyboardShortcut("p")
            .disabled(printMarkdownDocument == nil)
        }
    }
}
