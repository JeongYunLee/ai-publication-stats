---
name: markdown-pdf-export
description: Convert local Markdown documents into PDF files using macOS built-in Swift/AppKit tooling. Use when the user wants a Markdown note, survey, report, or design document exported as a PDF without installing external converters.
---

# Markdown PDF Export

Use this skill when a Markdown file in the workspace needs to be turned into a PDF and external tools like `pandoc` or `wkhtmltopdf` are unavailable.

## Workflow

1. Run the bundled Swift script against the target Markdown file.
2. Write the PDF next to the source file or into a requested output path.
3. If needed, render the first page to an image and inspect it.

## Command

```bash
mkdir -p /tmp/swift-module-cache
env SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache \
swift .codex/skills/markdown-pdf-export/scripts/markdown_to_pdf.swift \
  --input design/2026-03-13_revised_survey_instrument.md \
  --output design/2026-03-13_revised_survey_instrument.pdf
```

## Notes

- The script supports headings and list-heavy Markdown well, which fits surveys and notes in this project.
- It uses A4 pages and paginates text automatically.
- If a document uses unusual Markdown features, verify the resulting PDF visually.
