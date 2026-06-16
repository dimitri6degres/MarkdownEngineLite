import SwiftUI
import UniformTypeIdentifiers

struct LiveMarkdownTextEditor: View {
    let title: String
    @Binding var text: String
    @Binding var mode: MarkdownEditorMode
    @Binding var selectedRange: Range<String.Index>?

    let placeholder: String
    let configuration: MarkdownEditorConfiguration
    @State private var isExportingPDF = false
    @State private var pdfDocument: MarkdownPDFDocument?

    private var isEditable: Bool {
        mode == .edit
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topLeading) {
                PlatformMarkdownTextView(
                    text: $text,
                    selectedRange: $selectedRange,
                    configuration: configuration,
                    isEditable: isEditable
                )
                
                if text.isEmpty && isEditable {
                    Text(placeholder)
                        .font(configuration.editorFont)
                        .foregroundStyle(.secondary)
                        .padding(configuration.contentInsets)
                        .allowsHitTesting(false)
                }
            }
            
            
            VStack(alignment: .trailing, spacing: 10) {
                if configuration.showsPdfExporter {
                    CustomButtonLabel(text: "PDF Export",
                                      image: "export",
                                      editorToolbarButtonSize: configuration.editorToolbarButtonSize) {
                        exportCurrentViewToPDF()
                    }
                    
                }
                
                if configuration.showsEditorToolbar {
                    VStack(alignment: .center) {
                        
                        CustomButtonLabel(text: "Change mode",
                                          image: isEditable ? "eye" : "pen",
                                          editorToolbarButtonSize: configuration.editorToolbarButtonSize) {
                            mode = isEditable ? .preview : .edit
                        }
                        
                       
                        
                        if isEditable {
                            
                            VStack {
                                
                                CustomButtonLabel(text: "Bold",
                                                  image: "bold",
                                                  editorToolbarButtonSize: configuration.editorToolbarButtonSize,
                                                  small: true) {
                                    selectedRange = MarkdownTextEditing.makeBold(
                                        in: &text,
                                        selectedRange: selectedRange
                                    )
                                }
                                
                                CustomButtonLabel(text: "Italic",
                                                  image: "italic",
                                                  editorToolbarButtonSize: configuration.editorToolbarButtonSize,
                                                  small: true) {
                                    selectedRange = MarkdownTextEditing.makeItalic(
                                        in: &text,
                                        selectedRange: selectedRange
                                    )
                                }
                                
                                CustomButtonLabel(text: "Header",
                                                  image: "header",
                                                  editorToolbarButtonSize: configuration.editorToolbarButtonSize,
                                                  small: true) {
                                    selectedRange = MarkdownTextEditing.applyHeading(
                                        in: &text,
                                        selectedRange: selectedRange
                                    )
                                }
                                
                                CustomButtonLabel(text: "Quotes",
                                                  image: "quotes",
                                                  editorToolbarButtonSize: configuration.editorToolbarButtonSize,
                                                  small: true) {
                                    selectedRange = MarkdownTextEditing.toggleBlockQuote(
                                        in: &text,
                                        selectedRange: selectedRange
                                    )
                                }
                                
                                CustomButtonLabel(text: "Block",
                                                  image: "block",
                                                  editorToolbarButtonSize: configuration.editorToolbarButtonSize,
                                                  small: true) {
                                    selectedRange = MarkdownTextEditing.toggleCodeBlock(
                                        in: &text,
                                        selectedRange: selectedRange
                                    )
                                }
                            }
                            .padding(.vertical, configuration.editorToolbarButtonSize)
                        }
                        
                    }
                }
            }
            .padding(10)
        }
        .fileExporter(
            isPresented: $isExportingPDF,
            document: pdfDocument,
            contentType: .pdf,
            defaultFilename: pdfFilename
        ) { result in
            if case let .failure(error) = result {
                print("Saving PDF failed: \(error)")
            }
        }
    }

    private func exportCurrentViewToPDF() {
        do {
            pdfDocument = try MarkdownPDFExporter.document(markdown: text)
            isExportingPDF = true
        } catch {
            print("PDF export failed: \(error)")
        }
    }

    private var pdfFilename: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedTitle.isEmpty ? "Document" : trimmedTitle
        return baseName.lowercased().hasSuffix(".pdf") ? baseName : baseName + ".pdf"
    }
}

