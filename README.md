# arXiv Reader for Kobo

Browse arXiv, save papers, read offline, and keep research notes on a Kobo running KOReader.

**Early version.** Developed against KOReader v2026.07.1 on a Kobo Clara BW. Automated tests cover core logic and mocked UI integration; full on-device acceptance is still pending. This is a KOReader plugin, not a replacement Kobo firmware or a desktop application.

## Features

- Search by keywords, author/title queries, arXiv IDs, or abstract/HTML/PDF links.
- Browse subjects, newest first, with paginated results.
- Save abstracts and metadata to a local library.
- Build scientific EPUB 3 editions with MathML, embedded STIX Two Math, full-resolution figures, and section navigation.
- Download original PDFs and read either format offline.
- Track To read / Reading / Finished status.
- Write multiline paper notes and export them as Markdown.
- Use KOReader's native highlights, passage notes, and reading position.
- Optional shortcut in KOReader's home-folder listing.

No account, separate server, or Node.js runtime is needed on the Kobo.

## Install

1. Install [KOReader](https://github.com/koreader/koreader) on your Kobo first. This repository does not install KOReader.
2. Connect the Kobo to your computer by USB.
3. Copy **the entire** `arxivreader.koplugin` folder, including `scientific.lua` and the `assets/` font folder, into `.adds/koreader/plugins/` on the Kobo.
4. Optionally copy `patches/2-arxivreader-shortcut.lua` into `.adds/koreader/patches/`. Create the patches folder if needed.
5. Safely eject the device and restart KOReader.
6. Open **Tools > More tools > arXiv Reader** (the menu grouping can vary), or tap the optional **arXiv Reader** home-folder row.

The shortcut is in KOReader's file browser, not the stock Kobo home screen. Do not install it if another custom patch already provides the same shortcut; see [installation details](docs/INSTALLATION.md).

The scientific EPUB builder uses KOReader's native HTML balancer and ZIP writer directly. The news downloader plugin is no longer required.

## Scientific reading (0.3.0)

Scientific EPUBs preserve the paper's mathematical structure and provide a layout designed for a small e-ink screen:

- **Equations:** original MathML is preserved, with STIX Two Math embedded for mathematical symbols and layout. No separate font installation is needed.
- **Graphs and diagrams:** source image resolution is retained while figures fit the page. Long-press a figure to open KOReader's zoom/pan viewer. Inline SVG artwork and SVG figures embedded as HTML objects are packaged as zoomable vector images.
- **Tables and captions:** recognized wide data tables are split into groups of up to four columns with repeated row labels and merged headers. The original layouts remain in an appendix. Captions and reference targets are retained; unrecognized table structures are left intact.
- **Navigation:** section headings appear in the EPUB table of contents.
- **Complete downloads:** missing or invalid figures stop conversion instead of silently producing a book with missing artwork.

Keep **embedded styles and fonts enabled** in KOReader. For wide equations or tables, rotate to landscape or reduce text size. Rendering still depends on KOReader's engine and the quality of arXiv's HTML conversion; the original PDF remains available for comparison.

### Upgrade previously downloaded papers

1. Replace the plugin folder with this version, including its assets, and restart KOReader.
2. Open a saved paper and choose **Download EPUB** again.
3. Choose **Read EPUB** to open the new scientific edition.

New editions use `Articles/<arxiv-id>.science-v3.epub`. Existing `.science.epub` and `.epub` files and their annotations are kept. **Read EPUB** prefers the scientific edition when present, and otherwise opens the old EPUB. Annotations do not transfer between editions; open the old file through KOReader's file browser to access them.

See the [scientific reading guide](docs/SCIENTIFIC_READING.md) for details, limitations, and font provenance.

## First paper

1. Turn on Wi-Fi and open **Search papers**.
2. Enter `2402.08954`, a paper URL, or a query such as `au:Einstein AND ti:gravity`.
3. Open a result and tap **Save to library**.
4. Choose **Download EPUB** or **Download PDF**, then **Read** when offered.
5. Later, open **My library**, select the paper, and choose **Read EPUB/PDF**.

**Save to library saves metadata, not the full paper.** Download the chosen format before tapping Read. HTML is not available for every paper; PDF is the fallback.

See the [user guide](docs/USAGE.md) for notes, exports, backups, and troubleshooting.

## Data and privacy

Downloaded papers live in `/mnt/onboard/Articles/`. Paper notes and the library live in KOReader's `settings/arxivreader.lua`. Nothing from your personal library is included in this repository.

Searches contact arXiv; EPUB creation also retrieves article figures. There is no project-operated service or telemetry. The code uses the installed KOReader networking and conversion components.

## Known limits

- Kobo storage path is currently fixed to `/mnt/onboard/Articles`; other KOReader platforms are not supported by this version.
- Very wide equations and tables may still need landscape orientation or smaller text. Mathematical rendering and touch zoom require on-device validation; automated tests do not establish visual correctness.
- Response limits: 2 MiB metadata, 15 MiB HTML, 40 MiB PDF. Figures are limited to 20 MiB each and 100 MiB total. Failed or unsupported figures stop conversion.
- The last search page is cached; there is no full offline search index.
- Paper notes and document highlights are separate. EPUB/PDF annotations and different paper versions do not merge.
- No cloud sync, background subscriptions, or phone link receiver yet.

## iPhone sharing idea

A future on-demand receiver on the Kobo could accept arXiv links from an iOS Share Sheet Shortcut over the same Wi-Fi. **This is not implemented.** There is currently no endpoint or iPhone Shortcut to configure. See [the roadmap](docs/ROADMAP.md).

## Development

Install Node.js 20 or newer on your computer, then:

```sh
npm ci
npm test
```

Node is only for development tests. Tests cover paper/library behavior, the home shortcut, scientific EPUB packaging, math preservation, figure handling, and failure cleanup. They use Lua 5.1 syntax validation and a mocked Lua runtime; they do not emulate KOReader's native libraries or e-ink display.

On Windows, build a USB-ready release ZIP:

```powershell
powershell -NoProfile -File scripts/build-release.ps1
```

Output: `dist/kobo-arxiv-reader-0.3.0.zip`. The archive contains a `.adds/koreader/` tree with the plugin and optional shortcut. Inspect existing patches before extracting it onto a device.

The optional `npm run review:eagle` command downloads EAGLE-3 (2503.01840v3), checks all source figures and split-table values, and builds a private sample EPUB under `dist/`. Add `-- --screenshots` for an installed Microsoft Edge browser preview. Browser rendering is not KOReader hardware validation.

See [development and device checks](docs/DEVELOPMENT.md).

## Publish to GitHub

Create an empty GitHub repository, then run these commands from this folder, substituting your GitHub account:

```sh
git add .
git commit -m "Initial arXiv Reader release"
git remote add origin https://github.com/YOUR-USERNAME/kobo-arxiv-reader.git
git push -u origin main
```

If this checkout already has an `origin` remote, use that remote instead of adding it again. Attach the ZIP to a GitHub release if you want a downloadable install package.

## License and acknowledgements

Plugin code is MIT; see [LICENSE](LICENSE). The bundled STIX Two Math font uses the [SIL Open Font License](arxivreader.koplugin/assets/OFL.txt). The font and its license are also included in generated EPUBs. KOReader and its bundled dependencies retain their own licenses and are not distributed here. Uses arXiv's public metadata and article services. Papers retain their respective copyrights and licenses.

Independent project; not affiliated with or endorsed by arXiv or Kobo.
