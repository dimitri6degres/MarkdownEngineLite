import SwiftUI
import UniformTypeIdentifiers

private func safeNSRange(_ range: Range<String.Index>, in text: String) -> NSRange? {
    guard let lowerBound = range.lowerBound.samePosition(in: text.utf16),
          let upperBound = range.upperBound.samePosition(in: text.utf16) else {
        return nil
    }

    let location = text.utf16.distance(from: text.utf16.startIndex, to: lowerBound)
    let upperLocation = text.utf16.distance(from: text.utf16.startIndex, to: upperBound)
    guard location <= upperLocation else {
        return nil
    }

    return NSRange(location: location, length: upperLocation - location)
}

private struct RenderedMarkdownImage {
    let range: NSRange
    let frame: CGRect
}

struct LiveMarkdownTextEditor: View {
    let title: String
    @Binding var text: String
    @Binding var mode: MarkdownEditorMode
    @Binding var selectedRange: Range<String.Index>?

    let placeholder: String
    let configuration: MarkdownEditorConfiguration

    private var isEditable: Bool {
        mode == .edit
    }

    private var selectedImageRange: NSRange? {
        MarkdownTextEditing.imageRange(containing: selectedRange, in: text)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
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
            
            
            if configuration.showsEditorToolbar && isEditable {
                
                VStack(alignment: .center, spacing: configuration.editorToolbarButtonSize) {
                    
                    CustomButtonLabel(text: "Bold",
                                      image: "bold",
                                      size: configuration.editorToolbarButtonSize) {
                        selectedRange = MarkdownTextEditing.makeBold(
                            in: &text,
                            selectedRange: selectedRange
                        )
                    }
                    
                    CustomButtonLabel(text: "Italic",
                                      image: "italic",
                                      size: configuration.editorToolbarButtonSize) {
                        selectedRange = MarkdownTextEditing.makeItalic(
                            in: &text,
                            selectedRange: selectedRange
                        )
                    }
                    
                    CustomButtonLabel(text: "Header",
                                      image: "header",
                                      size: configuration.editorToolbarButtonSize) {
                        selectedRange = MarkdownTextEditing.applyHeading(
                            in: &text,
                            selectedRange: selectedRange
                        )
                    }

                    CustomButtonLabel(text: "Separator",
                                      image: "separator",
                                      size: configuration.editorToolbarButtonSize) {
                        selectedRange = MarkdownTextEditing.insertSeparator(
                            in: &text,
                            selectedRange: selectedRange
                        )
                    }
                    
                    CustomButtonLabel(text: "Quotes",
                                      image: "quotes",
                                      size: configuration.editorToolbarButtonSize) {
                        selectedRange = MarkdownTextEditing.toggleBlockQuote(
                            in: &text,
                            selectedRange: selectedRange
                        )
                    }
                    
                    CustomButtonLabel(text: "Block",
                                      image: "block",
                                      size: configuration.editorToolbarButtonSize) {
                        selectedRange = MarkdownTextEditing.toggleCodeBlock(
                            in: &text,
                            selectedRange: selectedRange
                        )
                    }
                    
//                    Menu {
//                        Button("Auto") { setSelectedImageWidth(0) }
//                        Button("25%") { setSelectedImageWidth(25) }
//                        Button("50%") { setSelectedImageWidth(50) }
//                        Button("75%") { setSelectedImageWidth(75) }
//                        Button("100%") { setSelectedImageWidth(100) }
//                    }
//                    label: {
//                        
//                        CustomButtonLabel(text: "Image size",
//                                          image: "size",
//                                          size: configuration.editorToolbarButtonSize) {
//                            selectedRange = MarkdownTextEditing.toggleCodeBlock(
//                                in: &text,
//                                selectedRange: selectedRange
//                            )
//                        }
//                    }
//                    .opacity(selectedImageRange != nil ? 1 : 0.35)
//                    .disabled(selectedImageRange == nil)
                    
                    ImageWidthMenu(
                        size: configuration.editorToolbarButtonSize,
                        isEnabled: selectedImageRange != nil
                    ) { percent in
                        setSelectedImageWidth(percent)
                    }
                }
                .padding(.vertical, configuration.editorToolbarButtonSize / 2)
                .padding(.horizontal, configuration.editorToolbarButtonSize / 4)
                .background(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .cornerRadius(10)
                )
                .contentShape(Rectangle())
                
                
                .padding(10)
            }
            
        }
    }

    private func setSelectedImageWidth(_ percent: CGFloat) {
        guard let imageRange = selectedImageRange else { return }
        selectedRange = MarkdownTextEditing.setImageWidth(
            in: &text,
            imageRange: imageRange,
            percent: percent
        )
    }

    private struct CustomButtonLabel : View {
        
        let text : String
        let image : String
        let size : CGFloat
        
        let action : () -> Void

        
        var body: some View {
            Button {
                action()
            }
            label :{
                Image(image, bundle: MarkdownEngineLiteResources.bundle)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .accessibilityLabel(Text(text))
        }
        
    }

    private struct ImageWidthMenu: View {
        let size: CGFloat
        let isEnabled: Bool
        let action: (CGFloat) -> Void

        var body: some View {
            Menu {
                Button("Auto") { action(0) }
                Button("25%") { action(25) }
                Button("50%") { action(50) }
                Button("75%") { action(75) }
                Button("100%") { action(100) }
            } label: {
                
                Image("size", bundle: MarkdownEngineLiteResources.bundle)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .contentShape(Rectangle())
                
//                Image(systemName: "photo")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: size, height: size)
//                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .opacity(isEnabled ? 1 : 0.35)
            .disabled(!isEnabled)
            .accessibilityLabel(Text("Image size"))
        }
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
        textView.isMarkdownEditingEnabled = isEditable
        textView.onImageWidthChange = { [weak coordinator = context.coordinator] range, percent in
            coordinator?.setImageWidth(range: range, percent: percent)
        }
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
        (textView as? MarkdownNSTextView)?.isMarkdownEditingEnabled = isEditable
        (textView as? MarkdownNSTextView)?.onImageWidthChange = { [weak coordinator = context.coordinator] range, percent in
            coordinator?.setImageWidth(range: range, percent: percent)
        }
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
        private var lastNativeSelectedRange: NSRange?
        private var nativeSelectionText: String?
        private var lastImageMaxWidth: CGFloat = 0

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
            lastNativeSelectedRange = textView.selectedRange()
            nativeSelectionText = textView.string
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

        func setImageWidth(range: NSRange, percent: CGFloat) {
            var updatedText = text
            guard let updatedRange = MarkdownTextEditing.setImageWidth(
                in: &updatedText,
                imageRange: range,
                percent: percent
            ) else {
                return
            }

            text = updatedText
            selectedRange = updatedRange
        }

        func applyStyle(to textView: NSTextView, force: Bool = false) {
            guard !isApplyingStyle else { return }

            let selectedRanges = textView.selectedRanges
            let selectedRange = textView.selectedRange()
            let revealedRanges = isEditable
                ? activeRanges(in: textView.string, selectedRange: selectedRange)
                : []
            let imageMaxWidth = self.imageMaxWidth(in: textView)
            let hiddenImageRanges = MarkdownStyle.imageReferences(in: textView.string)
                .map(\.range)
                .filter { imageRange in
                    !revealedRanges.contains {
                        NSIntersectionRange(imageRange, $0).length > 0
                    }
                }
            guard force
                    || textView.string != lastStyledText
                    || revealedRanges != lastRevealedRanges
                    || imageMaxWidth != lastImageMaxWidth else {
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
                    revealedRanges: revealedRanges,
                    imageMaxWidth: imageMaxWidth,
                    imageDataProvider: configuration.imageDataProvider
                )
            )

            if let markdownTextView = textView as? MarkdownNSTextView {
                markdownTextView.imageDataProvider = configuration.imageDataProvider
                markdownTextView.imageMaxWidth = imageMaxWidth
                markdownTextView.imageRevealedRanges = revealedRanges
            }
            textView.textStorage?.setAttributedString(attributed)
            restoreTemporaryAttributes(
                temporaryAttributes,
                in: textView,
                excluding: hiddenImageRanges
            )
            textView.selectedRanges = selectedRanges
            textView.needsDisplay = true
            lastStyledText = textView.string
            lastRevealedRanges = revealedRanges
            lastImageMaxWidth = imageMaxWidth
        }

        private func imageMaxWidth(in textView: NSTextView) -> CGFloat {
            let origin = textView.textContainerOrigin
            return max(0, textView.bounds.width - origin.x - textView.textContainerInset.width)
        }

        private func activeRanges(in text: String, selectedRange: NSRange) -> [NSRange] {
            MarkdownStyle.revealedRanges(for: text, selectedRange: selectedRange)
        }

        private func updateSelectedRange(from nsRange: NSRange, in text: String) {
            guard !isApplyingStyle, !isApplyingBoundSelection else { return }

            lastNativeSelectedRange = nsRange
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

            let textLength = (textView.string as NSString).length
            let nsRange: NSRange
            if nativeSelectionText == text,
               let lastNativeSelectedRange,
               NSMaxRange(lastNativeSelectedRange) <= textLength {
                nsRange = lastNativeSelectedRange
            } else {
                nsRange = safeNSRange(selectedRange, in: text)
                    ?? lastNativeSelectedRange
                    ?? NSRange(location: textLength, length: 0)
            }
            guard NSMaxRange(nsRange) <= textLength else { return }
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
            in textView: NSTextView,
            excluding excludedRanges: [NSRange] = []
        ) {
            guard let layoutManager = textView.layoutManager else { return }
            let length = (textView.string as NSString).length

            for item in temporaryAttributes where NSMaxRange(item.range) <= length {
                guard !excludedRanges.contains(where: { NSIntersectionRange(item.range, $0).length > 0 }) else {
                    continue
                }
                layoutManager.addTemporaryAttributes(item.attributes, forCharacterRange: item.range)
            }
        }
    }
}

