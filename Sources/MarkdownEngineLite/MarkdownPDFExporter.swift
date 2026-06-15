import Foundation
import CoreGraphics
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public enum MarkdownPDFExporter {
    public struct Margins: Sendable, Equatable {
        public var top: CGFloat
        public var left: CGFloat
        public var bottom: CGFloat
        public var right: CGFloat

        public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }
    }

    public struct Configuration: Sendable {
        public var pageSize: CGSize
        public var margins: Margins
        public var bodyFontSize: CGFloat

        public init(
            pageSize: CGSize = CGSize(width: 595.2, height: 841.8),
            margins: Margins = Margins(top: 56, left: 56, bottom: 56, right: 56),
            bodyFontSize: CGFloat = 12
        ) {
            self.pageSize = pageSize
            self.margins = margins
            self.bodyFontSize = bodyFontSize
        }

        public static let `default` = Configuration()
    }

    public static func export(
        markdown: String,
        configuration: Configuration = .default
    ) throws -> Data {
        let attributedString = MarkdownStyle.attributedString(
            for: markdown,
            options: MarkdownStyleOptions(
                bodyFontSize: configuration.bodyFontSize,
                hideMarkers: true,
                revealedRanges: []
            )
        )

        return try PDFRenderer(
            markdown: markdown,
            attributedString: attributedString,
            configuration: configuration
        ).render()
    }

    public static func document(
        markdown: String,
        configuration: Configuration = .default
    ) throws -> MarkdownPDFDocument {
        let data = try export(markdown: markdown, configuration: configuration)
        return MarkdownPDFDocument(data: data)
    }

    public static func shareItem(
        markdown: String,
        filename: String = "Document.pdf",
        configuration: Configuration = .default
    ) throws -> MarkdownPDFShareItem {
        let data = try export(markdown: markdown, configuration: configuration)
        return MarkdownPDFShareItem(data: data, filename: filename)
    }

    public static func write(
        markdown: String,
        to url: URL,
        configuration: Configuration = .default
    ) throws {
        let data = try export(markdown: markdown, configuration: configuration)
        try data.write(to: url, options: .atomic)
    }
}

public struct MarkdownPDFDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.pdf] }

    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

public struct MarkdownPDFShareItem: Transferable {
    public var data: Data
    public var filename: String

    public init(data: Data, filename: String = "Document.pdf") {
        self.data = data
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.filename)
            try item.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

private final class PDFRenderer {
    private let markdown: String
    private let attributedString: NSAttributedString
    private let configuration: MarkdownPDFExporter.Configuration
    private let textStorage: NSTextStorage
    private let layoutManager: NSLayoutManager
    private var textContainers: [NSTextContainer] = []

    private var contentRect: CGRect {
        CGRect(
            x: configuration.margins.left,
            y: configuration.margins.top,
            width: configuration.pageSize.width - configuration.margins.left - configuration.margins.right,
            height: configuration.pageSize.height - configuration.margins.top - configuration.margins.bottom
        )
    }

    init(
        markdown: String,
        attributedString: NSAttributedString,
        configuration: MarkdownPDFExporter.Configuration
    ) {
        self.markdown = markdown
        self.attributedString = attributedString
        self.configuration = configuration
        self.textStorage = NSTextStorage(attributedString: attributedString)
        self.layoutManager = NSLayoutManager()
        self.textStorage.addLayoutManager(layoutManager)
    }

    func render() throws -> Data {
        paginate()

        #if os(macOS)
        return renderMacPDF()
        #elseif os(iOS)
        return renderIOSPDF()
        #endif
    }

    private func paginate() {
        textContainers.removeAll()

        let size = contentRect.size
        repeat {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)
            textContainers.append(container)

            let glyphRange = layoutManager.glyphRange(for: container)
            if NSMaxRange(glyphRange) >= layoutManager.numberOfGlyphs {
                break
            }
        } while true

        if textContainers.isEmpty {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            textContainers.append(container)
        }
    }

