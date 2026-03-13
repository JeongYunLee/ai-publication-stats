import Foundation
import PDFKit

struct Config {
    var inputFiles: [String] = []
    var inputDir: String?
    var outputDir: String = "reviews/article_texts"
    var limitPages: Int?
    var overwrite = false
}

enum ArgError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text):
            return text
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
            guard index < args.count else { throw ArgError.message("Missing value for --input") }
            config.inputFiles.append(args[index])
        case "--input-dir":
            index += 1
            guard index < args.count else { throw ArgError.message("Missing value for --input-dir") }
            config.inputDir = args[index]
        case "--output-dir":
            index += 1
            guard index < args.count else { throw ArgError.message("Missing value for --output-dir") }
            config.outputDir = args[index]
        case "--limit-pages":
            index += 1
            guard index < args.count, let value = Int(args[index]), value > 0 else {
                throw ArgError.message("Invalid value for --limit-pages")
            }
            config.limitPages = value
        case "--overwrite":
            config.overwrite = true
        case "--help":
            throw ArgError.message("""
            Usage:
              swift extract_pdf_text.swift --input file.pdf [--output-dir dir]
              swift extract_pdf_text.swift --input-dir articles [--output-dir dir] [--limit-pages N] [--overwrite]
            """)
        default:
            config.inputFiles.append(arg)
        }
        index += 1
    }

    if config.inputFiles.isEmpty && config.inputDir == nil {
        throw ArgError.message("Provide at least one --input file or --input-dir")
    }

    return config
}

func discoverPDFs(inputDir: String) throws -> [URL] {
    let fm = FileManager.default
    let dirURL = URL(fileURLWithPath: inputDir)
    guard let enumerator = fm.enumerator(at: dirURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        throw ArgError.message("Cannot read input directory: \(inputDir)")
    }

    var files: [URL] = []
    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension.lowercased() == "pdf" {
            files.append(fileURL)
        }
    }
    return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

func outputURL(for inputURL: URL, outputDir: String) -> URL {
    let base = inputURL.deletingPathExtension().lastPathComponent + ".txt"
    return URL(fileURLWithPath: outputDir).appendingPathComponent(base)
}

func extractText(from inputURL: URL, limitPages: Int?) throws -> (pageCount: Int, text: String) {
    guard let document = PDFDocument(url: inputURL) else {
        throw ArgError.message("Failed to open PDF: \(inputURL.path)")
    }

    let totalPages = document.pageCount
    let maxPages = limitPages.map { min($0, totalPages) } ?? totalPages
    var chunks: [String] = []

    chunks.append("# Source")
    chunks.append(inputURL.path)
    chunks.append("")
    chunks.append("# PageCount")
    chunks.append(String(totalPages))
    chunks.append("")

    for pageIndex in 0..<maxPages {
        let pageNumber = pageIndex + 1
        let pageText = document.page(at: pageIndex)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        chunks.append("## Page \(pageNumber)")
        chunks.append(pageText)
        chunks.append("")
    }

    return (totalPages, chunks.joined(separator: "\n"))
}

do {
    let config = try parseArgs()
    let fm = FileManager.default
    try fm.createDirectory(atPath: config.outputDir, withIntermediateDirectories: true)

    var inputURLs = config.inputFiles.map { URL(fileURLWithPath: $0) }
    if let inputDir = config.inputDir {
        inputURLs.append(contentsOf: try discoverPDFs(inputDir: inputDir))
    }

    let normalized = Array(Set(inputURLs.map { $0.standardizedFileURL })).sorted {
        $0.path.localizedStandardCompare($1.path) == .orderedAscending
    }

    if normalized.isEmpty {
        throw ArgError.message("No PDF files found")
    }

    for inputURL in normalized {
        let outURL = outputURL(for: inputURL, outputDir: config.outputDir)
        if fm.fileExists(atPath: outURL.path) && !config.overwrite {
            print("SKIP\t\(inputURL.lastPathComponent)\toutput exists")
            continue
        }

        let result = try extractText(from: inputURL, limitPages: config.limitPages)
        try result.text.write(to: outURL, atomically: true, encoding: .utf8)
        print("OK\t\(inputURL.lastPathComponent)\tpages=\(result.pageCount)\tout=\(outURL.path)")
    }
} catch {
    fputs("ERROR\t\(error)\n", stderr)
    exit(1)
}
