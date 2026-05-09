# Peek

Smarter link previews. Everywhere on your Mac.

Peek is a macOS menu bar app that replaces the raw URL tooltip with a rich preview card. Hover over any link in any app — Mail, Safari, Slack, PDFs — and Peek shows you the page title, a plain-English description, the real destination domain, and a trust signal. No click required.

## What it does

- **System-wide** — works in every native macOS app via the Accessibility API
- **Trust badges** — flags domain mismatches, shortened URLs, and known malicious links
- **Lightweight** — lives in the menu bar, no Dock icon, minimal memory footprint
- **Private** — all results cached locally, no accounts or telemetry

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (prompted on first launch)

## Building locally

```bash
git clone git@github.com:boatnoah/peek.git
cd peek
xcodebuild -project peek.xcodeproj -scheme peek -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Or open `peek.xcodeproj` in Xcode and press `⌘R`.

## Project structure

```
peek/
├── peekApp.swift              # App entry point, menu bar, AppDelegate
├── EventMonitor.swift         # CGEvent tap — detects cursor dwell on links
├── URLExtractor.swift         # Accessibility API — extracts URL from hovered element
├── RedirectResolver.swift     # Follows redirects, strips UTM params, detects shorteners
├── SafeBrowsingClient.swift   # Google Safe Browsing API lookup
├── MetadataFetcher.swift      # Fetches og:title, og:description, favicon
├── LLMProvider.swift          # LLM-agnostic protocol + GeminiProvider implementation
├── TrustEvaluator.swift       # Rule-based trust badge logic
├── EnrichmentPipeline.swift   # Orchestrates all enrichment steps
├── PreviewCache.swift         # In-memory LRU cache (200 entries)
└── PreviewCardController.swift # NSPanel overlay card UI
```

## Status

Under active development. See the [open issues](https://github.com/boatnoah/peek/issues) for what's being built next.
