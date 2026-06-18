import Foundation

#if os(macOS)
import AppKit
typealias MarkdownNativeFont = NSFont
typealias MarkdownNativeColor = NSColor
#elseif os(iOS)
import UIKit
typealias MarkdownNativeFont = UIFont
typealias MarkdownNativeColor = UIColor
#endif

struct MarkdownStyleOptions {
    var bodyFontSize: CGFloat
    var hideMarkers: Bool
    var revealedRanges: [NSRange]
    var imageMaxWidth: CGFloat = 0
    var imageMaxHeight: CGFloat = 0
    var imageDataProvider: ((String) -> Data?)? = nil
}

struct MarkdownImageReference {
    let range: NSRange
    let path: String
    let widthPercent: CGFloat?
}

enum MarkdownStyle {
    static let codeBlockHorizontalPadding: CGFloat = 8
    static let codeBlockTopPadding: CGFloat = 6
    static let codeBlockBottomPadding: CGFloat = 16
    static let codeBlockSpacingBefore: CGFloat = 8
    static let codeBlockSpacingAfter: CGFloat = 24
    static let codeBlockCornerRadius: CGFloat = 10
    static let blockQuoteInset: CGFloat = 16
    static let blockQuoteBarWidth: CGFloat = 6
    static let imageVerticalPadding: CGFloat = 10

    static func horizontalRuleRanges(in text: String) -> [NSRange] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return matches(#"(?m)^[ \t]*-{3,}[ \t]*$"#, in: text, range: fullRange).map(\.range)
    }

    static func fencedCodeBlockRanges(in text: String) -> [NSRange] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return matches(#"(?ms)^```.*?$.*?^```[ \t]*$"#, in: text, range: fullRange).map(\.range)
    }

    static func blockQuoteRanges(in text: String) -> [NSRange] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return matches(#"(?m)^[ \t]*>[ \t]?.*$"#, in: text, range: fullRange).map(\.range)
    }

