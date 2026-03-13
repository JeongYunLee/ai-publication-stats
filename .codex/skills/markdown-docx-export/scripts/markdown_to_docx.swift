import Foundation
import AppKit

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
              swift markdown_to_docx.swift --input source.md --output output.docx [--title "Document Title"]
            """)
        default:
            throw ConfigError.message("Unknown argument: \(arg)")
        }
        index += 1
    }

    guard !config.inputPath.isEmpty else { throw ConfigError.message("Provide --input") }
    guard !config.outputPath.isEmpty else { throw ConfigError.message("Provide --output") }
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

func attributes(font: NSFont, style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
    [
        .font: font,
        .foregroundColor: NSColor.black,
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
        result.append(NSAttributedString(string: "\(title)\n", attributes: attributes(font: h1Font, style: paragraphStyle(spacingAfter: 14, lineSpacing: 3))))
    }

    for rawLine in markdown.components(separatedBy: .newlines) {
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
            result.append(NSAttributedString(string: "\(normalizeInlineMarkdown(line))\n", attributes: attributes(font: smallFont, style: paragraphStyle(spacingAfter: 4, lineSpacing: 1))))
            continue
        }
        if line.hasPrefix("```") {
            continue
        }

        let font = line.hasSuffix(":") ? bodyBold : bodyFont
        result.append(NSAttributedString(string: "\(normalizeInlineMarkdown(line))\n", attributes: attributes(font: font, style: paragraphStyle(spacingAfter: 6, lineSpacing: 2))))
    }

    return result
}

func runTextUtilConvert(rtfURL: URL, docxURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
    process.arguments = ["-convert", "docx", rtfURL.path, "-output", docxURL.path]

    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? "textutil conversion failed"
        throw ConfigError.message(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

do {
    let config = try parseArgs()
    let inputURL = URL(fileURLWithPath: config.inputPath)
    let outputURL = URL(fileURLWithPath: config.outputPath)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let markdown = try String(contentsOf: inputURL, encoding: .utf8)
    let title = config.title ?? inputURL.deletingPathExtension().lastPathComponent
    let attributed = makeAttributedString(markdown: markdown, title: title)

    let fullRange = NSRange(location: 0, length: attributed.length)
    let rtfData = try attributed.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    let tempRTF = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("rtf")
    try rtfData.write(to: tempRTF, options: .atomic)
    defer { try? FileManager.default.removeItem(at: tempRTF) }

    try runTextUtilConvert(rtfURL: tempRTF, docxURL: outputURL)
    print("OK\t\(outputURL.path)")
} catch {
    fputs("ERROR\t\(error)\n", stderr)
    exit(1)
}