final class MarkdownNSTextView: NSTextView {
    private var automaticScrollingSuppressionCount = 0
    private var allowsSuppressedScrollChange = false
    private var renderedImageTargets: [RenderedMarkdownImage] = []
    private var imageWidthPalette: NSStackView?
    private var activeImageRange: NSRange?
    var imageDataProvider: ((String) -> Data?)?
    var imageMaxWidth: CGFloat = 0
    var imageRevealedRanges: [NSRange] = []
    var isMarkdownEditingEnabled = true {
        didSet {
            if !isMarkdownEditingEnabled {
                hideImageWidthPalette()
            }
        }
    }
    var onImageWidthChange: ((NSRange, CGFloat) -> Void)?

    private var suppressesSelectionScrolling: Bool {
        automaticScrollingSuppressionCount > 0
    }

    override func draw(_ dirtyRect: NSRect) {
        drawCodeBlockBackgrounds()
        super.draw(dirtyRect)
        drawRenderedImages()
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

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if isMarkdownEditingEnabled,
           let target = renderedImageTargets.first(where: { $0.frame.contains(location) }) {
            showImageWidthPalette(for: target)
            return
        }

        hideImageWidthPalette()
        super.mouseDown(with: event)
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

    private func drawRenderedImages() {
        guard let layoutManager else { return }
        renderedImageTargets = []

        let options = MarkdownStyleOptions(
            bodyFontSize: 0,
            hideMarkers: true,
            revealedRanges: imageRevealedRanges,
            imageMaxWidth: imageMaxWidth,
            imageDataProvider: imageDataProvider
        )

        let source = string as NSString
        var imageOffsetsByParagraph: [String: CGFloat] = [:]

        for reference in MarkdownStyle.imageReferences(in: string) {
            guard !imageRevealedRanges.contains(where: { NSIntersectionRange(reference.range, $0).length > 0 }),
                  let data = imageDataProvider?(reference.path),
                  let image = NSImage(data: data),
                  let size = MarkdownStyle.resolvedImageSize(
                    for: reference.path,
                    widthPercent: reference.widthPercent,
                    options: options
                  ) else {
                continue
            }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: reference.range,
                actualCharacterRange: nil
            )
            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            let origin = textContainerOrigin
            let paragraphRange = source.paragraphRange(for: reference.range)
            let paragraphKey = "\(paragraphRange.location)-\(paragraphRange.length)"
            let xOffset = imageOffsetsByParagraph[paragraphKey, default: 0]
            let rect = CGRect(
                x: origin.x + xOffset,
                y: origin.y + lineRect.minY + MarkdownStyle.imageVerticalPadding,
                width: size.width,
                height: size.height
            )
            imageOffsetsByParagraph[paragraphKey] = xOffset + size.width
            image.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
            renderedImageTargets.append(RenderedMarkdownImage(range: reference.range, frame: rect))
        }

        updateImageWidthPalettePosition()
    }