    static func imageReferences(in text: String) -> [MarkdownImageReference] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return matches(imagePattern, in: text, range: fullRange).compactMap { match in
            guard !intersectsFencedCode(match.range, source: nsText) else { return nil }

            let path = nsText.substring(with: match.range(at: 2))
            let widthPercentRange = match.range(at: 3)
            let widthPercent: CGFloat?
            if widthPercentRange.location != NSNotFound,
               let value = Double(nsText.substring(with: widthPercentRange)) {
                widthPercent = CGFloat(min(max(value, 1), 100))
            } else {
                widthPercent = nil
            }

            return MarkdownImageReference(
                range: match.range,
                path: path,
                widthPercent: widthPercent
            )
        }
    }

    static func revealedRanges(for text: String, selectedRange: NSRange) -> [NSRange] {
        let nsText = text as NSString
        guard selectedRange.location <= nsText.length else { return [] }

        let paragraphRange = nsText.paragraphRange(for: NSRange(location: selectedRange.location, length: 0))
        if let fencedCodeBlockRange = fencedCodeBlockRange(containing: selectedRange.location, in: text) {
            return [paragraphRange, fencedCodeBlockRange]
        }

        return [paragraphRange]
    }

    static func attributedString(for text: String, options: MarkdownStyleOptions) -> NSMutableAttributedString {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let output = NSMutableAttributedString(string: text)

        output.addAttributes(baseAttributes(fontSize: options.bodyFontSize), range: fullRange)
        styleFencedCode(in: output, source: nsText, fullRange: fullRange, options: options)
        styleBlockQuotes(in: output, source: nsText, fullRange: fullRange, options: options)
        styleHorizontalRules(in: output, source: nsText, fullRange: fullRange, options: options)
        styleHeadings(in: output, source: nsText, fullRange: fullRange, options: options)
        styleInlineCode(in: output, source: nsText, fullRange: fullRange, options: options)
        styleImages(in: output, source: nsText, fullRange: fullRange, options: options)
        styleStrongEmphasis(in: output, source: nsText, fullRange: fullRange, options: options)
        styleStrong(in: output, source: nsText, fullRange: fullRange, options: options)
        styleEmphasis(in: output, source: nsText, fullRange: fullRange, options: options)
        styleLinks(in: output, source: nsText, fullRange: fullRange, options: options)

        return output
    }

    private static func baseAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        return [
            .font: MarkdownNativeFont.systemFont(ofSize: fontSize),
            .foregroundColor: textColor,
            .paragraphStyle: baseParagraphStyle
        ]
    }

    private static func styleHeadings(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        let pattern = #"(?m)^(#{1,6})[ \t]+(.+)$"#
        for match in matches(pattern, in: source as String, range: fullRange) {
            guard !intersectsFencedCode(match.range, source: source) else { continue }

            let markerRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            let level = markerRange.length
            let scale: CGFloat

            switch level {
            case 1: scale = 2.0
            case 2: scale = 1.65
            case 3: scale = 1.35
            case 4: scale = 1.18
            default: scale = 1.05
            }

            output.addAttributes([
                .font: MarkdownNativeFont.boldSystemFont(ofSize: options.bodyFontSize * scale)
            ], range: titleRange)
            hide(
                NSRange(location: match.range.location, length: titleRange.location - match.range.location),
                in: output,
                options: options
            )
        }
    }

    private static func styleHorizontalRules(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        for range in horizontalRuleRanges(in: source as String) where NSIntersectionRange(range, fullRange).length > 0 {
            guard !intersectsFencedCode(range, source: source) else { continue }

            output.addAttributes([
                .foregroundColor: horizontalRuleColor
            ], range: range)

            guard options.hideMarkers,
                  !options.revealedRanges.contains(where: { NSIntersectionRange(range, $0).length > 0 }) else {
                continue
            }

            output.addAttributes([
                .foregroundColor: MarkdownNativeColor.clear
            ], range: range)
        }
    }

    private static func styleBlockQuotes(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        let pattern = #"(?m)^([ \t]*>[ \t]?)(.*)$"#
        for match in matches(pattern, in: source as String, range: fullRange) {
            guard !intersectsFencedCode(match.range, source: source) else { continue }

            let markerRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            let paragraphRange = source.paragraphRange(for: match.range)

            output.addAttributes([
                .paragraphStyle: blockQuoteParagraphStyle,
                .foregroundColor: secondaryTextColor
            ], range: paragraphRange)
            output.addAttributes([
                .font: italicFont(ofSize: options.bodyFontSize)
            ], range: textRange)
            hide(markerRange, in: output, options: options)
        }
    }

    private static func styleStrong(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        for delimiter in ["**", "__"] {
            let escaped = NSRegularExpression.escapedPattern(for: delimiter)
            let pattern = "\(escaped)(.+?)\(escaped)"

            for match in matches(pattern, in: source as String, range: fullRange) {
                guard !isWrappedByAdditionalDelimiter(match.range, delimiter: delimiter, source: source) else {
                    continue
                }
                let isInCodeBlock = intersectsFencedCode(match.range, source: source)

                output.addAttributes([
                    .font: isInCodeBlock
                        ? monospacedFont(ofSize: options.bodyFontSize * 0.92, weight: .bold)
                        : MarkdownNativeFont.boldSystemFont(ofSize: options.bodyFontSize)
                ], range: match.range(at: 1))
                hide(NSRange(location: match.range.location, length: delimiter.count), in: output, options: options)
                hide(NSRange(location: match.range.location + match.range.length - delimiter.count, length: delimiter.count), in: output, options: options)
            }
        }
    }

    private static func styleStrongEmphasis(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        for delimiter in ["***", "___"] {
            let escaped = NSRegularExpression.escapedPattern(for: delimiter)
            let pattern = "\(escaped)(.+?)\(escaped)"

            for match in matches(pattern, in: source as String, range: fullRange) {
                let isInCodeBlock = intersectsFencedCode(match.range, source: source)

                output.addAttributes([
                    .font: isInCodeBlock
                        ? monospacedBoldItalicFont(ofSize: options.bodyFontSize * 0.92)
                        : boldItalicFont(ofSize: options.bodyFontSize)
                ], range: match.range(at: 1))
                hide(NSRange(location: match.range.location, length: delimiter.count), in: output, options: options)
                hide(NSRange(location: match.range.location + match.range.length - delimiter.count, length: delimiter.count), in: output, options: options)
            }
        }
    }

    private static func styleEmphasis(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        let pattern = #"(?<!\*)\*([^\*\n]+)\*(?!\*)"#
        for match in matches(pattern, in: source as String, range: fullRange) {
            let isInCodeBlock = intersectsFencedCode(match.range, source: source)

            output.addAttributes([
                .font: isInCodeBlock
                    ? monospacedItalicFont(ofSize: options.bodyFontSize * 0.92)
                    : italicFont(ofSize: options.bodyFontSize)
            ], range: match.range(at: 1))
            hide(NSRange(location: match.range.location, length: 1), in: output, options: options)
            hide(NSRange(location: match.range.location + match.range.length - 1, length: 1), in: output, options: options)
        }
    }

    private static func styleInlineCode(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        let pattern = #"`([^`\n]+)`"#
        for match in matches(pattern, in: source as String, range: fullRange) {
            guard !intersectsFencedCode(match.range, source: source) else { continue }

            output.addAttributes([
                .font: MarkdownNativeFont.monospacedSystemFont(ofSize: options.bodyFontSize * 0.95, weight: .regular),
                .backgroundColor: codeBackgroundColor
            ], range: match.range(at: 1))
            hide(NSRange(location: match.range.location, length: 1), in: output, options: options)
            hide(NSRange(location: match.range.location + match.range.length - 1, length: 1), in: output, options: options)
        }
    }

    private static func styleImages(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        for match in matches(imagePattern, in: source as String, range: fullRange) {
            guard !intersectsFencedCode(match.range, source: source) else { continue }

            let altRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            let path = source.substring(with: urlRange)
            let revealed = options.revealedRanges.contains {
                NSIntersectionRange(match.range, $0).length > 0
            }
            let widthPercentRange = match.range(at: 3)
            let widthPercent = widthPercentRange.location == NSNotFound
                ? nil
                : Double(source.substring(with: widthPercentRange)).map { CGFloat($0) }

            if !revealed,
               let imageSize = resolvedImageSize(
                for: path,
                widthPercent: widthPercent,
                options: options
               ) {
                let paragraphRange = source.paragraphRange(for: match.range)
                output.addAttribute(
                    .paragraphStyle,
                    value: imageParagraphStyle(height: imageSize.height),
                    range: paragraphRange
                )
                hide(match.range, in: output, options: options)
                continue
            }

            if altRange.length > 0 {
                output.addAttributes([
                    .font: italicFont(ofSize: options.bodyFontSize),
                    .foregroundColor: secondaryTextColor,
                    .link: source.substring(with: urlRange)
                ], range: altRange)
            }

            hide(NSRange(location: match.range.location, length: altRange.location - match.range.location), in: output, options: options)
            hide(
                NSRange(location: NSMaxRange(altRange), length: NSMaxRange(match.range) - NSMaxRange(altRange)),
                in: output,
                options: options
            )
        }
    }

    static func resolvedImageSize(
        for path: String,
        widthPercent: CGFloat?,
        options: MarkdownStyleOptions
    ) -> CGSize? {
        guard options.imageMaxWidth > 0,
              let data = options.imageDataProvider?(path),
              let originalSize = nativeImageSize(from: data),
              originalSize.width > 0,
              originalSize.height > 0 else {
            return nil
        }

        let cappedMaxWidth = max(1, options.imageMaxWidth)
        let displayWidth: CGFloat
        if let widthPercent {
            displayWidth = cappedMaxWidth * min(max(widthPercent, 1), 100) / 100
        } else {
            displayWidth = min(originalSize.width, cappedMaxWidth)
        }

        let aspectRatio = originalSize.width / originalSize.height
        var size = CGSize(width: displayWidth, height: displayWidth / aspectRatio)

        if options.imageMaxHeight > 0, size.height > options.imageMaxHeight {
            let scale = options.imageMaxHeight / size.height
            size = CGSize(width: size.width * scale, height: options.imageMaxHeight)
        }

        return size
    }

    private static func styleFencedCode(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        for blockRange in fencedCodeBlockRanges(in: source as String)
            where NSIntersectionRange(blockRange, fullRange).length > 0 {
            output.addAttributes([
                .font: MarkdownNativeFont.monospacedSystemFont(ofSize: options.bodyFontSize * 0.92, weight: .regular),
                .paragraphStyle: codeBlockParagraphStyle
            ], range: blockRange)
            applyCodeBlockOuterSpacing(to: output, blockRange: blockRange, source: source)

            let block = source.substring(with: blockRange) as NSString
            let firstLineLength = block.range(of: "\n").location
            if firstLineLength != NSNotFound {
                hide(NSRange(location: blockRange.location, length: firstLineLength), in: output, options: options)
            }

            let closing = source.range(of: "```", options: .backwards, range: blockRange)
            if closing.location != NSNotFound {
                hide(closing, in: output, options: options)
            }
        }
    }

    private static func applyCodeBlockOuterSpacing(
        to output: NSMutableAttributedString,
        blockRange: NSRange,
        source: NSString
    ) {
        let firstParagraphRange = source.paragraphRange(
            for: NSRange(location: blockRange.location, length: 0)
        )
        output.addAttribute(
            .paragraphStyle,
            value: codeBlockParagraphStyle(spacingBefore: codeBlockSpacingBefore),
            range: firstParagraphRange
        )

        guard let nextParagraphRange = paragraphRangeAfterBlock(blockRange, source: source) else {
            return
        }
        output.addAttribute(
            .paragraphStyle,
            value: baseParagraphStyle(spacingBefore: codeBlockSpacingAfter),
            range: nextParagraphRange
        )
    }

    private static func paragraphRangeAfterBlock(_ blockRange: NSRange, source: NSString) -> NSRange? {
        var location = NSMaxRange(blockRange)

        while location < source.length {
            let character = source.character(at: location)
            guard character == 10 || character == 13 else { break }
            location += 1
        }

        guard location < source.length else { return nil }
        return source.paragraphRange(for: NSRange(location: location, length: 0))
    }

    private static func styleLinks(
        in output: NSMutableAttributedString,
        source: NSString,
        fullRange: NSRange,
        options: MarkdownStyleOptions
    ) {
        let pattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        for match in matches(pattern, in: source as String, range: fullRange) {
            guard !intersectsFencedCode(match.range, source: source) else { continue }

            if match.range.location > 0,
               source.character(at: match.range.location - 1) == 33 {
                continue
            }

            let labelRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            output.addAttributes([
                .foregroundColor: MarkdownNativeColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: source.substring(with: urlRange)
            ], range: labelRange)

            hide(NSRange(location: match.range.location, length: 1), in: output, options: options)
            hide(
                NSRange(location: NSMaxRange(labelRange), length: NSMaxRange(match.range) - NSMaxRange(labelRange)),
                in: output,
                options: options
            )
        }
    }

    private static func hide(
        _ range: NSRange,
        in output: NSMutableAttributedString,
        options: MarkdownStyleOptions
    ) {
        guard options.hideMarkers else { return }
        if options.revealedRanges.contains(where: { NSIntersectionRange(range, $0).length > 0 }) {
            return
        }

        output.addAttributes([
            .font: MarkdownNativeFont.systemFont(ofSize: 0.1),
            .foregroundColor: MarkdownNativeColor.clear,
            NSAttributedString.Key("NSSpellingState"): 0
        ], range: range)
    }

    private static func matches(_ pattern: String, in text: String, range: NSRange) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        return regex.matches(in: text, range: range)
    }

    private static let imagePattern = #"!\[([^\]]*)\]\(([^\)]+)\)(?:\{[ \t]*width[ \t]*=[ \t]*([0-9]{1,3})%[ \t]*\})?"#

    private static func intersectsFencedCode(_ range: NSRange, source: NSString) -> Bool {
        fencedCodeBlockRanges(in: source as String).contains {
            NSIntersectionRange(range, $0).length > 0
        }
    }

    private static func isWrappedByAdditionalDelimiter(
        _ range: NSRange,
        delimiter: String,
        source: NSString
    ) -> Bool {
        guard let character = delimiter.utf16.first else { return false }

        let hasPrevious = range.location > 0
            && source.character(at: range.location - 1) == character
        let nextLocation = NSMaxRange(range)
        let hasNext = nextLocation < source.length
            && source.character(at: nextLocation) == character

        return hasPrevious || hasNext
    }

    private static func fencedCodeBlockRange(containing location: Int, in text: String) -> NSRange? {
        fencedCodeBlockRanges(in: text)
            .first { NSLocationInRange(location, $0) || location == NSMaxRange($0) }
    }

    private static var textColor: MarkdownNativeColor {
        #if os(macOS)
        return .labelColor
        #else
        return .label
        #endif
    }

    private static var secondaryTextColor: MarkdownNativeColor {
        #if os(macOS)
        return .secondaryLabelColor
        #else
        return .secondaryLabel
        #endif
    }

    static var codeBackgroundColor: MarkdownNativeColor {
        #if os(macOS)
        return MarkdownNativeColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? MarkdownNativeColor(calibratedWhite: 0.18, alpha: 1)
                : MarkdownNativeColor(calibratedWhite: 0.92, alpha: 1)
        }
        #else
        return .secondarySystemFill
        #endif
    }

    private static var horizontalRuleColor: MarkdownNativeColor {
        #if os(macOS)
        return .separatorColor
        #else
        return .separator
        #endif
    }

    static var blockQuoteBarColor: MarkdownNativeColor {
        #if os(macOS)
        return .separatorColor
        #else
        return .separator
        #endif
    }

    private static var baseParagraphStyle: NSParagraphStyle {
        baseParagraphStyle()
    }

    private static func baseParagraphStyle(spacingBefore: CGFloat = 0) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 8
        paragraph.paragraphSpacingBefore = spacingBefore
        return paragraph
    }

    private static var blockQuoteParagraphStyle: NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 8
        paragraph.firstLineHeadIndent = blockQuoteInset
        paragraph.headIndent = blockQuoteInset
        return paragraph
    }

    private static var codeBlockParagraphStyle: NSParagraphStyle {
        codeBlockParagraphStyle()
    }

    private static func codeBlockParagraphStyle(
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacing = spacingAfter
        paragraph.paragraphSpacingBefore = spacingBefore
        paragraph.firstLineHeadIndent = codeBlockHorizontalPadding
        paragraph.headIndent = codeBlockHorizontalPadding
        paragraph.tailIndent = -codeBlockHorizontalPadding
        return paragraph
    }

    private static func imageParagraphStyle(height: CGFloat) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = height + imageVerticalPadding * 2
        paragraph.maximumLineHeight = height + imageVerticalPadding * 2
        paragraph.paragraphSpacing = 12
        return paragraph
    }

    private static func nativeImageSize(from data: Data) -> CGSize? {
        #if os(macOS)
        return NSImage(data: data)?.size
        #else
        return UIImage(data: data)?.size
        #endif
    }

    private static func italicFont(ofSize size: CGFloat) -> MarkdownNativeFont {
        #if os(macOS)
        let base = MarkdownNativeFont.systemFont(ofSize: size)
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        #else
        return MarkdownNativeFont.italicSystemFont(ofSize: size)
        #endif
    }

    private static func monospacedFont(ofSize size: CGFloat, weight: MarkdownNativeFont.Weight) -> MarkdownNativeFont {
        MarkdownNativeFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    private static func monospacedItalicFont(ofSize size: CGFloat) -> MarkdownNativeFont {
        #if os(macOS)
        let base = monospacedFont(ofSize: size, weight: .regular)
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        #else
        let descriptor = monospacedFont(ofSize: size, weight: .regular).fontDescriptor
            .withSymbolicTraits([.traitMonoSpace, .traitItalic])
        return descriptor.map { MarkdownNativeFont(descriptor: $0, size: size) }
            ?? monospacedFont(ofSize: size, weight: .regular)
        #endif
    }

    private static func monospacedBoldItalicFont(ofSize size: CGFloat) -> MarkdownNativeFont {
        #if os(macOS)
        let base = monospacedFont(ofSize: size, weight: .bold)
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        #else
        let descriptor = monospacedFont(ofSize: size, weight: .bold).fontDescriptor
            .withSymbolicTraits([.traitMonoSpace, .traitBold, .traitItalic])
        return descriptor.map { MarkdownNativeFont(descriptor: $0, size: size) }
            ?? monospacedFont(ofSize: size, weight: .bold)
        #endif
    }

    private static func boldItalicFont(ofSize size: CGFloat) -> MarkdownNativeFont {
        #if os(macOS)
        let bold = MarkdownNativeFont.boldSystemFont(ofSize: size)
        return NSFontManager.shared.convert(bold, toHaveTrait: .italicFontMask)
        #else
        let descriptor = MarkdownNativeFont.systemFont(ofSize: size).fontDescriptor
            .withSymbolicTraits([.traitBold, .traitItalic])
        return descriptor.map { MarkdownNativeFont(descriptor: $0, size: size) }
            ?? MarkdownNativeFont.boldSystemFont(ofSize: size)
        #endif
    }
}
