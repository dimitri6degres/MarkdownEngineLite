//
//  ContentView.swift
//  MarkUp ios
//
//  Created by Dimitri Fontaine on 14/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers





struct ContentView: View {
    
    @Binding var document: MarkdownDocument
    let documentURL: URL?
    
    @State private var selectedRange: Range<String.Index>?
    
    
   
    var body: some View {
        MarkdownEditor(
            title: documentURL?.deletingPathExtension().lastPathComponent ?? "Document",
            text: $document.text,
            mode: $document.mode,
            selectedRange: $selectedRange,
            placeholder: "Écrire en Markdown...",
            configuration: MarkdownEditorConfiguration(contentInsets:  EdgeInsets(top: 12, leading: UIDevice.isIPhone ? 20 : 50, bottom: 12, trailing: UIDevice.isIPhone ? 20 : 50))
        )
        .navigationTitle(documentURL?.lastPathComponent ?? "Nouveau document")
        
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
