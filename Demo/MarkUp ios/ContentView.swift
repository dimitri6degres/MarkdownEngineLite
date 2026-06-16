//
//  ContentView.swift
//  MarkUp ios
//
//  Created by Dimitri Fontaine on 14/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers
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
            selectedRange: $selectedRange,
            configuration: MarkdownEditorConfiguration(contentInsets:  EdgeInsets(top: 12, leading: UIDevice.isIPhone ? 20 : 50, bottom: 12, trailing: UIDevice.isIPhone ? 35 : 50))
        )
        .navigationTitle(documentURL?.lastPathComponent ?? "New document")
        
    }
    
    
    
}



extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}
