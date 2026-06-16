//
//  ContentView.swift
//  MarkUp
//
//  Created by Dimitri Fontaine on 12/06/2026.
//

import SwiftUI
import AppKit
import MarkdownEngineLite


struct ContentView: View {
    
    @Binding var document: MarkdownDocument
    let documentURL: URL?
    
    @State private var selectedRange: Range<String.Index>?
    @State private var mode: MarkdownEditorMode
    
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
            selectedRange: $selectedRange
        )
        
        .navigationTitle(documentURL?.lastPathComponent ?? "New document")
       
    }
    
}
