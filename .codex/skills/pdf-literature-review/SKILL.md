---
name: pdf-literature-review
description: Extract body text from local PDF papers and review their relevance for the AI publishing survey project. Use when the user wants collected articles checked, summarized, classified, or turned into reusable review records.
---

# PDF Literature Review

Use this skill when the workspace contains local PDF papers that need to be extracted and reviewed for the AI publishing research project.

## Workflow

1. Persist any review output under `reviews/`.
2. Extract PDF body text with the bundled Swift script. It uses macOS `PDFKit`, so it does not require external Python packages.
3. Review extracted text against the rubric in [references/review_rubric.md](references/review_rubric.md).
4. Write or update a dated review record in `reviews/` with:
   - relevance class: `direct`, `adjacent`, or `low`
   - research question, variables, methods, key findings
   - how the paper helps the current survey or why it should be excluded
5. If the survey design is part of the task, also check whether the current literature supports:
   - the main dependent variable
   - group-difference hypotheses
   - pre/post explanation design

## Extraction command

Run from the workspace root:

```bash
mkdir -p /tmp/swift-module-cache
env SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/swift-module-cache \
swift .codex/skills/pdf-literature-review/scripts/extract_pdf_text.swift \
  --input-dir articles \
  --output-dir reviews/article_texts \
  --overwrite
```

Useful variants:

- One file only: add `--input path/to/file.pdf`
- Quick skim: add `--limit-pages 2`

## Notes for this project

- The current study excludes minors. If the survey design is being reviewed, remove `10대` or add an adult-only screening item.
- Keep literature review notes concrete. Prefer per-paper decisions over generic summaries.
- If a paper is not directly about AI publishing, keep it only when the method, construct, or comparison logic clearly transfers.
