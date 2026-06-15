import SwiftUI

public struct MarkdownEditor: View {
    private let title: String
    @Binding private var text: String
    @Binding private var mode: MarkdownEditorMode
    @Binding private var selectedRange: Range<String.Index>?

    private let configuration: MarkdownEditorConfiguration
    private let placeholder: String

    public init(
        title: String = "Document",
        text: Binding<String>,
        mode: MarkdownEditorMode = .edit,
        selectedRange: Binding<Range<String.Index>?> = .constant(nil),
        placeholder: String = "Start writing...",
        configuration: MarkdownEditorConfiguration = .default
    ) {
        self.title = title
        self._text = text
        self._mode = .constant(mode)
        self._selectedRange = selectedRange
        self.placeholder = placeholder
        self.configuration = configuration
    }

    public init(
        title: String = "Document",
        text: Binding<String>,
        mode: Binding<MarkdownEditorMode>,
        selectedRange: Binding<Range<String.Index>?> = .constant(nil),
        placeholder: String = "Start writing...",
        configuration: MarkdownEditorConfiguration = .default
    ) {
        self.title = title
        self._text = text
        self._mode = mode
        self._selectedRange = selectedRange
        self.placeholder = placeholder
        self.configuration = configuration
    }

    public var body: some View {
        VStack(spacing: 0) {
            if configuration.showsModePicker {
                Picker("", selection: $mode) {
                    ForEach(MarkdownEditorMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(configuration.contentInsets)

                Divider()
            }

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        
        LiveMarkdownTextEditor(
            title: title,
            text: $text,
            mode: $mode,
            selectedRange: $selectedRange,
            placeholder: placeholder,
            configuration: configuration
        )
    }
}


public enum MarkdownEditorMode: String, CaseIterable, Identifiable {
    case edit
    case preview

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .edit:
            return "Edit"
        case .preview:
            return "Preview"
        }
    }
}
