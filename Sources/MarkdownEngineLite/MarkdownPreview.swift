import SwiftUI

public enum MarkdownRenderer {
    public static func render(_ markdown: String, fallbackPrefix: String = "") -> AttributedString {
        guard !markdown.isEmpty else {
            return AttributedString("")
        }

        do {
            return try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            return AttributedString(fallbackPrefix + markdown)
        }
    }
}
