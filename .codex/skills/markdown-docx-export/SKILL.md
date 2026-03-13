---
name: markdown-docx-export
description: Convert local Markdown documents into DOCX files using macOS built-in Swift/AppKit plus textutil. Use when the user wants a Markdown note, survey, or report exported as an editable Word document without installing pandoc.
---

# Markdown DOCX Export

Use this skill when a Markdown file in the workspace needs to be converted into an editable `.docx` and `pandoc` is not available.

## Workflow

1. Convert Markdown into a styled attributed document with the bundled Swift script.
2. Write a temporary RTF file.
3. Convert that RTF into `.docx` using macOS `textutil`.
4. Verify the resulting `.docx` by extracting plain text back out if needed.

## Command

```bash
mkdir -p /tmp/swift-module-cache
env SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache \
swift .codex/skills/markdown-docx-export/scripts/markdown_to_docx.swift \
  --input design/2026-03-13_revised_survey_instrument.md \
  --output design/2026-03-13_revised_survey_instrument.docx \
  --title "AI 출판 제도 인식 조사 설문지"
```

## Notes

- This path preserves headings and list-heavy documents better than plain-text conversion.
- It is appropriate for surveys, notes, and structured reports.
- If a Markdown file contains advanced tables or code fences, verify the final Word document visually.
