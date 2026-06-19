import XCTest
@testable import MarkdownEngineLite

#if os(macOS)
import AppKit
#endif

final class MarkdownRendererTests: XCTestCase {
    func testRendersBasicMarkdown() {
        let rendered = MarkdownRenderer.render("# Title\n\nHello, **world**.")

        XCTAssertFalse(rendered.characters.isEmpty)
        XCTAssertTrue(String(rendered.characters).contains("Title"))
        XCTAssertTrue(String(rendered.characters).contains("world"))
    }

    func testEmptyMarkdownRendersEmptyString() {
        let rendered = MarkdownRenderer.render("")

        XCTAssertEqual(String(rendered.characters), "")
    }

    func testLiveStyleKeepsLineBreaks() {
        let source = "# Title\n\nBody"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        XCTAssertEqual(rendered.string, source)
    }

    func testLiveStyleMakesHeadingLargerAndBold() throws {
        let source = "# Title\nBody"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: false, revealedRanges: [])
        )

        let titleFont = try XCTUnwrap(rendered.attribute(.font, at: 2, effectiveRange: nil) as? MarkdownNativeFont)
        let bodyFont = try XCTUnwrap(rendered.attribute(.font, at: 8, effectiveRange: nil) as? MarkdownNativeFont)

        XCTAssertGreaterThan(titleFont.pointSize, bodyFont.pointSize)

        #if os(macOS)
        XCTAssertTrue(titleFont.fontDescriptor.symbolicTraits.contains(.bold))
        #else
        XCTAssertTrue(titleFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        #endif
    }

    func testHeadingPrefixHidesHashAndFollowingSpace() throws {
        let source = "# Title"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        let hashFont = try XCTUnwrap(rendered.attribute(.font, at: 0, effectiveRange: nil) as? MarkdownNativeFont)
        let spaceFont = try XCTUnwrap(rendered.attribute(.font, at: 1, effectiveRange: nil) as? MarkdownNativeFont)
        let titleFont = try XCTUnwrap(rendered.attribute(.font, at: 2, effectiveRange: nil) as? MarkdownNativeFont)

        XCTAssertLessThan(hashFont.pointSize, 1)
        XCTAssertLessThan(spaceFont.pointSize, 1)
        XCTAssertGreaterThan(titleFont.pointSize, 17)
    }

    func testCodeBlockUsesContinuousParagraphSpacingAndTextInsets() throws {
        let source = """
        ```swift
        let value = 1
        print(value)
        ```
        After
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: false, revealedRanges: [])
        )

        let codeIndex = (source as NSString).range(of: "let value").location
        let paragraph = try XCTUnwrap(rendered.attribute(.paragraphStyle, at: codeIndex, effectiveRange: nil) as? NSParagraphStyle)
        let openingParagraph = try XCTUnwrap(rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let closingIndex = (source as NSString).range(of: "```", options: .backwards).location
        let closingParagraph = try XCTUnwrap(rendered.attribute(.paragraphStyle, at: closingIndex, effectiveRange: nil) as? NSParagraphStyle)
        let afterIndex = (source as NSString).range(of: "After").location
        let afterParagraph = try XCTUnwrap(rendered.attribute(.paragraphStyle, at: afterIndex, effectiveRange: nil) as? NSParagraphStyle)

        XCTAssertEqual(paragraph.lineSpacing, 0)
        XCTAssertEqual(paragraph.paragraphSpacing, 0)
        XCTAssertGreaterThan(paragraph.firstLineHeadIndent, 0)
        XCTAssertEqual(paragraph.headIndent, paragraph.firstLineHeadIndent)
        XCTAssertLessThan(paragraph.tailIndent, 0)
        XCTAssertGreaterThan(MarkdownStyle.codeBlockTopPadding, 0)
        XCTAssertGreaterThan(MarkdownStyle.codeBlockBottomPadding, MarkdownStyle.codeBlockTopPadding)
        XCTAssertGreaterThan(MarkdownStyle.codeBlockCornerRadius, 0)
        XCTAssertGreaterThan(openingParagraph.paragraphSpacingBefore, 0)
        XCTAssertEqual(closingParagraph.paragraphSpacing, 0)
        XCTAssertGreaterThan(afterParagraph.paragraphSpacingBefore, openingParagraph.paragraphSpacingBefore)
    }

    func testFencedCodeMarkersAreRevealedFromAnyLineInBlock() {
        let source = """
        ```swift
        let value = 1
        print(value)
        ```
        """
        let selectedLocation = (source as NSString).range(of: "print").location
        let revealedRanges = MarkdownStyle.revealedRanges(
            for: source,
            selectedRange: NSRange(location: selectedLocation, length: 0)
        )

        let openingFence = (source as NSString).range(of: "```swift")
        let closingFence = (source as NSString).range(of: "```", options: .backwards)

        XCTAssertTrue(revealedRanges.contains { NSIntersectionRange($0, openingFence).length > 0 })
        XCTAssertTrue(revealedRanges.contains { NSIntersectionRange($0, closingFence).length > 0 })
    }

    func testInlineMarkdownInsideCodeBlockIsNotInterpretedByDefault() throws {
        let source = """
        ```swift
        **bold** and *italic*
        ```
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: false, revealedRanges: [])
        )

        let boldIndex = (source as NSString).range(of: "bold").location
        let italicIndex = (source as NSString).range(of: "italic").location
        let boldFont = try XCTUnwrap(rendered.attribute(.font, at: boldIndex, effectiveRange: nil) as? MarkdownNativeFont)
        let italicFont = try XCTUnwrap(rendered.attribute(.font, at: italicIndex, effectiveRange: nil) as? MarkdownNativeFont)

        #if os(macOS)
        XCTAssertFalse(boldFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertFalse(italicFont.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #else
        XCTAssertFalse(boldFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertFalse(italicFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #endif
    }

    func testInlineMarkdownInsideTextCodeBlockKeepsMonospaceFontTraits() throws {
        let source = """
        ```text
        **bold** and *italic*
        ```
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: false, revealedRanges: [])
        )

        let boldIndex = (source as NSString).range(of: "bold").location
        let italicIndex = (source as NSString).range(of: "italic").location
        let boldFont = try XCTUnwrap(rendered.attribute(.font, at: boldIndex, effectiveRange: nil) as? MarkdownNativeFont)
        let italicFont = try XCTUnwrap(rendered.attribute(.font, at: italicIndex, effectiveRange: nil) as? MarkdownNativeFont)

        #if os(macOS)
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #else
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #endif
    }

    func testMarkdownLinkStylesLabelAndHidesMarkup() throws {
        let source = "[google](https://www.google.com)"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        let labelRange = (source as NSString).range(of: "google")
        let openingBracketColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MarkdownNativeColor)
        let urlColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: labelRange.location + labelRange.length + 2, effectiveRange: nil) as? MarkdownNativeColor)
        let link = try XCTUnwrap(rendered.attribute(.link, at: labelRange.location, effectiveRange: nil) as? String)

        XCTAssertEqual(link, "https://www.google.com")

        #if os(macOS)
        XCTAssertEqual(openingBracketColor.alphaComponent, 0)
        XCTAssertEqual(urlColor.alphaComponent, 0)
        #else
        XCTAssertEqual(openingBracketColor.cgColor.alpha, 0)
        XCTAssertEqual(urlColor.cgColor.alpha, 0)
        #endif
    }

    func testTripleAsteriskMakesTextBoldAndItalic() throws {
        let source = "***important***"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        let font = try XCTUnwrap(rendered.attribute(.font, at: 3, effectiveRange: nil) as? MarkdownNativeFont)
        let markerColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MarkdownNativeColor)

        #if os(macOS)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.italic))
        XCTAssertEqual(markerColor.alphaComponent, 0)
        #else
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertEqual(markerColor.cgColor.alpha, 0)
        #endif
    }

    func testMarkdownImageStylesAltTextAndHidesMarkup() throws {
        let source = "![le logo de Framasoft](https://framasoft.org/img/biglogo.png)"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        let altRange = (source as NSString).range(of: "le logo de Framasoft")
        let bangColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MarkdownNativeColor)
        let urlColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: altRange.location + altRange.length + 2, effectiveRange: nil) as? MarkdownNativeColor)
        let link = try XCTUnwrap(rendered.attribute(.link, at: altRange.location, effectiveRange: nil) as? String)

        XCTAssertEqual(link, "https://framasoft.org/img/biglogo.png")

        #if os(macOS)
        XCTAssertEqual(bangColor.alphaComponent, 0)
        XCTAssertEqual(urlColor.alphaComponent, 0)
        #else
        XCTAssertEqual(bangColor.cgColor.alpha, 0)
        XCTAssertEqual(urlColor.cgColor.alpha, 0)
        #endif
    }

    func testHiddenMarkdownDisablesSpellCheckingArtifacts() throws {
        let source = "![image](assets/image.png)"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        let spellingState = try XCTUnwrap(rendered.attribute(NSAttributedString.Key("NSSpellingState"), at: 0, effectiveRange: nil) as? Int)
        XCTAssertEqual(spellingState, 0)
    }

    func testBlockQuoteStylesTextAndHidesMarker() throws {
        let source = "> Oh la belle prise !"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )

        let markerColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MarkdownNativeColor)
        let paragraph = try XCTUnwrap(rendered.attribute(.paragraphStyle, at: 2, effectiveRange: nil) as? NSParagraphStyle)

        XCTAssertEqual(MarkdownStyle.blockQuoteRanges(in: source), [NSRange(location: 0, length: (source as NSString).length)])
        XCTAssertGreaterThan(paragraph.headIndent, 0)

        #if os(macOS)
        XCTAssertEqual(markerColor.alphaComponent, 0)
        #else
        XCTAssertEqual(markerColor.cgColor.alpha, 0)
        #endif
    }

    func testMarkdownTextEditingAddsImageWidth() throws {
        var source = "![Logo](assets/logo.png)"
        let reference = try XCTUnwrap(MarkdownStyle.imageReferences(in: source).first)

        let newRange = MarkdownTextEditing.setImageWidth(
            in: &source,
            imageRange: reference.range,
            percent: 50
        )

        XCTAssertEqual(source, "![Logo](assets/logo.png){width=50%}")
        XCTAssertEqual(newRange.map { String(source[$0]) }, source)
    }

    func testMarkdownTextEditingReplacesImageWidth() throws {
        var source = "![Logo](assets/logo.png){width=25%}"
        let reference = try XCTUnwrap(MarkdownStyle.imageReferences(in: source).first)

        let newRange = MarkdownTextEditing.setImageWidth(
            in: &source,
            imageRange: reference.range,
            percent: 75
        )

        XCTAssertEqual(source, "![Logo](assets/logo.png){width=75%}")
        XCTAssertEqual(newRange.map { String(source[$0]) }, source)
    }

    func testMarkdownTextEditingRemovesImageWidthForAuto() throws {
        var source = "![Logo](assets/logo.png){width=75%}"
        let reference = try XCTUnwrap(MarkdownStyle.imageReferences(in: source).first)

        let newRange = MarkdownTextEditing.setImageWidth(
            in: &source,
            imageRange: reference.range,
            percent: 0
        )

        XCTAssertEqual(source, "![Logo](assets/logo.png)")
        XCTAssertEqual(newRange.map { String(source[$0]) }, source)
    }

    func testMarkdownTextEditingFindsImageRangeContainingSelection() throws {
        let source = "Before\n![Logo](assets/logo.png){width=75%}\nAfter"
        let selectedRange = try XCTUnwrap(source.range(of: "Logo"))
        let imageRange = try XCTUnwrap(MarkdownTextEditing.imageRange(containing: selectedRange, in: source))

        XCTAssertEqual((source as NSString).substring(with: imageRange), "![Logo](assets/logo.png){width=75%}")
    }

    func testMarkdownTextEditingDoesNotFindImageRangeOutsideSelection() throws {
        let source = "Before\n![Logo](assets/logo.png)\nAfter"
        let selectedRange = try XCTUnwrap(source.range(of: "Before"))

        XCTAssertNil(MarkdownTextEditing.imageRange(containing: selectedRange, in: source))
    }

    func testMarkdownTextEditingWrapsSelectionInBold() throws {
        var source = "Hello world"
        let selectedRange = try XCTUnwrap(source.range(of: "world"))

        let newRange = MarkdownTextEditing.makeBold(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Hello **world**")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "world")
    }

    func testMarkdownTextEditingTogglesBoldOffWhenSelectionIsAlreadyWrapped() throws {
        var source = "Hello **world**"
        let selectedRange = try XCTUnwrap(source.range(of: "world"))

        let newRange = MarkdownTextEditing.makeBold(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Hello world")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "world")
    }

    func testMarkdownTextEditingTogglesItalicOffWhenSelectionIsAlreadyWrapped() throws {
        var source = "Hello *world*"
        let selectedRange = try XCTUnwrap(source.range(of: "world"))

        let newRange = MarkdownTextEditing.makeItalic(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Hello world")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "world")
    }

    func testMarkdownTextEditingBoldAtStartDoesNotCrash() throws {
        var source = "Hello"
        let selectedRange = try XCTUnwrap(source.range(of: "Hello"))

        let newRange = MarkdownTextEditing.makeBold(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "**Hello**")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Hello")
    }

    func testMarkdownTextEditingItalicAtEndDoesNotCrash() throws {
        var source = "Hello"
        let selectedRange = try XCTUnwrap(source.range(of: "Hello"))

        let newRange = MarkdownTextEditing.makeItalic(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "*Hello*")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Hello")
    }

    func testMarkdownTextEditingTogglesBlockQuoteOn() throws {
        var source = "Hello\nWorld"
        let selectedRange = try XCTUnwrap(source.range(of: "Hello"))

        let newRange = MarkdownTextEditing.toggleBlockQuote(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "> Hello\nWorld")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Hello")
    }

    func testMarkdownTextEditingTogglesBlockQuoteOff() throws {
        var source = "> Hello\nWorld"
        let selectedRange = try XCTUnwrap(source.range(of: "Hello"))

        let newRange = MarkdownTextEditing.toggleBlockQuote(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Hello\nWorld")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Hello")
    }

    func testMarkdownTextEditingTogglesBlockQuoteAcrossSelectedLines() throws {
        var source = "One\nTwo\nThree"
        let selectedStart = try XCTUnwrap(source.range(of: "One")).lowerBound
        let selectedEnd = try XCTUnwrap(source.range(of: "Two")).upperBound

        let newRange = MarkdownTextEditing.toggleBlockQuote(
            in: &source,
            selectedRange: selectedStart..<selectedEnd
        )

        XCTAssertEqual(source, "> One\n> Two\nThree")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "One\n> Two")
    }

    func testMarkdownTextEditingTogglesCodeBlockOn() throws {
        var source = "Before\nprint(\"Hello\")\nAfter"
        let selectedRange = try XCTUnwrap(source.range(of: "Hello"))

        let newRange = MarkdownTextEditing.toggleCodeBlock(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Before\n```\nprint(\"Hello\")\n```\nAfter")
        XCTAssertEqual(newRange.map { String(source[$0]) }, #"print("Hello")"#)
    }

    func testMarkdownTextEditingTogglesCodeBlockAcrossSelectedLines() throws {
        var source = "One\nTwo\nThree"
        let selectedStart = try XCTUnwrap(source.range(of: "One")).lowerBound
        let selectedEnd = try XCTUnwrap(source.range(of: "Two")).upperBound

        let newRange = MarkdownTextEditing.toggleCodeBlock(
            in: &source,
            selectedRange: selectedStart..<selectedEnd
        )

        XCTAssertEqual(source, "```\nOne\nTwo\n```\nThree")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "One\nTwo")
    }

    func testMarkdownTextEditingTogglesCodeBlockOff() throws {
        var source = "```\nprint(\"Hello\")\n```"
        let selectedRange = try XCTUnwrap(source.range(of: #"print("Hello")"#))

        let newRange = MarkdownTextEditing.toggleCodeBlock(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "print(\"Hello\")")
        XCTAssertEqual(newRange.map { String(source[$0]) }, #"print("Hello")"#)
    }

    func testMarkdownTextEditingInsertsSeparatorAsOwnBlock() throws {
        var source = "Before\nAfter"
        let insertionPoint = try XCTUnwrap(source.range(of: "Before")).upperBound

        let newRange = MarkdownTextEditing.insertSeparator(
            in: &source,
            selectedRange: insertionPoint..<insertionPoint
        )

        XCTAssertEqual(source, "Before\n\n---\n\nAfter")
        let cursor = source.index(source.startIndex, offsetBy: "Before\n\n---\n".count)
        XCTAssertEqual(newRange?.lowerBound, cursor)
        XCTAssertEqual(newRange?.upperBound, cursor)
    }

    func testMarkdownTextEditingInsertsSeparatorInEmptyDocument() throws {
        var source = ""

        let newRange = MarkdownTextEditing.insertSeparator(
            in: &source,
            selectedRange: source.startIndex..<source.startIndex
        )

        XCTAssertEqual(source, "---\n\n")
        XCTAssertEqual(newRange?.lowerBound, source.endIndex)
        XCTAssertEqual(newRange?.upperBound, source.endIndex)
    }

    func testMarkdownTextEditingAppliesHeadingToSelectedLine() throws {
        var source = "Title\nBody"
        let selectedRange = try XCTUnwrap(source.range(of: "Title"))

        let newRange = MarkdownTextEditing.applyHeading(level: 2, in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "## Title\nBody")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Title")
    }

    func testMarkdownTextEditingTogglesHeadingOffWhenSameLevelIsApplied() throws {
        var source = "## Title\nBody"
        let selectedRange = try XCTUnwrap(source.range(of: "Title"))

        let newRange = MarkdownTextEditing.applyHeading(level: 2, in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Title\nBody")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Title")
    }

    func testMarkdownTextEditingSwitchesHeadingLevel() throws {
        var source = "# Title\nBody"
        let selectedRange = try XCTUnwrap(source.range(of: "Title"))

        let newRange = MarkdownTextEditing.applyHeading(level: 2, in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "## Title\nBody")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Title")
    }

    func testMarkdownTextEditingCyclesHeadingFromNormalToH1() throws {
        var source = "Title\nBody"
        let selectedRange = try XCTUnwrap(source.range(of: "Title"))

        let newRange = MarkdownTextEditing.applyHeading(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "# Title\nBody")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Title")
    }

    func testMarkdownTextEditingCyclesHeadingFromH1ToH2() throws {
        var source = "# Title\nBody"
        let selectedRange = try XCTUnwrap(source.range(of: "Title"))

        let newRange = MarkdownTextEditing.applyHeading(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "## Title\nBody")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Title")
    }

    func testMarkdownTextEditingCyclesHeadingFromH2ToNormal() throws {
        var source = "## Title\nBody"
        let selectedRange = try XCTUnwrap(source.range(of: "Title"))

        let newRange = MarkdownTextEditing.applyHeading(in: &source, selectedRange: selectedRange)

        XCTAssertEqual(source, "Title\nBody")
        XCTAssertEqual(newRange.map { String(source[$0]) }, "Title")
    }

    func testHorizontalRuleIsDetectedAndCanHideMarkers() throws {
        let source = "---"
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )
        let markerColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MarkdownNativeColor)

        XCTAssertEqual(MarkdownStyle.horizontalRuleRanges(in: source), [NSRange(location: 0, length: 3)])

        #if os(macOS)
        XCTAssertEqual(markerColor.alphaComponent, 0)
        #else
        XCTAssertEqual(markerColor.cgColor.alpha, 0)
        #endif
    }

    func testHorizontalRuleInsideCodeBlockIsNotInterpretedByDefault() throws {
        let source = """
        ```swift
        ---
        ```
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: false, revealedRanges: [])
        )
        let ruleIndex = (source as NSString).range(of: "---").location
        let color = try XCTUnwrap(rendered.attribute(.foregroundColor, at: ruleIndex, effectiveRange: nil) as? MarkdownNativeColor)

        #if os(macOS)
        XCTAssertEqual(color, MarkdownNativeColor.labelColor)
        #else
        XCTAssertEqual(color, MarkdownNativeColor.label)
        #endif
        XCTAssertTrue(MarkdownStyle.renderedHorizontalRuleRanges(in: source).isEmpty)
    }

    func testHorizontalRuleInsideTextCodeBlockIsNotInterpreted() throws {
        let source = """
        ```text
        ---
        ```
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: false, revealedRanges: [])
        )
        let ruleIndex = (source as NSString).range(of: "---").location
        let color = try XCTUnwrap(rendered.attribute(.foregroundColor, at: ruleIndex, effectiveRange: nil) as? MarkdownNativeColor)

        #if os(macOS)
        XCTAssertEqual(color, MarkdownNativeColor.labelColor)
        #else
        XCTAssertEqual(color, MarkdownNativeColor.label)
        #endif
        XCTAssertTrue(MarkdownStyle.renderedHorizontalRuleRanges(in: source).isEmpty)
    }

    func testBlockQuoteInsideCodeBlockIsNotRendered() throws {
        let source = """
        ```text
        > quote
        ```
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )
        let markerIndex = (source as NSString).range(of: ">").location
        let markerColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: markerIndex, effectiveRange: nil) as? MarkdownNativeColor)

        #if os(macOS)
        XCTAssertEqual(markerColor, MarkdownNativeColor.labelColor)
        #else
        XCTAssertEqual(markerColor, MarkdownNativeColor.label)
        #endif
        XCTAssertTrue(MarkdownStyle.renderedBlockQuoteRanges(in: source).isEmpty)
    }

    func testImageInsideTextCodeBlockIsNotInterpreted() throws {
        let source = """
        ```text
        ![Logo](assets/logo.png)
        ```
        """
        let rendered = MarkdownStyle.attributedString(
            for: source,
            options: MarkdownStyleOptions(bodyFontSize: 17, hideMarkers: true, revealedRanges: [])
        )
        let markerIndex = (source as NSString).range(of: "!").location
        let markerColor = try XCTUnwrap(rendered.attribute(.foregroundColor, at: markerIndex, effectiveRange: nil) as? MarkdownNativeColor)

        #if os(macOS)
        XCTAssertEqual(markerColor, MarkdownNativeColor.labelColor)
        #else
        XCTAssertEqual(markerColor, MarkdownNativeColor.label)
        #endif
    }

    func testPDFExporterProducesPDFData() throws {
        let data = try MarkdownPDFExporter.export(markdown: "# Title\n\nHello **PDF**\n\n---")
        let prefix = String(data: data.prefix(4), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF")
        XCTAssertGreaterThan(data.count, 100)
    }

    func testPDFExporterHandlesMarkdownImagesWithoutAssetProvider() throws {
        let data = try MarkdownPDFExporter.export(
            markdown: "# Title\n\n![Logo](assets/logo.png){width=50%}\n\nAfter"
        )
        let prefix = String(data: data.prefix(4), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF")
        XCTAssertGreaterThan(data.count, 100)
    }

    func testPDFExporterRendersProvidedMarkdownImages() throws {
        let imageData = try XCTUnwrap(Self.onePixelPNGData)
        let data = try MarkdownPDFExporter.export(
            markdown: "# Title\n\n![Logo](assets/logo.png)\n\nAfter",
            configuration: MarkdownPDFExporter.Configuration(
                imageDataProvider: { path in
                    path == "assets/logo.png" ? imageData : nil
                }
            )
        )
        let prefix = String(data: data.prefix(4), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF")
        XCTAssertGreaterThan(data.count, 100)
    }

    func testPDFExporterDoesNotStallOnTallImages() throws {
        let imageData = try XCTUnwrap(Self.tallPNGData())
        let data = try MarkdownPDFExporter.export(
            markdown: "# Title\n\n![Tall](assets/tall.png)\n\nAfter",
            configuration: MarkdownPDFExporter.Configuration(
                pageSize: CGSize(width: 240, height: 240),
                margins: .init(top: 24, left: 24, bottom: 24, right: 24),
                imageDataProvider: { path in
                    path == "assets/tall.png" ? imageData : nil
                }
            )
        )
        let prefix = String(data: data.prefix(4), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF")
        XCTAssertGreaterThan(data.count, 100)
    }

    func testPDFExporterProducesFileDocument() throws {
        let document = try MarkdownPDFExporter.document(markdown: "# Title")
        let prefix = String(data: document.data.prefix(4), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF")
    }

    func testPDFExporterProducesShareItem() throws {
        let item = try MarkdownPDFExporter.shareItem(markdown: "# Title", filename: "Test.pdf")
        let prefix = String(data: item.data.prefix(4), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF")
        XCTAssertEqual(item.filename, "Test.pdf")
    }

    func testPDFExporterPaginatesLongDocuments() throws {
        let markdown = (1...120).map { "Line \($0)" }.joined(separator: "\n")
        let data = try MarkdownPDFExporter.export(
            markdown: markdown,
            configuration: MarkdownPDFExporter.Configuration(
                pageSize: CGSize(width: 240, height: 240),
                margins: .init(top: 24, left: 24, bottom: 24, right: 24),
                bodyFontSize: 17
            )
        )

        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let document = try XCTUnwrap(CGPDFDocument(provider))

        XCTAssertGreaterThan(document.numberOfPages, 1)
    }

    func testPDFExporterCanDisablePagination() throws {
        let markdown = (1...120).map { "Line \($0)" }.joined(separator: "\n")
        let data = try MarkdownPDFExporter.export(
            markdown: markdown,
            configuration: MarkdownPDFExporter.Configuration(
                pageSize: CGSize(width: 240, height: 240),
                margins: .init(top: 24, left: 24, bottom: 24, right: 24),
                bodyFontSize: 17,
                paginates: false
            )
        )

        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let document = try XCTUnwrap(CGPDFDocument(provider))

        XCTAssertEqual(document.numberOfPages, 1)
        XCTAssertGreaterThan(document.page(at: 1)?.getBoxRect(.mediaBox).height ?? 0, 240)
    }

    func testPDFExporterHandlesPaginatedCodeBlocks() throws {
        let code = (1...80).map { "print(\"line \($0)\")" }.joined(separator: "\n")
        let markdown = """
        Before

        ```swift
        \(code)
        ```

        After
        """
        let data = try MarkdownPDFExporter.export(
            markdown: markdown,
            configuration: MarkdownPDFExporter.Configuration(
                pageSize: CGSize(width: 240, height: 240),
                margins: .init(top: 24, left: 24, bottom: 24, right: 24),
                bodyFontSize: 12
            )
        )

        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let document = try XCTUnwrap(CGPDFDocument(provider))

        XCTAssertGreaterThan(document.numberOfPages, 1)
    }

    private static var onePixelPNGData: Data? {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")
    }

    private static func tallPNGData() -> Data? {
        #if os(macOS)
        let image = NSImage(size: CGSize(width: 20, height: 2_000))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 2_000).fill()
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return onePixelPNGData
        #endif
    }
}
