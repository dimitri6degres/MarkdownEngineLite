//
//  MarkUp_iosApp.swift
//  MarkUp ios
//
//  Created by Dimitri Fontaine on 14/06/2026.
//

import SwiftUI


@main
struct MarkUpApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, documentURL: file.fileURL)
        }
    }
}
