import Foundation

public enum MarkdownTextEditing {
    @discardableResult
    public static func wrapSelection(
        in text: inout String,
        selectedRange: Range<String.Index>?,
        prefix: String,
        suffix: String
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        let lowerOffset = text.distance(from: text.startIndex, to: selectedRange.lowerBound)
        let selectedText = String(text[selectedRange])
        let replacement = prefix + selectedText + suffix
        text.replaceSubrange(selectedRange, with: replacement)

        let selectionStart = text.index(text.startIndex, offsetBy: lowerOffset + prefix.count)
        let selectionEnd = text.index(selectionStart, offsetBy: selectedText.count)
        return selectionStart..<selectionEnd
    }

    @discardableResult
    public static func toggleSelection(
        in text: inout String,
        selectedRange: Range<String.Index>?,
        prefix: String,
        suffix: String
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        if hasMarkers(around: selectedRange, in: text, prefix: prefix, suffix: suffix) {
            return unwrapSelection(
                in: &text,
                selectedRange: selectedRange,
                prefix: prefix,
                suffix: suffix
            )
        }

        return wrapSelection(in: &text, selectedRange: selectedRange, prefix: prefix, suffix: suffix)
    }

    @discardableResult
    public static func makeBold(
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        toggleSelection(in: &text, selectedRange: selectedRange, prefix: "**", suffix: "**")
    }

    @discardableResult
    public static func makeItalic(
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        toggleSelection(in: &text, selectedRange: selectedRange, prefix: "*", suffix: "*")
    }

    @discardableResult
    public static func toggleBlockQuote(
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        let editRange = text.lineRange(for: selectedRange)
        let edits = blockQuoteEdits(in: text, editRange: editRange)
        guard !edits.isEmpty else { return selectedRange }

        return apply(edits, to: &text, preserving: selectedRange)
    }

    @discardableResult
    public static func toggleCodeBlock(
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        if let blockRange = fencedCodeBlockRange(containing: selectedRange, in: text) {
            return unwrapCodeBlock(in: &text, blockRange: blockRange, selectedRange: selectedRange)
        }

        let blockContentRange = codeBlockContentRange(in: text, selectedRange: selectedRange)
        let lowerOffset = text.distance(from: text.startIndex, to: blockContentRange.lowerBound)
        let selectedText = String(text[blockContentRange])
        let replacement = "```\n" + selectedText + "\n```"
        text.replaceSubrange(blockContentRange, with: replacement)

        let selectionStart = text.index(text.startIndex, offsetBy: lowerOffset + 4)
        let selectionEnd = text.index(selectionStart, offsetBy: selectedText.count)
        return selectionStart..<selectionEnd
    }

    @discardableResult
    public static func insertSeparator(
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        let insertionIndex = selectedRange.upperBound
        let insertionOffset = text.distance(from: text.startIndex, to: insertionIndex)
        let prefix = separatorPrefix(before: insertionIndex, in: text)
        let suffix = separatorSuffix(after: insertionIndex, in: text)
        let replacement = prefix + "---" + suffix

        text.insert(contentsOf: replacement, at: insertionIndex)

        let cursorOffset = insertionOffset + replacement.count
        let cursor = text.index(text.startIndex, offsetBy: cursorOffset)
        return cursor..<cursor
    }

    @discardableResult
    public static func setImageWidth(
        in text: inout String,
        imageRange: NSRange,
        percent: CGFloat
    ) -> Range<String.Index>? {
        guard let range = Range(imageRange, in: text) else { return nil }

        let markdown = String(text[range])
        let baseMarkdown = removingImageWidthAttribute(from: markdown)
        let replacement: String
        if percent <= 0 {
            replacement = baseMarkdown
        } else {
            let clampedPercent = Int(min(max(percent.rounded(), 1), 100))
            replacement = "\(baseMarkdown){width=\(clampedPercent)%}"
        }
        let lowerOffset = text.distance(from: text.startIndex, to: range.lowerBound)

        text.replaceSubrange(range, with: replacement)

        let lower = text.index(text.startIndex, offsetBy: lowerOffset)
        let upper = text.index(lower, offsetBy: replacement.count)
        return lower..<upper
    }