    private func showImageWidthPalette(for target: RenderedMarkdownImage) {
        activeImageRange = target.range
        let palette = imageWidthPalette ?? makeImageWidthPalette()
        if palette.superview == nil {
            addSubview(palette)
        }
        imageWidthPalette = palette
        position(palette, near: target.frame)
        keepImageWidthPaletteInFront()
    }

    private func hideImageWidthPalette() {
        activeImageRange = nil
        imageWidthPalette?.removeFromSuperview()
    }

    private func updateImageWidthPalettePosition() {
        guard let activeImageRange,
              let palette = imageWidthPalette,
              let target = renderedImageTargets.first(where: { $0.range == activeImageRange }) else {
            hideImageWidthPalette()
            return
        }

        position(palette, near: target.frame)
        keepImageWidthPaletteInFront()
    }

    private func makeImageWidthPalette() -> NSStackView {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        stackView.wantsLayer = true
        stackView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94).cgColor
        stackView.layer?.cornerRadius = 8
        stackView.layer?.borderColor = NSColor.separatorColor.cgColor
        stackView.layer?.borderWidth = 1
        stackView.layer?.zPosition = 10_000

        for option in [(title: "Auto", percent: 0), (title: "25%", percent: 25), (title: "50%", percent: 50), (title: "75%", percent: 75), (title: "100%", percent: 100)] {
            let button = NSButton(title: option.title, target: self, action: #selector(changeImageWidth(_:)))
            button.tag = option.percent
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 11, weight: .medium)
            stackView.addArrangedSubview(button)
        }