#if os(macOS)
struct PlatformMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: Range<String.Index>?
    let configuration: MarkdownEditorConfiguration
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selectedRange: $selectedRange,
            configuration: configuration,
            isEditable: isEditable
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let textView = MarkdownNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = isEditable ? !configuration.autocorrectionDisabled : false
        textView.isContinuousSpellCheckingEnabled = isEditable ?  !configuration.spellCheckingDisabled : false
        textView.isGrammarCheckingEnabled = isEditable ?  !configuration.spellCheckingDisabled :false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = CGSize(
            width: configuration.contentInsets.leading,
            height: configuration.contentInsets.top
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = CGSize(width: 0, height: 0)
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.applyStyle(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.isEditable = isEditable

        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.isEditable = isEditable
        textView.isAutomaticSpellingCorrectionEnabled = isEditable ? !configuration.autocorrectionDisabled : false
        textView.isContinuousSpellCheckingEnabled = isEditable ?  !configuration.spellCheckingDisabled : false
        textView.isGrammarCheckingEnabled = isEditable ?  !configuration.spellCheckingDisabled : false

        context.coordinator.preservingScrollPosition(in: scrollView) {
            context.coordinator.syncFromBinding {
                if textView.string != text {
                    textView.string = text
                }

                context.coordinator.applyBoundSelection(to: textView)
            }

            context.coordinator.applyStyle(to: textView)
            context.coordinator.syncFromBinding {
                context.coordinator.applyBoundSelection(to: textView)
            }
        }
        context.coordinator.applyBoundSelectionAfterLayout(to: textView, in: scrollView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var selectedRange: Range<String.Index>?
        var configuration: MarkdownEditorConfiguration
        var isEditable: Bool
        private var isApplyingStyle = false
        private var isApplyingBoundSelection = false
        private var selectionUpdateGeneration = 0
        private var scrollRestoreGeneration = 0
        private var lastStyledText: String?
        private var lastRevealedRanges: [NSRange] = []

        init(
            text: Binding<String>,
            selectedRange: Binding<Range<String.Index>?>,
            configuration: MarkdownEditorConfiguration,
            isEditable: Bool
        ) {
            self._text = text
            self._selectedRange = selectedRange
            self.configuration = configuration
            self.isEditable = isEditable
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if text != textView.string {
                text = textView.string
            }
            updateSelectedRange(from: textView.selectedRange(), in: textView.string)
            applyStyle(to: textView, force: true)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateSelectedRange(from: textView.selectedRange(), in: textView.string)
            applyStyle(to: textView)
        }

        func applyStyle(to textView: NSTextView, force: Bool = false) {
            guard !isApplyingStyle else { return }

            let selectedRanges = textView.selectedRanges
            let selectedRange = textView.selectedRange()
            let revealedRanges = isEditable
                ? activeRanges(in: textView.string, selectedRange: selectedRange)
                : []
            guard force || textView.string != lastStyledText || revealedRanges != lastRevealedRanges else {
                return
            }

            isApplyingStyle = true
            defer { isApplyingStyle = false }

            let temporaryAttributes = temporaryAttributes(in: textView)
            let attributed = MarkdownStyle.attributedString(
                for: textView.string,
                options: MarkdownStyleOptions(
                    bodyFontSize: configuration.bodyFontSize,
                    hideMarkers: configuration.hidesMarkdownMarkers,
                    revealedRanges: revealedRanges
                )
            )

            textView.textStorage?.setAttributedString(attributed)
            restoreTemporaryAttributes(temporaryAttributes, in: textView)
            textView.selectedRanges = selectedRanges
            textView.needsDisplay = true
            lastStyledText = textView.string
            lastRevealedRanges = revealedRanges
        }

        private func activeRanges(in text: String, selectedRange: NSRange) -> [NSRange] {
            MarkdownStyle.revealedRanges(for: text, selectedRange: selectedRange)
        }

        private func updateSelectedRange(from nsRange: NSRange, in text: String) {
            guard !isApplyingStyle, !isApplyingBoundSelection else { return }

            let range = Range(nsRange, in: text)
            guard selectedRange != range else { return }

            selectionUpdateGeneration += 1
            let generation = selectionUpdateGeneration
            let sourceText = text
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.selectionUpdateGeneration == generation,
                      self.text == sourceText,
                      self.selectedRange != range else {
                    return
                }
                self.selectedRange = range
            }
        }

        func syncFromBinding(_ updates: () -> Void) {
            selectionUpdateGeneration += 1
            isApplyingBoundSelection = true
            defer { isApplyingBoundSelection = false }
            updates()
        }

        func preservingScrollPosition(in scrollView: NSScrollView, _ updates: () -> Void) {
            let visibleOrigin = scrollView.contentView.bounds.origin
            let markdownTextView = scrollView.documentView as? MarkdownNSTextView
            markdownTextView?.beginSuppressingAutomaticScrolling()
            updates()
            restoreVisibleOriginRepeatedly(
                visibleOrigin,
                in: scrollView,
                endingSuppressionFor: markdownTextView
            )
        }

        func applyBoundSelection(to textView: NSTextView) {
            guard let selectedRange else {
                return
            }

            let nsRange = NSRange(selectedRange, in: text)
            guard NSMaxRange(nsRange) <= (textView.string as NSString).length else { return }
            if isEditable, textView.window?.firstResponder !== textView {
                textView.window?.makeFirstResponder(textView)
            }
            setSelectedRange(nsRange, in: textView)
        }

        func applyBoundSelectionAfterLayout(to textView: NSTextView, in scrollView: NSScrollView) {
            let visibleOrigin = scrollView.contentView.bounds.origin
            DispatchQueue.main.async { [weak self, weak textView, weak scrollView] in
                guard let self, let textView, let scrollView else { return }
                self.preservingScrollPosition(in: scrollView) {
                    self.syncFromBinding {
                        self.applyBoundSelection(to: textView)
                    }
                }
                if self.isEditable {
                    textView.window?.makeFirstResponder(textView)
                }
                self.restoreVisibleOrigin(visibleOrigin, in: scrollView)
            }
        }

        private func restoreVisibleOriginRepeatedly(
            _ visibleOrigin: CGPoint,
            in scrollView: NSScrollView,
            endingSuppressionFor textView: MarkdownNSTextView?
        ) {
            scrollRestoreGeneration += 1
            let generation = scrollRestoreGeneration
            restoreVisibleOrigin(visibleOrigin, in: scrollView)

            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self,
                      let scrollView,
                      self.scrollRestoreGeneration == generation else {
                    return
                }
                self.restoreVisibleOrigin(visibleOrigin, in: scrollView)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak scrollView, weak textView] in
                guard let self,
                      let scrollView,
                      self.scrollRestoreGeneration == generation else {
                    textView?.endSuppressingAutomaticScrolling()
                    return
                }
                self.restoreVisibleOrigin(visibleOrigin, in: scrollView)
                textView?.endSuppressingAutomaticScrolling()
            }
        }

        private func setSelectedRange(_ selectedRange: NSRange, in textView: NSTextView) {
            guard textView.selectedRange() != selectedRange else { return }

            let scrollView = textView.enclosingScrollView
            let visibleOrigin = scrollView?.contentView.bounds.origin
            if let markdownTextView = textView as? MarkdownNSTextView {
                markdownTextView.beginSuppressingAutomaticScrolling()
                textView.setSelectedRange(selectedRange)
                markdownTextView.endSuppressingAutomaticScrolling()
            } else {
                textView.setSelectedRange(selectedRange)
            }
            if let scrollView, let visibleOrigin {
                restoreVisibleOrigin(visibleOrigin, in: scrollView)
            }
        }

        private func restoreVisibleOrigin(_ visibleOrigin: CGPoint, in scrollView: NSScrollView) {
            let documentBounds = scrollView.documentView?.bounds ?? .zero
            let clipBounds = scrollView.contentView.bounds
            let maxX = max(0, documentBounds.width - clipBounds.width)
            let maxY = max(0, documentBounds.height - clipBounds.height)
            let restoredOrigin = CGPoint(
                x: min(max(visibleOrigin.x, 0), maxX),
                y: min(max(visibleOrigin.y, 0), maxY)
            )

            guard scrollView.contentView.bounds.origin != restoredOrigin else { return }
            if let textView = scrollView.documentView as? MarkdownNSTextView {
                textView.scrollToVisibleOriginWhileSuppressed(restoredOrigin)
            } else {
                scrollView.contentView.scroll(to: restoredOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        private func temporaryAttributes(in textView: NSTextView) -> [(attributes: [NSAttributedString.Key: Any], range: NSRange)] {
            guard let layoutManager = textView.layoutManager else { return [] }

            var result: [(attributes: [NSAttributedString.Key: Any], range: NSRange)] = []
            var location = 0
            let length = (textView.string as NSString).length

            while location < length {
                var effectiveRange = NSRange(location: 0, length: 0)
                let attributes = layoutManager.temporaryAttributes(
                    atCharacterIndex: location,
                    effectiveRange: &effectiveRange
                )

                if !attributes.isEmpty {
                    result.append((attributes, effectiveRange))
                }

                let nextLocation = effectiveRange.location + max(effectiveRange.length, 1)
                location = max(nextLocation, location + 1)
            }

            return result
        }

        private func restoreTemporaryAttributes(
            _ temporaryAttributes: [(attributes: [NSAttributedString.Key: Any], range: NSRange)],
            in textView: NSTextView
        ) {
            guard let layoutManager = textView.layoutManager else { return }
            let length = (textView.string as NSString).length

            for item in temporaryAttributes where NSMaxRange(item.range) <= length {
                layoutManager.addTemporaryAttributes(item.attributes, forCharacterRange: item.range)
            }
        }
    }
}

final class MarkdownNSTextView: NSTextView {
    private var automaticScrollingSuppressionCount = 0
    private var allowsSuppressedScrollChange = false

    private var suppressesSelectionScrolling: Bool {
        automaticScrollingSuppressionCount > 0
    }

    override func draw(_ dirtyRect: NSRect) {
        drawCodeBlockBackgrounds()
        super.draw(dirtyRect)
        drawBlockQuoteBars()
        drawHorizontalRules()
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard !suppressesSelectionScrolling else { return }
        super.scrollRangeToVisible(range)
    }

    override func scroll(_ clipView: NSClipView, to point: NSPoint) {
        guard !suppressesSelectionScrolling || allowsSuppressedScrollChange else { return }
        super.scroll(clipView, to: point)
    }

    func beginSuppressingAutomaticScrolling() {
        automaticScrollingSuppressionCount += 1
    }

    func endSuppressingAutomaticScrolling() {
        automaticScrollingSuppressionCount = max(0, automaticScrollingSuppressionCount - 1)
    }

    func scrollToVisibleOriginWhileSuppressed(_ visibleOrigin: CGPoint) {
        guard let scrollView = enclosingScrollView else { return }
        allowsSuppressedScrollChange = true
        scrollView.contentView.scroll(to: visibleOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        allowsSuppressedScrollChange = false
    }

    private func drawCodeBlockBackgrounds() {
        guard let layoutManager else { return }

        MarkdownStyle.codeBackgroundColor.setFill()

        for range in MarkdownStyle.fencedCodeBlockRanges(in: string) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            var blockRect = CGRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, _, _ in
                blockRect = blockRect.union(lineRect)
            }
            guard !blockRect.isNull else { continue }

            let origin = textContainerOrigin
            let x = origin.x
            let width = max(0, bounds.width - origin.x - textContainerInset.width)
            let rect = CGRect(
                x: x,
                y: origin.y + blockRect.minY - MarkdownStyle.codeBlockTopPadding,
                width: width,
                height: blockRect.height + MarkdownStyle.codeBlockTopPadding + MarkdownStyle.codeBlockBottomPadding
            )
            NSBezierPath(
                roundedRect: rect,
                xRadius: MarkdownStyle.codeBlockCornerRadius,
                yRadius: MarkdownStyle.codeBlockCornerRadius
            ).fill()
        }
    }

    private func drawHorizontalRules() {
        guard let layoutManager, let textContainer else { return }

        NSColor.separatorColor.setStroke()

        for range in MarkdownStyle.horizontalRuleRanges(in: string) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )

            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let origin = textContainerOrigin
            let y = origin.y + rect.midY
            let width = max(0, bounds.width - origin.x - textContainerInset.width)

            let path = NSBezierPath()
            path.lineWidth = 2
            path.move(to: CGPoint(x: origin.x, y: y))
            path.line(to: CGPoint(x: origin.x + width, y: y))
            path.stroke()
        }
    }

    private func drawBlockQuoteBars() {
        guard let layoutManager else { return }

        MarkdownStyle.blockQuoteBarColor.setFill()

        for range in MarkdownStyle.blockQuoteRanges(in: string) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            var quoteRect = CGRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, _, _ in
                quoteRect = quoteRect.union(lineRect)
            }
            guard !quoteRect.isNull else { continue }

            let origin = textContainerOrigin
            let rect = CGRect(
                x: origin.x ,
                y: origin.y - 4 + quoteRect.minY,
                width: MarkdownStyle.blockQuoteBarWidth,
                height: quoteRect.height
            )
            rect.fill()
        }
    }
}
#endif