    public static func imageRange(
        containing selectedRange: Range<String.Index>?,
        in text: String
    ) -> NSRange? {
        guard let selectedRange,
              let nsRange = safeNSRange(selectedRange, in: text) else {
            return nil
        }

        return MarkdownStyle.imageReferences(in: text).first { reference in
            if nsRange.length == 0 {
                return nsRange.location >= reference.range.location
                    && nsRange.location <= NSMaxRange(reference.range)
            }

            return NSIntersectionRange(nsRange, reference.range).length > 0
        }?.range
    }

    @discardableResult
    public static func applyHeading(
        level: Int,
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        return applyHeading(
            replacementLevel: min(max(level, 1), 6),
            togglesSameLevelOff: true,
            in: &text,
            selectedRange: selectedRange
        )
    }

    @discardableResult
    public static func applyHeading(
        in text: inout String,
        selectedRange: Range<String.Index>?
    ) -> Range<String.Index>? {
        guard let selectedRange else { return nil }

        let currentLevel = headingLevel(in: text, selectedRange: selectedRange)
        let nextLevel: Int?

        switch currentLevel {
        case nil:
            nextLevel = 1
        case 1:
            nextLevel = 2
        default:
            nextLevel = nil
        }

        return applyHeading(
            replacementLevel: nextLevel,
            togglesSameLevelOff: false,
            in: &text,
            selectedRange: selectedRange
        )
    }

    private static func applyHeading(
        replacementLevel: Int?,
        togglesSameLevelOff: Bool,
        in text: inout String,
        selectedRange: Range<String.Index>
    ) -> Range<String.Index>? {
        let lineRange = text.lineRange(for: selectedRange)
        let lowerOffset = text.distance(from: text.startIndex, to: selectedRange.lowerBound)
        let upperOffset = text.distance(from: text.startIndex, to: selectedRange.upperBound)

        let existingHeading = text[lineRange].prefix { $0 == "#" }
        let existingLevel = existingHeading.count
        var contentStart = lineRange.lowerBound

        if !existingHeading.isEmpty {
            let afterHashes = text.index(lineRange.lowerBound, offsetBy: existingHeading.count)
            if afterHashes < lineRange.upperBound, text[afterHashes] == " " {
                contentStart = text.index(afterHashes, offsetBy: 1)
            }
        }

        let replacedPrefixLength = text.distance(from: lineRange.lowerBound, to: contentStart)
        let replacement: String

        if togglesSameLevelOff, existingLevel == replacementLevel {
            replacement = ""
        } else if let replacementLevel {
            replacement = String(repeating: "#", count: replacementLevel) + " "
        } else {
            replacement = ""
        }

        text.replaceSubrange(lineRange.lowerBound..<contentStart, with: replacement)
        let delta = replacement.count - replacedPrefixLength
        let lower = text.index(text.startIndex, offsetBy: lowerOffset + delta)
        let upper = text.index(text.startIndex, offsetBy: upperOffset + delta)
        return lower..<upper
    }

    private static func headingLevel(
        in text: String,
        selectedRange: Range<String.Index>
    ) -> Int? {
        let lineRange = text.lineRange(for: selectedRange)
        let existingHeading = text[lineRange].prefix { $0 == "#" }
        guard !existingHeading.isEmpty else { return nil }

        let afterHashes = text.index(lineRange.lowerBound, offsetBy: existingHeading.count)
        guard afterHashes < lineRange.upperBound, text[afterHashes] == " " else {
            return nil
        }

        return existingHeading.count
    }

    private static func codeBlockContentRange(
        in text: String,
        selectedRange: Range<String.Index>
    ) -> Range<String.Index> {
        let lowerLineRange = text.lineRange(for: selectedRange.lowerBound..<selectedRange.lowerBound)
        let upperProbe: String.Index

        if selectedRange.isEmpty {
            upperProbe = selectedRange.upperBound
        } else {
            upperProbe = text.index(before: selectedRange.upperBound)
        }

        let upperLineRange = text.lineRange(for: upperProbe..<upperProbe)
        return trimmingTrailingLineEndings(
            lowerLineRange.lowerBound..<upperLineRange.upperBound,
            in: text
        )
    }

    private static func fencedCodeBlockRange(
        containing selectedRange: Range<String.Index>,
        in text: String
    ) -> NSRange? {
        let nsRange = NSRange(selectedRange, in: text)
        return MarkdownStyle.fencedCodeBlockRanges(in: text).first { blockRange in
            let lowerInside = nsRange.location >= blockRange.location
                && nsRange.location <= NSMaxRange(blockRange)
            let upperInside = NSMaxRange(nsRange) >= blockRange.location
                && NSMaxRange(nsRange) <= NSMaxRange(blockRange)
            return lowerInside && upperInside
        }
    }

