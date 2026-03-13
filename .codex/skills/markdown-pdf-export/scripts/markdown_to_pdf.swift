import Foundation
import AppKit
import CoreText

struct Config {
    var inputPath: String = ""
    var outputPath: String = ""
    var title: String?
}

enum ConfigError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let message):
            return message
        }
    }
}

func parseArgs() throws -> Config {
    var config = Config()
    let args = Array(CommandLine.arguments.dropFirst())
    var index = 0

    while index < args.count {
        let arg = args[index]
        switch arg {
        case "--input":
            index += 1
            guard index < args.count else { throw ConfigError.message("Missing value for --input") }
            config.inputPath = args[index]
        case "--output":
            index += 1
            guard index < args.count else { throw ConfigError.message("Missing value for --output") }
            config.outputPath = args[index]
        case "--title":
            index += 1
            guard index < args.count else { throw ConfigError.message("Missing value for --title") }
            config.title = args[index]
        case "--help":
            throw ConfigError.message("""
            Usage:
              swift markdown_to_pdf.swift --input source.md --output output.pdf [--title "Document Title"]
            """)
        default:
            throw ConfigError.message("Unknown argument: \(arg)")
        }
        index += 1
    }

    guard !config.inputPath.isEmpty else {
        throw ConfigError.message("Provide --input")
    }
    guard !config.outputPath.isEmpty else {
        throw ConfigError.message("Provide --output")
    }

    return config
}

func paragraphStyle(spacingBefore: CGFloat = 0, spacingAfter: CGFloat = 8, lineSpacing: CGFloat = 2, headIndent: CGFloat = 0) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.paragraphSpacingBefore = spacingBefore
    style.paragraphSpacing = spacingAfter
    style.lineSpacing = lineSpacing
    style.headIndent = headIndent
    style.firstLineHeadIndent = headIndent
    return style
}

func attributes(font: NSFont, color: NSColor = .black, style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
    [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
}

func normalizeInlineMarkdown(_ text: String) -> String {
    text
        .replacingOccurrences(of: "`", with: "")
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "__", with: "")
        .replacingOccurrences(of: "*", with: "")
}

func makeAttributedString(markdown: String, title: String?) -> NSAttributedString {
    let bodyFont = NSFont.systemFont(ofSize: 11)
    let bodyBold = NSFont.boldSystemFont(ofSize: 11)
    let h1Font = NSFont.boldSystemFont(ofSize: 20)
    let h2Font = NSFont.boldSystemFont(ofSize: 16)
    let h3Font = NSFont.boldSystemFont(ofSize: 13)
    let smallFont = NSFont.systemFont(ofSize: 10)

    let result = NSMutableAttributedString()

    if let title, !title.isEmpty {
        let titleText = NSAttributedString(
            string: "\(title)\n",
            attributes: attributes(font: h1Font, style: paragraphStyle(spacingAfter: 14, lineSpacing: 3))
        )
        result.append(titleText)
    }

    let lines = markdown.components(separatedBy: .newlines)

    for rawLine in lines {
        let line = rawLine.trimmingCharacters(in: .whitespaces)

        if line.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: attributes(font: bodyFont, style: paragraphStyle(spacingAfter: 6))))
            continue
        }

        if line.hasPrefix("# ") {
            let text = normalizeInlineMarkdown(String(line.dropFirst(2)))
            result.append(NSAttributedString(string: "\(text)\n", attributes: attributes(font: h1Font, style: paragraphStyle(spacingBefore: 6, spacingAfter: 12, lineSpacing: 3))))
            continue
        }

        if line.hasPrefix("## ") {
            let text = normalizeInlineMarkdown(String(line.dropFirst(3)))
            result.append(NSAttributedString(string: "\(text)\n", attributes: attributes(font: h2Font, style: paragraphStyle(spacingBefore: 6, spacingAfter: 10, lineSpacing: 3))))
            continue
        }

        if line.hasPrefix("### ") {
            let text = normalizeInlineMarkdown(String(line.dropFirst(4)))
            result.append(NSAttributedString(string: "\(text)\n", attributes: attributes(font: h3Font, style: paragraphStyle(spacingBefore: 4, spacingAfter: 8, lineSpacing: 2))))
            continue
        }

        if line.hasPrefix("- ") {
            let text = "• " + normalizeInlineMarkdown(String(line.dropFirst(2)))
            result.append(NSAttributedString(string: "\(text)\n", attributes: attributes(font: bodyFont, style: paragraphStyle(spacingAfter: 5, lineSpacing: 2, headIndent: 14))))
            continue
        }

        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let prefix = String(line[..<match.upperBound])
            let rest = normalizeInlineMarkdown(String(line[match.upperBound...]))
            result.append(NSAttributedString(string: "\(prefix)\(rest)\n", attributes: attributes(font: bodyFont, style: paragraphStyle(spacingAfter: 5, lineSpacing: 2, headIndent: 18))))
            continue
        }

        if line.hasPrefix("|") && line.hasSuffix("|") {
            let tableLine = normalizeInlineMarkdown(line)
            result.append(NSAttributedString(string: "\(tableLine)\n", attributes: attributes(font: smallFont, style: paragraphStyle(spacingAfter: 4, lineSpacing: 1))))
            continue
        }

        if line.hasPrefix("```") {
            continue
        }

        let baseFont = line.hasSuffix(":") ? bodyBold : bodyFont
        let text = normalizeInlineMarkdown(line)
        result.append(NSAttributedString(string: "\(text)\n", attributes: attributes(font: baseFont, style: paragraphStyle(spacingAfter: 6, lineSpacing: 2))))
    }

    return result
}