#if os(iOS)
struct PlatformMarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: Range<String.Index>?
    let configuration: MarkdownEditorConfiguration
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selectedRange: $selectedRange,
            configuration: configuration,
            isEditable: isEditable
        )
    }

    func makeUIView(context: Context) -> MarkdownUITextView {
        let textView = MarkdownUITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsHorizontalScrollIndicator = false
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = configuration.autocorrectionDisabled ? .no : .default
        textView.spellCheckingType = configuration.spellCheckingDisabled ? .no : .default
        textView.textContainerInset = UIEdgeInsets(
            top: configuration.contentInsets.top,
            left: configuration.contentInsets.leading,
            bottom: configuration.contentInsets.bottom,
            right: configuration.contentInsets.trailing
        )
        textView.text = text
        context.coordinator.applyStyle(to: textView)

        return textView
    }

    func updateUIView(_ textView: MarkdownUITextView, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.isEditable = isEditable
        textView.isEditable = isEditable
        textView.autocorrectionType = configuration.autocorrectionDisabled ? .no : .default
        textView.spellCheckingType = configuration.spellCheckingDisabled ? .no : .default

        let needsTextSync = textView.text != text
        context.coordinator.preservingScrollPosition(in: textView) {
            context.coordinator.syncFromBinding {
                if needsTextSync {
                    textView.text = text
                    context.coordinator.applyBoundSelection(to: textView)
                }
            }

            context.coordinator.applyStyle(to: textView)
            context.coordinator.syncFromBinding {
                if needsTextSync {
                    context.coordinator.applyBoundSelection(to: textView)
                }
            }
        }
        if needsTextSync {
            context.coordinator.applyBoundSelectionAfterLayout(to: textView)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var selectedRange: Range<String.Index>?
        var configuration: MarkdownEditorConfiguration
        var isEditable: Bool
        private var isApplyingStyle = false
        private var isApplyingBoundSelection = false
        private var selectionUpdateGeneration = 0
        private var scrollRestoreGeneration = 0
        private var textChangeGeneration = 0
        private var lastStyledText: String?
        private var lastRevealedRanges: [NSRange] = []

        init(
            text: Binding<String>,
            selectedRange: Binding<Range<String.Index>?>,
            configuration: MarkdownEditorConfiguration,
            isEditable: Bool
        ) {
            self._text = text
            self._selectedRange = selectedRange
            self.configuration = configuration
            self.isEditable = isEditable
        }

        func textViewDidChange(_ textView: UITextView) {
            if text != textView.text {
                text = textView.text
            }

            textChangeGeneration += 1
            let generation = textChangeGeneration
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self,
                      let textView,
                      self.textChangeGeneration == generation else {
                    return
                }

                self.updateSelectedRange(from: textView.selectedRange, in: textView.text)
                self.applyStyle(to: textView, force: true)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelectedRange(from: textView.selectedRange, in: textView.text)
            applyStyle(to: textView)
        }

        func applyStyle(to textView: UITextView, force: Bool = false) {
            guard !isApplyingStyle else { return }

            let selectedRange = textView.selectedRange
            let revealedRanges = isEditable
                ? activeRanges(in: textView.text, selectedRange: selectedRange)
                : []
            guard force || textView.text != lastStyledText || revealedRanges != lastRevealedRanges else {
                return
            }

            isApplyingStyle = true
            defer { isApplyingStyle = false }

            let attributed = MarkdownStyle.attributedString(
                for: textView.text,
                options: MarkdownStyleOptions(
                    bodyFontSize: configuration.bodyFontSize,
                    hideMarkers: configuration.hidesMarkdownMarkers,
                    revealedRanges: revealedRanges
                )
            )

            preservingScrollPosition(in: textView) {
                textView.attributedText = attributed
                setSelectedRange(selectedRange, in: textView)
                (textView as? MarkdownUITextView)?.updateCodeBlockBackgrounds()
                (textView as? MarkdownUITextView)?.updateBlockQuoteBars()
                (textView as? MarkdownUITextView)?.updateHorizontalRules()
            }
            lastStyledText = textView.text
            lastRevealedRanges = revealedRanges
        }

        private func activeRanges(in text: String, selectedRange: NSRange) -> [NSRange] {
            MarkdownStyle.revealedRanges(for: text, selectedRange: selectedRange)
        }

        private func updateSelectedRange(from nsRange: NSRange, in text: String) {
            guard !isApplyingStyle, !isApplyingBoundSelection else { return }

            let range = Range(nsRange, in: text)
            guard selectedRange != range else { return }

            selectionUpdateGeneration += 1
            let generation = selectionUpdateGeneration
            let sourceText = text
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.selectionUpdateGeneration == generation,
                      self.text == sourceText,
                      self.selectedRange != range else {
                    return
                }
                self.selectedRange = range
            }
        }

        func syncFromBinding(_ updates: () -> Void) {
            selectionUpdateGeneration += 1
            isApplyingBoundSelection = true
            defer { isApplyingBoundSelection = false }
            updates()
        }

        func applyBoundSelection(to textView: UITextView) {
            guard let selectedRange else {
                return
            }

            let nsRange = NSRange(selectedRange, in: text)
            let nativeText = textView.text ?? ""
            guard NSMaxRange(nsRange) <= (nativeText as NSString).length else { return }
            setSelectedRange(nsRange, in: textView)
        }

        func applyBoundSelectionAfterLayout(to textView: UITextView) {
            let contentOffset = textView.contentOffset
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.preservingScrollPosition(in: textView) {
                    self.syncFromBinding {
                        self.applyBoundSelection(to: textView)
                    }
                }
                self.restoreContentOffset(contentOffset, in: textView)
            }
        }

        func preservingScrollPosition(in textView: UITextView, _ updates: () -> Void) {
            let contentOffset = textView.contentOffset
            let markdownTextView = textView as? MarkdownUITextView
            markdownTextView?.beginSuppressingAutomaticScrolling()
            updates()
            restoreContentOffsetRepeatedly(
                contentOffset,
                in: textView,
                endingSuppressionFor: markdownTextView
            )
        }

        private func restoreContentOffsetRepeatedly(
            _ contentOffset: CGPoint,
            in textView: UITextView,
            endingSuppressionFor markdownTextView: MarkdownUITextView?
        ) {
            scrollRestoreGeneration += 1
            let generation = scrollRestoreGeneration
            restoreContentOffset(contentOffset, in: textView)

            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self,
                      let textView,
                      self.scrollRestoreGeneration == generation else {
                    return
                }
                self.restoreContentOffset(contentOffset, in: textView)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak textView, weak markdownTextView] in
                guard let self,
                      let textView,
                      self.scrollRestoreGeneration == generation else {
                    markdownTextView?.endSuppressingAutomaticScrolling()
                    return
                }
                self.restoreContentOffset(contentOffset, in: textView)
                markdownTextView?.endSuppressingAutomaticScrolling()
            }
        }

        private func setSelectedRange(_ selectedRange: NSRange, in textView: UITextView) {
            guard textView.selectedRange != selectedRange else { return }

            let contentOffset = textView.contentOffset
            if let markdownTextView = textView as? MarkdownUITextView {
                markdownTextView.beginSuppressingAutomaticScrolling()
                textView.selectedRange = selectedRange
                markdownTextView.endSuppressingAutomaticScrolling()
            } else {
                textView.selectedRange = selectedRange
            }
            restoreContentOffset(contentOffset, in: textView)
        }

        private func restoreContentOffset(_ contentOffset: CGPoint, in textView: UITextView) {
            let adjustedInset = textView.adjustedContentInset
            let minX = -adjustedInset.left
            let minY = -adjustedInset.top
            let maxX = max(minX, textView.contentSize.width - textView.bounds.width + adjustedInset.right)
            let maxY = max(minY, textView.contentSize.height - textView.bounds.height + adjustedInset.bottom)
            let restoredOffset = CGPoint(
                x: min(max(contentOffset.x, minX), maxX),
                y: min(max(contentOffset.y, minY), maxY)
            )

            guard textView.contentOffset != restoredOffset else { return }
            if let markdownTextView = textView as? MarkdownUITextView {
                markdownTextView.setContentOffsetWhileSuppressed(restoredOffset)
            } else {
                textView.setContentOffset(restoredOffset, animated: false)
            }
        }
    }
}

