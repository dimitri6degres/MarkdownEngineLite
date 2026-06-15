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
    
    var body: some View {
        
        MarkdownEditor(
            title: documentURL?.deletingPathExtension().lastPathComponent ?? "Document",
            text: $document.text,
            mode: $document.mode,
            selectedRange: $selectedRange
        )
        
        .navigationTitle(documentURL?.lastPathComponent ?? "New document")
       
    }
    
}