func renderPDF(attributedString: NSAttributedString, outputURL: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let paperSize = NSSize(width: 595.2, height: 841.8) // A4
    let margin: CGFloat = 50
    let contentWidth = paperSize.width - margin * 2

    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1000))
    textView.isEditable = false
    textView.isSelectable = false
    textView.drawsBackground = false
    textView.textContainerInset = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
    textView.minSize = NSSize(width: contentWidth, height: 0)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textStorage?.setAttributedString(attributedString)

    guard let textContainer = textView.textContainer,
          let layoutManager = textView.layoutManager else {
        throw ConfigError.message("Failed to initialize text layout")
    }

    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: ceil(usedRect.height) + 20)

    let printInfo = NSPrintInfo()
    printInfo.paperSize = paperSize
    printInfo.topMargin = margin
    printInfo.bottomMargin = margin
    printInfo.leftMargin = margin
    printInfo.rightMargin = margin
    printInfo.horizontalPagination = .automatic
    printInfo.verticalPagination = .automatic
    printInfo.isVerticallyCentered = false
    printInfo.isHorizontallyCentered = false

    let pdfData = NSMutableData()
    let operation = NSPrintOperation.pdfOperation(with: textView, inside: textView.bounds, to: pdfData, printInfo: printInfo)
    operation.showsPrintPanel = false
    operation.showsProgressPanel = false
    guard operation.run() else {
        throw ConfigError.message("Print operation failed")
    }

    try pdfData.write(to: outputURL, options: .atomic)
}

do {
    let config = try parseArgs()
    let inputURL = URL(fileURLWithPath: config.inputPath)
    let outputURL = URL(fileURLWithPath: config.outputPath)
    let markdown = try String(contentsOf: inputURL, encoding: .utf8)
    let fallbackTitle = inputURL.deletingPathExtension().lastPathComponent
    let attributed = makeAttributedString(markdown: markdown, title: config.title ?? fallbackTitle)
    try renderPDF(attributedString: attributed, outputURL: outputURL)
    print("OK\t\(outputURL.path)")
} catch {
    fputs("ERROR\t\(error)\n", stderr)
    exit(1)
}
