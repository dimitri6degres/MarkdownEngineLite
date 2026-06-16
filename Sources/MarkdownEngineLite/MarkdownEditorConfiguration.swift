import SwiftUI

public struct MarkdownEditorConfiguration: Sendable {
    public var editorFont: Font
    public var bodyFontSize: CGFloat
    public var contentInsets: EdgeInsets
    public var showsModePicker: Bool
    public var showsEditorToolbar: Bool
    public var editorToolbarButtonSize: CGFloat
    public var showsPdfExporter: Bool
    public var autocorrectionDisabled: Bool
    public var spellCheckingDisabled: Bool
    public var hidesMarkdownMarkers: Bool


    public init(
        editorFont: Font = .system(.body, design: .monospaced),
        bodyFontSize: CGFloat = 17,
        contentInsets: EdgeInsets = EdgeInsets(top: 12, leading: 50, bottom: 12, trailing: 50),
        showsModePicker: Bool = false,
        showsEditorToolbar: Bool = true,
        editorToolbarButtonSize: CGFloat = 26,
        showsPdfExporter: Bool = true,
        autocorrectionDisabled: Bool = true,
        spellCheckingDisabled: Bool = false,
        hidesMarkdownMarkers: Bool = true
    ) {
        self.editorFont = editorFont
        self.bodyFontSize = bodyFontSize
        self.contentInsets = contentInsets
        self.showsModePicker = showsModePicker
        self.showsEditorToolbar = showsEditorToolbar
        self.editorToolbarButtonSize = editorToolbarButtonSize
        self.showsPdfExporter = showsPdfExporter
        self.autocorrectionDisabled = autocorrectionDisabled
        self.spellCheckingDisabled = spellCheckingDisabled
        self.hidesMarkdownMarkers = hidesMarkdownMarkers
      
    }

    public static let `default` = MarkdownEditorConfiguration()
}