    private static func unwrapCodeBlock(
        in text: inout String,
        blockRange: NSRange,
        selectedRange: Range<String.Index>
    ) -> Range<String.Index>? {
        let source = text as NSString
        let openingLineEnd = source.range(of: "\n", range: blockRange)
        guard openingLineEnd.location != NSNotFound else { return selectedRange }

        let closingFence = source.range(of: "```", options: .backwards, range: blockRange)
        guard closingFence.location != NSNotFound else { return selectedRange }

        var closingLocation = closingFence.location
        let characterBeforeClosing = closingLocation > blockRange.location
            ? source.character(at: closingLocation - 1)
            : nil
        if closingLocation > blockRange.location,
           characterBeforeClosing == 10 || characterBeforeClosing == 13 {
            closingLocation -= 1
        }

        let edits = [
            TextEdit(
                location: blockRange.location,
                removedLength: NSMaxRange(openingLineEnd) - blockRange.location,
                replacement: ""
            ),
            TextEdit(
                location: closingLocation,
                removedLength: NSMaxRange(closingFence) - closingLocation,
                replacement: ""
            )
        ]

        return apply(edits, to: &text, preserving: selectedRange)
    }

    private static func trimmingTrailingLineEndings(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index> {
        var upperBound = range.upperBound

        while upperBound > range.lowerBound {
            let previous = text.index(before: upperBound)
            guard text[previous] == "\n" || text[previous] == "\r" else { break }
            upperBound = previous
        }

        return range.lowerBound..<upperBound
    }

    private static func separatorPrefix(before index: String.Index, in text: String) -> String {
        guard index > text.startIndex else { return "" }

        if text[..<index].hasSuffix("\n\n") {
            return ""
        }
        if text[..<index].hasSuffix("\n") {
            return "\n"
        }
        return "\n\n"
    }

    private static func separatorSuffix(after index: String.Index, in text: String) -> String {
        guard index < text.endIndex else { return "\n\n" }

        if text[index...].hasPrefix("\n\n") {
            return ""
        }
        if text[index...].hasPrefix("\n") {
            return "\n"
        }
        return "\n\n"
    }

    private static func removingImageWidthAttribute(from markdown: String) -> String {
        let pattern = #"\{[ \t]*width[ \t]*=[ \t]*[0-9]{1,3}%[ \t]*\}[ \t]*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return markdown
        }

        let range = NSRange(location: 0, length: (markdown as NSString).length)
        return expression.stringByReplacingMatches(
            in: markdown,
            range: range,
            withTemplate: ""
        )
    }

    private static func safeNSRange(_ range: Range<String.Index>, in text: String) -> NSRange? {
        guard let lowerBound = range.lowerBound.samePosition(in: text.utf16),
              let upperBound = range.upperBound.samePosition(in: text.utf16) else {
            return nil
        }

        let location = text.utf16.distance(from: text.utf16.startIndex, to: lowerBound)
        let upperLocation = text.utf16.distance(from: text.utf16.startIndex, to: upperBound)
        guard location <= upperLocation else { return nil }
        return NSRange(location: location, length: upperLocation - location)
    }

    private struct TextEdit {
        var location: Int
        var removedLength: Int
        var replacement: String

        var delta: Int {
            replacement.count - removedLength
        }
    }

    private static func blockQuoteEdits(
        in text: String,
        editRange: Range<String.Index>
    ) -> [TextEdit] {
        let lineRanges = lineRanges(in: text, editRange: editRange)
        let allQuoted = lineRanges.allSatisfy { lineRange in
            blockQuoteMarkerRange(in: text, lineRange: lineRange) != nil
        }

        if allQuoted {
            return lineRanges.compactMap { lineRange in
                guard let markerRange = blockQuoteMarkerRange(in: text, lineRange: lineRange) else {
                    return nil
                }

                return TextEdit(
                    location: text.distance(from: text.startIndex, to: markerRange.lowerBound),
                    removedLength: text.distance(from: markerRange.lowerBound, to: markerRange.upperBound),
                    replacement: ""
                )
            }
        }

        return lineRanges.map { lineRange in
            TextEdit(
                location: text.distance(from: text.startIndex, to: lineRange.lowerBound),
                removedLength: 0,
                replacement: "> "
            )
        }
    }