final class MarkdownUITextView: UITextView {
    private let horizontalRuleLayerName = "MarkdownEngineLiteHorizontalRule"
    private let codeBlockLayerName = "MarkdownEngineLiteCodeBlock"
    private let blockQuoteLayerName = "MarkdownEngineLiteBlockQuote"
    private var automaticScrollingSuppressionCount = 0
    private var allowsSuppressedContentOffsetChange = false

    var suppressesSelectionScrolling: Bool {
        automaticScrollingSuppressionCount > 0
    }

    override var text: String! {
        didSet { setNeedsLayout() }
    }

    override var attributedText: NSAttributedString! {
        didSet { setNeedsLayout() }
    }

    override var contentOffset: CGPoint {
        didSet {
            updateBlockQuoteBars()
            updateHorizontalRules()
        }
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard !suppressesSelectionScrolling else { return }
        super.scrollRangeToVisible(range)
    }

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        guard !suppressesSelectionScrolling || allowsSuppressedContentOffsetChange else { return }
        super.setContentOffset(contentOffset, animated: animated)
    }

    func beginSuppressingAutomaticScrolling() {
        automaticScrollingSuppressionCount += 1
    }

    func endSuppressingAutomaticScrolling() {
        automaticScrollingSuppressionCount = max(0, automaticScrollingSuppressionCount - 1)
    }

    func setContentOffsetWhileSuppressed(_ contentOffset: CGPoint) {
        allowsSuppressedContentOffsetChange = true
        setContentOffset(contentOffset, animated: false)
        allowsSuppressedContentOffsetChange = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCodeBlockBackgrounds()
        updateBlockQuoteBars()
        updateHorizontalRules()
    }

    func updateCodeBlockBackgrounds() {
        layer.sublayers?
            .filter { $0.name == codeBlockLayerName }
            .forEach { $0.removeFromSuperlayer() }

        let text = self.text ?? ""
        guard !text.isEmpty else { return }

        layoutManager.ensureLayout(for: textContainer)

        let width = max(0, bounds.width - textContainerInset.left - textContainerInset.right)
        guard width > 0 else { return }

        for range in MarkdownStyle.fencedCodeBlockRanges(in: text) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            var blockRect = CGRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, _, _ in
                blockRect = blockRect.union(lineRect)
            }
            guard !blockRect.isNull else { continue }

            let backgroundLayer = CALayer()
            backgroundLayer.name = codeBlockLayerName
            backgroundLayer.backgroundColor = MarkdownStyle.codeBackgroundColor.cgColor
            backgroundLayer.cornerRadius = MarkdownStyle.codeBlockCornerRadius
            backgroundLayer.masksToBounds = true
            backgroundLayer.frame = CGRect(
                x: textContainerInset.left,
                y: textContainerInset.top + blockRect.minY - MarkdownStyle.codeBlockTopPadding,
                width: width,
                height: blockRect.height + MarkdownStyle.codeBlockTopPadding + MarkdownStyle.codeBlockBottomPadding
            )
            layer.insertSublayer(backgroundLayer, at: 0)
        }
    }

    func updateBlockQuoteBars() {
        layer.sublayers?
            .filter { $0.name == blockQuoteLayerName }
            .forEach { $0.removeFromSuperlayer() }

        let text = self.text ?? ""
        guard !text.isEmpty else { return }

        layoutManager.ensureLayout(for: textContainer)

        for range in MarkdownStyle.blockQuoteRanges(in: text) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            var quoteRect = CGRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, _, _ in
                quoteRect = quoteRect.union(lineRect)
            }
            guard !quoteRect.isNull else { continue }

            let barLayer = CALayer()
            barLayer.name = blockQuoteLayerName
            barLayer.backgroundColor = MarkdownStyle.blockQuoteBarColor.cgColor
            barLayer.cornerRadius = MarkdownStyle.blockQuoteBarWidth / 2
            barLayer.frame = CGRect(
                x: textContainerInset.left,
                y: textContainerInset.top + quoteRect.minY,
                width: MarkdownStyle.blockQuoteBarWidth,
                height: quoteRect.height
            )
            layer.addSublayer(barLayer)
        }
    }

    func updateHorizontalRules() {
        layer.sublayers?
            .filter { $0.name == horizontalRuleLayerName }
            .forEach { $0.removeFromSuperlayer() }

        let text = self.text ?? ""
        guard !text.isEmpty else { return }

        layoutManager.ensureLayout(for: textContainer)

        let scale = max(window?.windowScene?.screen.scale ?? traitCollection.displayScale, 1)
        let lineHeight = 5 / scale
        let width = max(0, bounds.width - textContainerInset.left - textContainerInset.right)
        guard width > 0 else { return }

        for range in MarkdownStyle.horizontalRuleRanges(in: text) {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )

            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let x = textContainerInset.left
            let y = textContainerInset.top + rect.midY - lineHeight / 2
            let visibleY = y - contentOffset.y
            guard visibleY >= -lineHeight, visibleY <= bounds.height + lineHeight else { continue }

            let ruleLayer = CALayer()
            ruleLayer.name = horizontalRuleLayerName
            ruleLayer.backgroundColor = UIColor.separator.cgColor
            ruleLayer.frame = CGRect(x: x, y: y, width: width, height: lineHeight)
            layer.addSublayer(ruleLayer)
        }
    }
}
#endif




struct CustomButtonLabel : View {
    
    let text : String
    let image : String
    let editorToolbarButtonSize: CGFloat
    var small : Bool = false
    
    let action : () -> Void

    private var buttonSize: (CGFloat, CGFloat)  {
        return (editorToolbarButtonSize * (small ? 0.8 : 1), (editorToolbarButtonSize + 10) * (small ? 0.8 : 1))
    }
    
    var body: some View {
        Button {
            action()
        }
        label :{
            Image(image, bundle: MarkdownEngineLiteResources.bundle)
                .resizable()
                .scaledToFit()
                .frame(width: buttonSize.0, height: buttonSize.0)
                .frame(width: buttonSize.1, height: buttonSize.1)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.25))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(Text(text))
    }
    
}