    #if os(macOS)
    private func renderMacPDF() -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: configuration.pageSize)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        for container in textContainers {
            context.beginPDFPage(nil)
            context.saveGState()
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(origin: .zero, size: configuration.pageSize))
            context.translateBy(x: contentRect.minX, y: configuration.pageSize.height - contentRect.minY)
            context.scaleBy(x: 1, y: -1)

            let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext
            draw(container: container)
            NSGraphicsContext.restoreGraphicsState()

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()
        return data as Data
    }
    #endif

    #if os(iOS)
    private func renderIOSPDF() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: configuration.pageSize),
            format: format
        )

        return renderer.pdfData { context in
            for container in textContainers {
                context.beginPage()
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: configuration.pageSize))
                UIGraphicsPushContext(context.cgContext)
                context.cgContext.translateBy(x: contentRect.minX, y: contentRect.minY)
                draw(container: container)
                UIGraphicsPopContext()
            }
        }
    }
    #endif

    private func draw(container: NSTextContainer) {
        let glyphRange = layoutManager.glyphRange(for: container)
        drawCodeBlockBackgrounds(in: container, glyphRange: glyphRange)
        drawBlockQuoteBars(in: container, glyphRange: glyphRange)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        drawHorizontalRules(in: container, glyphRange: glyphRange)
    }

    private func drawCodeBlockBackgrounds(in container: NSTextContainer, glyphRange: NSRange) {
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )

        for codeBlockRange in MarkdownStyle.fencedCodeBlockRanges(in: markdown) {
            guard NSIntersectionRange(codeBlockRange, characterRange).length > 0 else { continue }

            let codeGlyphRange = layoutManager.glyphRange(
                forCharacterRange: codeBlockRange,
                actualCharacterRange: nil
            )
            let visibleCodeGlyphRange = NSIntersectionRange(codeGlyphRange, glyphRange)
            guard visibleCodeGlyphRange.length > 0 else { continue }

            var blockRect = CGRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: visibleCodeGlyphRange) { lineRect, _, _, _, _ in
                blockRect = blockRect.union(lineRect)
            }
            guard !blockRect.isNull else { continue }

            let roundsTop = visibleCodeGlyphRange.location == codeGlyphRange.location
            let roundsBottom = NSMaxRange(visibleCodeGlyphRange) == NSMaxRange(codeGlyphRange)
            let topPadding = roundsTop ? MarkdownStyle.codeBlockTopPadding : 0
            let bottomPadding = roundsBottom ? MarkdownStyle.codeBlockBottomPadding : 0
            let rect = CGRect(
                x: 0,
                y: blockRect.minY - topPadding,
                width: contentRect.width,
                height: blockRect.height + topPadding + bottomPadding
            )
            drawCodeBlockBackground(
                rect.intersection(CGRect(origin: .zero, size: contentRect.size)),
                roundsTop: roundsTop,
                roundsBottom: roundsBottom
            )
        }
    }

    private func drawCodeBlockBackground(_ rect: CGRect, roundsTop: Bool, roundsBottom: Bool) {
        #if os(macOS)
        MarkdownStyle.codeBackgroundColor.setFill()
        roundedRectPath(rect, roundsTop: roundsTop, roundsBottom: roundsBottom).fill()
        #elseif os(iOS)
        MarkdownStyle.codeBackgroundColor.setFill()
        UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: roundedCorners(roundsTop: roundsTop, roundsBottom: roundsBottom),
            cornerRadii: CGSize(
                width: MarkdownStyle.codeBlockCornerRadius,
                height: MarkdownStyle.codeBlockCornerRadius
            )
        ).fill()
        #endif
    }

    #if os(macOS)
    private func roundedRectPath(_ rect: CGRect, roundsTop: Bool, roundsBottom: Bool) -> NSBezierPath {
        let radius = min(MarkdownStyle.codeBlockCornerRadius, rect.width / 2, rect.height / 2)
        let path = NSBezierPath()

        path.move(to: CGPoint(x: rect.minX + (roundsTop ? radius : 0), y: rect.minY))

        if roundsTop {
            path.line(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.curve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                controlPoint1: CGPoint(x: rect.maxX - radius * 0.45, y: rect.minY),
                controlPoint2: CGPoint(x: rect.maxX, y: rect.minY + radius * 0.45)
            )
        } else {
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        if roundsBottom {
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.curve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY - radius * 0.45),
                controlPoint2: CGPoint(x: rect.maxX - radius * 0.45, y: rect.maxY)
            )
            path.line(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.curve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                controlPoint1: CGPoint(x: rect.minX + radius * 0.45, y: rect.maxY),
                controlPoint2: CGPoint(x: rect.minX, y: rect.maxY - radius * 0.45)
            )
        } else {
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        }

        if roundsTop {
            path.line(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.curve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                controlPoint1: CGPoint(x: rect.minX, y: rect.minY + radius * 0.45),
                controlPoint2: CGPoint(x: rect.minX + radius * 0.45, y: rect.minY)
            )
        } else {
            path.line(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.close()
        return path
    }
    #elseif os(iOS)
    private func roundedCorners(roundsTop: Bool, roundsBottom: Bool) -> UIRectCorner {
        var corners: UIRectCorner = []

        if roundsTop {
            corners.insert(.topLeft)
            corners.insert(.topRight)
        }

        if roundsBottom {
            corners.insert(.bottomLeft)
            corners.insert(.bottomRight)
        }

        return corners
    }
    #endif

    private func drawBlockQuoteBars(in container: NSTextContainer, glyphRange: NSRange) {
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )

        for quoteRange in MarkdownStyle.blockQuoteRanges(in: markdown) {
            guard NSIntersectionRange(quoteRange, characterRange).length > 0 else { continue }

            let quoteGlyphRange = layoutManager.glyphRange(
                forCharacterRange: quoteRange,
                actualCharacterRange: nil
            )
            let visibleQuoteGlyphRange = NSIntersectionRange(quoteGlyphRange, glyphRange)
            guard visibleQuoteGlyphRange.length > 0 else { continue }

            var quoteRect = CGRect.null
            layoutManager.enumerateLineFragments(forGlyphRange: visibleQuoteGlyphRange) { lineRect, _, _, _, _ in
                quoteRect = quoteRect.union(lineRect)
            }
            guard !quoteRect.isNull else { continue }

            let rect = CGRect(
                x: 0,
                y: quoteRect.minY,
                width: MarkdownStyle.blockQuoteBarWidth,
                height: quoteRect.height
            )
            drawBlockQuoteBar(rect)
        }
    }

    private func drawBlockQuoteBar(_ rect: CGRect) {
        #if os(macOS)
        MarkdownStyle.blockQuoteBarColor.setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: MarkdownStyle.blockQuoteBarWidth / 2,
            yRadius: MarkdownStyle.blockQuoteBarWidth / 2
        ).fill()
        #elseif os(iOS)
        MarkdownStyle.blockQuoteBarColor.setFill()
        UIBezierPath(
            roundedRect: rect,
            cornerRadius: MarkdownStyle.blockQuoteBarWidth / 2
        ).fill()
        #endif
    }

    private func drawHorizontalRules(in container: NSTextContainer, glyphRange: NSRange) {
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )

        for ruleRange in MarkdownStyle.horizontalRuleRanges(in: markdown) {
            guard NSIntersectionRange(ruleRange, characterRange).length > 0 else { continue }

            let ruleGlyphRange = layoutManager.glyphRange(
                forCharacterRange: ruleRange,
                actualCharacterRange: nil
            )
            guard NSIntersectionRange(ruleGlyphRange, glyphRange).length > 0 else { continue }

            let rect = layoutManager.boundingRect(forGlyphRange: ruleGlyphRange, in: container)
            let y = rect.midY
            drawSeparatorLine(y: y)
        }
    }

    private func drawSeparatorLine(y: CGFloat) {
        #if os(macOS)
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: 0, y: y))
        path.line(to: CGPoint(x: contentRect.width, y: y))
        path.stroke()
        #elseif os(iOS)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: 0, y: y))
        context.addLine(to: CGPoint(x: contentRect.width, y: y))
        context.strokePath()
        context.restoreGState()
        #endif
    }
}