        return stackView
    }

    private func position(_ palette: NSView, near imageFrame: CGRect) {
        palette.layoutSubtreeIfNeeded()
        let fittingSize = palette.fittingSize
        let centeredX = imageFrame.midX - fittingSize.width / 2
        let x = min(
            max(centeredX, bounds.minX),
            max(bounds.maxX - fittingSize.width, bounds.minX)
        )
        let centeredY = imageFrame.midY - fittingSize.height / 2
        let y = min(
            max(centeredY, bounds.minY),
            max(bounds.maxY - fittingSize.height, bounds.minY)
        )
        palette.frame = CGRect(origin: CGPoint(x: x, y: y), size: fittingSize)
    }

    private func keepImageWidthPaletteInFront() {
        guard let imageWidthPalette else { return }
        addSubview(imageWidthPalette, positioned: .above, relativeTo: nil)
        imageWidthPalette.layer?.zPosition = 10_000
    }

    @objc private func changeImageWidth(_ sender: NSButton) {
        guard let activeImageRange else { return }
        onImageWidthChange?(activeImageRange, CGFloat(sender.tag))
        hideImageWidthPalette()
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
        textView.isMarkdownEditingEnabled = isEditable
        textView.onImageWidthChange = { [weak coordinator = context.coordinator] range, percent in
            coordinator?.setImageWidth(range: range, percent: percent)
        }
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
        textView.isMarkdownEditingEnabled = isEditable
        textView.onImageWidthChange = { [weak coordinator = context.coordinator] range, percent in
            coordinator?.setImageWidth(range: range, percent: percent)
        }
        textView.isEditable = isEditable
        textView.autocorrectionType = configuration.autocorrectionDisabled ? .no : .default
        textView.spellCheckingType = configuration.spellCheckingDisabled ? .no : .default

        if textView.text != text {
            context.coordinator.preservingScrollPosition(in: textView) {
                context.coordinator.syncFromBinding {
                    textView.text = text
                    context.coordinator.applyBoundSelection(to: textView)
                }

                context.coordinator.applyStyle(to: textView)
                context.coordinator.syncFromBinding {
                    context.coordinator.applyBoundSelection(to: textView)
                }
            }
            context.coordinator.applyBoundSelectionAfterLayout(to: textView)
        } else {
            context.coordinator.applyStyle(to: textView)
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
        private var lastNativeSelectedRange: NSRange?
        private var nativeSelectionText: String?
        private var lastImageMaxWidth: CGFloat = 0

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
            lastNativeSelectedRange = textView.selectedRange
            nativeSelectionText = textView.text
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
                self.applyStyle(to: textView, force: true, preservesScrollRepeatedly: false)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelectedRange(from: textView.selectedRange, in: textView.text)
            applyStyle(to: textView, preservesScrollRepeatedly: false)
        }

        func setImageWidth(range: NSRange, percent: CGFloat) {
            var updatedText = text
            guard let updatedRange = MarkdownTextEditing.setImageWidth(
                in: &updatedText,
                imageRange: range,
                percent: percent
            ) else {
                return
            }

            text = updatedText
            selectedRange = updatedRange
        }

        func applyStyle(
            to textView: UITextView,
            force: Bool = false,
            preservesScrollRepeatedly: Bool = true
        ) {
            guard !isApplyingStyle else { return }

            let selectedRange = textView.selectedRange
            let revealedRanges = isEditable
                ? activeRanges(in: textView.text, selectedRange: selectedRange)
                : []
            let imageMaxWidth = self.imageMaxWidth(in: textView)
            guard force
                    || textView.text != lastStyledText
                    || revealedRanges != lastRevealedRanges
                    || imageMaxWidth != lastImageMaxWidth else {
                return
            }

            isApplyingStyle = true
            defer { isApplyingStyle = false }

            let attributed = MarkdownStyle.attributedString(
                for: textView.text,
                options: MarkdownStyleOptions(
                    bodyFontSize: configuration.bodyFontSize,
                    hideMarkers: configuration.hidesMarkdownMarkers,
                    revealedRanges: revealedRanges,
                    imageMaxWidth: imageMaxWidth,
                    imageDataProvider: configuration.imageDataProvider
                )
            )

            if let markdownTextView = textView as? MarkdownUITextView {
                markdownTextView.imageDataProvider = configuration.imageDataProvider
                markdownTextView.imageMaxWidth = imageMaxWidth
                markdownTextView.imageRevealedRanges = revealedRanges
            }
            let applyAttributedText = {
                textView.textStorage.setAttributedString(attributed)
                self.setSelectedRange(selectedRange, in: textView)
                let markdownTextView = textView as? MarkdownUITextView
                markdownTextView?.updateCodeBlockBackgrounds()
                markdownTextView?.updateRenderedImages()
                markdownTextView?.updateBlockQuoteBars()
                markdownTextView?.updateHorizontalRules()
            }

            if preservesScrollRepeatedly {
                preservingScrollPosition(in: textView, applyAttributedText)
            } else {
                let contentOffset = textView.contentOffset
                let markdownTextView = textView as? MarkdownUITextView
                markdownTextView?.beginSuppressingAutomaticScrolling()
                applyAttributedText()
                markdownTextView?.endSuppressingAutomaticScrolling()
                restoreContentOffset(contentOffset, in: textView)
            }
            lastStyledText = textView.text
            lastRevealedRanges = revealedRanges
            lastImageMaxWidth = imageMaxWidth
        }

        private func imageMaxWidth(in textView: UITextView) -> CGFloat {
            max(0, textView.bounds.width - textView.textContainerInset.left - textView.textContainerInset.right)
        }

        private func activeRanges(in text: String, selectedRange: NSRange) -> [NSRange] {
            MarkdownStyle.revealedRanges(for: text, selectedRange: selectedRange)
        }

        private func updateSelectedRange(from nsRange: NSRange, in text: String) {
            guard !isApplyingStyle, !isApplyingBoundSelection else { return }

            lastNativeSelectedRange = nsRange
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

            let nativeText = textView.text ?? ""
            let textLength = (nativeText as NSString).length
            let nsRange: NSRange
            if nativeSelectionText == text,
               let lastNativeSelectedRange,
               NSMaxRange(lastNativeSelectedRange) <= textLength {
                nsRange = lastNativeSelectedRange
            } else {
                nsRange = safeNSRange(selectedRange, in: text)
                    ?? lastNativeSelectedRange
                    ?? NSRange(location: textLength, length: 0)
            }
            guard NSMaxRange(nsRange) <= textLength else { return }
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
    private let imageLayerName = "MarkdownEngineLiteImage"
    private var automaticScrollingSuppressionCount = 0
    private var renderedImageTargets: [RenderedMarkdownImage] = []
    private var imageWidthPalette: UIStackView?
    private var activeImageRange: NSRange?
    var imageDataProvider: ((String) -> Data?)?
    var imageMaxWidth: CGFloat = 0
    var imageRevealedRanges: [NSRange] = []
    var isMarkdownEditingEnabled = true {
        didSet {
            if !isMarkdownEditingEnabled {
                hideImageWidthPalette()
            }
        }
    }
    var onImageWidthChange: ((NSRange, CGFloat) -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var suppressesSelectionScrolling: Bool {
        automaticScrollingSuppressionCount > 0
    }

    override var text: String! {
        didSet { setNeedsLayout() }
    }

    override var attributedText: NSAttributedString! {
        didSet { setNeedsLayout() }
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard !suppressesSelectionScrolling else { return }
        super.scrollRangeToVisible(range)
    }

    func beginSuppressingAutomaticScrolling() {
        automaticScrollingSuppressionCount += 1
    }

    func endSuppressingAutomaticScrolling() {
        automaticScrollingSuppressionCount = max(0, automaticScrollingSuppressionCount - 1)
    }

    func setContentOffsetWhileSuppressed(_ contentOffset: CGPoint) {
        setContentOffset(contentOffset, animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCodeBlockBackgrounds()
        updateRenderedImages()
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

    func updateRenderedImages() {
        layer.sublayers?
            .filter { $0.name == imageLayerName }
            .forEach { $0.removeFromSuperlayer() }
        renderedImageTargets = []

        let text = self.text ?? ""
        guard !text.isEmpty else { return }

        layoutManager.ensureLayout(for: textContainer)

        let options = MarkdownStyleOptions(
            bodyFontSize: 0,
            hideMarkers: true,
            revealedRanges: imageRevealedRanges,
            imageMaxWidth: imageMaxWidth,
            imageDataProvider: imageDataProvider
        )

        let source = text as NSString
        var imageOffsetsByParagraph: [String: CGFloat] = [:]

        for reference in MarkdownStyle.imageReferences(in: text) {
            guard !imageRevealedRanges.contains(where: { NSIntersectionRange(reference.range, $0).length > 0 }),
                  let data = imageDataProvider?(reference.path),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage,
                  let size = MarkdownStyle.resolvedImageSize(
                    for: reference.path,
                    widthPercent: reference.widthPercent,
                    options: options
                  ) else {
                continue
            }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: reference.range,
                actualCharacterRange: nil
            )
            guard glyphRange.location != NSNotFound, glyphRange.length > 0 else { continue }

            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            let paragraphRange = source.paragraphRange(for: reference.range)
            let paragraphKey = "\(paragraphRange.location)-\(paragraphRange.length)"
            let xOffset = imageOffsetsByParagraph[paragraphKey, default: 0]
            let frame = CGRect(
                x: textContainerInset.left + xOffset,
                y: textContainerInset.top + lineRect.minY + MarkdownStyle.imageVerticalPadding,
                width: size.width,
                height: size.height
            )
            imageOffsetsByParagraph[paragraphKey] = xOffset + size.width

            let imageLayer = CALayer()
            imageLayer.name = imageLayerName
            imageLayer.contents = cgImage
            imageLayer.contentsScale = image.scale
            imageLayer.contentsGravity = .resizeAspect
            imageLayer.frame = frame
            layer.addSublayer(imageLayer)
            renderedImageTargets.append(RenderedMarkdownImage(range: reference.range, frame: frame))
        }

        updateImageWidthPalettePosition()
    }

    private func showImageWidthPalette(for target: RenderedMarkdownImage) {
        activeImageRange = target.range
        let palette = imageWidthPalette ?? makeImageWidthPalette()
        if palette.superview == nil {
            addSubview(palette)
        }
        imageWidthPalette = palette
        position(palette, near: target.frame)
    }

    private func hideImageWidthPalette() {
        activeImageRange = nil
        imageWidthPalette?.removeFromSuperview()
    }

    private func updateImageWidthPalettePosition() {
        guard let activeImageRange,
              let palette = imageWidthPalette,
              let target = renderedImageTargets.first(where: { $0.range == activeImageRange }) else {
            hideImageWidthPalette()
            return
        }

        position(palette, near: target.frame)
    }

    private func makeImageWidthPalette() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.layoutMargins = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.94)
        stackView.layer.cornerRadius = 8
        stackView.layer.borderColor = UIColor.separator.cgColor
        stackView.layer.borderWidth = 1
        stackView.layer.zPosition = 10_000

        for option in [(title: "Auto", percent: 0), (title: "25%", percent: 25), (title: "50%", percent: 50), (title: "75%", percent: 75), (title: "100%", percent: 100)] {
            let button = UIButton(type: .system)
            button.tag = option.percent
            button.setTitle(option.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
            button.addTarget(self, action: #selector(changeImageWidth(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }

        return stackView
    }

    private func position(_ palette: UIView, near imageFrame: CGRect) {
        let fittingSize = palette.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let centeredX = imageFrame.midX - fittingSize.width / 2
        let x = min(
            max(centeredX, bounds.minX),
            max(bounds.maxX - fittingSize.width, bounds.minX)
        )
        let centeredY = imageFrame.midY - fittingSize.height / 2
        let y = min(
            max(centeredY, bounds.minY),
            max(bounds.maxY - fittingSize.height, bounds.minY)
        )
        palette.frame = CGRect(origin: CGPoint(x: x, y: y), size: fittingSize)
    }

    private func keepImageWidthPaletteInFront() {
        guard let imageWidthPalette else { return }
        bringSubviewToFront(imageWidthPalette)
        imageWidthPalette.layer.zPosition = 10_000
    }

    @objc private func changeImageWidth(_ sender: UIButton) {
        guard let activeImageRange else { return }
        onImageWidthChange?(activeImageRange, CGFloat(sender.tag))
        hideImageWidthPalette()
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

            let ruleLayer = CALayer()
            ruleLayer.name = horizontalRuleLayerName
            ruleLayer.backgroundColor = UIColor.separator.cgColor
            ruleLayer.frame = CGRect(x: x, y: y, width: width, height: lineHeight)
            layer.addSublayer(ruleLayer)
        }
    }
}
#endif
