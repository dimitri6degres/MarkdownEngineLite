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
    }
}

