# Development

## Layout

- arxivreader.koplugin/: installable Lua plugin.
- patches/: optional standalone KOReader home-folder shortcut.
- tests/: portable syntax and mocked behavior checks.
- scripts/build-release.ps1: builds a ZIP with Kobo installation paths.
- .github/workflows/test.yml: runs tests on Linux and Windows.

The plugin reuses KOReader's UI widgets, network manager, settings, reader engine, HTML balancer, and ZIP writer. scientific.lua builds EPUB 3 directly.
It must be launched inside KOReader. Running main.lua with a desktop Lua interpreter will not supply these dependencies.

The download directory is currently Kobo-specific. Metadata/content fetches use cancellable subprocesses and a three-second minimum interval within an app instance. Figures use the same cancellable fetch and rate pacing. Missing or invalid figures abort conversion.

## Tests

Run npm ci, then npm test. The lockfile pins the development dependencies.
The test runner resolves source paths relative to the repository and makes no live network requests.

The regression suite supplies the path field injected by KOReader's plugin loader. Do not name plugin methods path: the loader overwrites that name with a directory string.
Syntax checks target Lua 5.1; behavioral tests use Fengari (Lua 5.3) with mocked KOReader modules. Neither replaces a real LuaJIT/device test.

## Device acceptance checklist

1. Install on a Kobo, restart KOReader, and open the app from Tools.
2. If installed, check the home shortcut; verify normal file taps and long presses still work.
3. Search 2402.08954, save it, and restart to verify library persistence.
4. Tap Read before downloading; confirm the missing-file message.
5. Download EPUB and inspect headings, figures, equations, and page turning.
6. Download PDF, open it, and verify reading position after closing/reopening.
7. Add a multiline paper note, restart, and verify the note.
8. Add a passage highlight/note and verify KOReader retains it.
9. Export notebook Markdown and inspect the file over USB.
10. Disable Wi-Fi and read a downloaded document from My library.
11. Browse subjects, page results, cancel a fetch, and try a paper without HTML.
12. Confirm removal of a library entry leaves its downloaded document intact.

These checks are pending for the packaged release; do not describe mocked tests as full hardware verification.

## Release

Run tests and scripts/build-release.ps1 on Windows.
The script includes only the plugin and optional patch under .adds/koreader, plus the README, documentation, and LICENSE. The plugin includes STIX Two Math and its OFL license.
dist/ is ignored by Git. Rebuild it after changing source or package version.

## EAGLE-3 regression

Run npm run review:eagle to fetch 2503.01840v3 and its artwork, compare source assets and every split-table cell, and build dist/2503.01840v3.science-v3.epub. Downloads are cached under dist/ and sequentially paced. Do not commit or redistribute cached paper content with the source repository.

Run npm run review:eagle -- --screenshots with Microsoft Edge installed to capture a small-screen browser preview and verify image decoding and table widths. This uses parse5 for HTML balancing on the PC; it does not execute KOReader\'s native balancer or renderer.

npm test remains offline and includes a synthetic SVG-object, merged-header, and rowspan regression fixture.