    private static func lineRanges(
        in text: String,
        editRange: Range<String.Index>
    ) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var current = editRange.lowerBound

        while current < editRange.upperBound {
            let lineRange = text.lineRange(for: current..<current)
            ranges.append(lineRange)

            guard lineRange.upperBound > current else { break }
            current = lineRange.upperBound
        }

        if ranges.isEmpty {
            ranges.append(text.lineRange(for: editRange))
        }

        return ranges
    }

    private static func blockQuoteMarkerRange(
        in text: String,
        lineRange: Range<String.Index>
    ) -> Range<String.Index>? {
        var current = lineRange.lowerBound

        while current < lineRange.upperBound, isIndentWhitespace(text[current]) {
            current = text.index(after: current)
        }

        guard current < lineRange.upperBound, text[current] == ">" else {
            return nil
        }

        var markerEnd = text.index(after: current)
        if markerEnd < lineRange.upperBound, isIndentWhitespace(text[markerEnd]) {
            markerEnd = text.index(after: markerEnd)
        }

        return current..<markerEnd
    }

    private static func isIndentWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }

    private static func apply(
        _ edits: [TextEdit],
        to text: inout String,
        preserving selectedRange: Range<String.Index>
    ) -> Range<String.Index>? {
        var lowerOffset = text.distance(from: text.startIndex, to: selectedRange.lowerBound)
        var upperOffset = text.distance(from: text.startIndex, to: selectedRange.upperBound)

        for edit in edits {
            if edit.location <= lowerOffset {
                lowerOffset += edit.delta
            }
            if edit.location <= upperOffset {
                upperOffset += edit.delta
            }
        }

        for edit in edits.sorted(by: { $0.location > $1.location }) {
            let lower = text.index(text.startIndex, offsetBy: edit.location)
            let upper = text.index(lower, offsetBy: edit.removedLength)
            text.replaceSubrange(lower..<upper, with: edit.replacement)
        }

        lowerOffset = min(max(lowerOffset, 0), text.count)
        upperOffset = min(max(upperOffset, lowerOffset), text.count)
        let lower = text.index(text.startIndex, offsetBy: lowerOffset)
        let upper = text.index(text.startIndex, offsetBy: upperOffset)
        return lower..<upper
    }

    private static func hasMarkers(
        around selectedRange: Range<String.Index>,
        in text: String,
        prefix: String,
        suffix: String
    ) -> Bool {
        guard let prefixRange = range(before: selectedRange.lowerBound, length: prefix.count, in: text),
              let suffixRange = range(after: selectedRange.upperBound, length: suffix.count, in: text) else {
            return false
        }

        return text[prefixRange] == prefix && text[suffixRange] == suffix
    }

    private static func unwrapSelection(
        in text: inout String,
        selectedRange: Range<String.Index>,
        prefix: String,
        suffix: String
    ) -> Range<String.Index>? {
        guard let prefixRange = range(before: selectedRange.lowerBound, length: prefix.count, in: text),
              let suffixRange = range(after: selectedRange.upperBound, length: suffix.count, in: text) else {
            return nil
        }

        let lowerOffset = text.distance(from: text.startIndex, to: selectedRange.lowerBound)
        let selectedLength = text.distance(from: selectedRange.lowerBound, to: selectedRange.upperBound)

        text.removeSubrange(suffixRange)
        text.removeSubrange(prefixRange)

        let selectionStart = text.index(text.startIndex, offsetBy: lowerOffset - prefix.count)
        let selectionEnd = text.index(selectionStart, offsetBy: selectedLength)
        return selectionStart..<selectionEnd
    }

    private static func range(before index: String.Index, length: Int, in text: String) -> Range<String.Index>? {
        guard length > 0,
              let lowerBound = text.index(index, offsetBy: -length, limitedBy: text.startIndex) else {
            return nil
        }

        guard lowerBound <= index else { return nil }
        return lowerBound..<index
    }

    private static func range(after index: String.Index, length: Int, in text: String) -> Range<String.Index>? {
        guard length > 0,
              let upperBound = text.index(index, offsetBy: length, limitedBy: text.endIndex) else {
            return nil
        }

        guard index <= upperBound else { return nil }
        return index..<upperBound
    }
}
