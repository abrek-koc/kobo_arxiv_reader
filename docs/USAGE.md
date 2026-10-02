# Using arXiv Reader

## Find and save

Search accepts keywords, an arXiv identifier (including legacy IDs), an abstract/HTML/PDF URL, or arXiv query syntax.
Examples: 2402.08954, https://arxiv.org/abs/2402.08954, au:Einstein AND ti:gravity.
If a copied URL has tracking parameters or a fragment, remove them or enter the plain identifier.

Browse subjects lists recent papers. Select a title to see authors, publication date, abstract, source link, and actions.
Save to library retains metadata locally. Last search (offline) shows the last fetched page; fetching other pages still needs Wi-Fi.

## Download and read

Choose Download EPUB for a scientific EPUB with native MathML, a math font, full-resolution artwork, and section navigation; or Download PDF for original layout.

Download EPUB again to create <id>.science-v3.epub. Old <id>.science.epub and <id>.epub files and their annotations are preserved. Read EPUB prefers the scientific edition. See [scientific reading](SCIENTIFIC_READING.md) for zoom and layout controls.
Recognized wide tables are split into narrow column groups with repeated labels. An Original layout link opens the retained table in the appendix.

A successful download offers Read now. Subsequently use My library ? paper ? Read EPUB/PDF.
The formats are downloaded separately. Missing files produce a Download first message.

Opening a paper marks it Reading. Use Reading status to mark it Finished or To read.
Existing files are not overwritten when you press Download again.

## Notes

Paper notes opens a multiline notebook for the selected paper/version. Saving a note also saves the paper to the library.
My notes lists papers with nonempty notebook text.
Export notes writes Articles/Notes/<arxiv-id>.md; exporting again replaces that exported copy.

To annotate passages, open a downloaded document, long-press text, and select KOReader's Highlight or Add note.
Those passage annotations belong to KOReader document metadata, not to the app's paper notebook.
Use KOReader's Export highlights tool for passage annotations.
EPUB and PDF annotations are separate, as are different versions of a paper.

## Files and backups

| Data | Kobo location |
| --- | --- |
| Downloaded papers | Articles/<arxiv-id>.science-v3.epub or .pdf (legacy .epub files retained) |
| Exported paper notebooks | Articles/Notes/<arxiv-id>.md |
| Saved library, notebooks, last results | .adds/koreader/settings/arxivreader.lua and its backup |
| Passage annotations and reading position | KOReader document metadata, typically .sdr folders, depending on KOReader settings |

Back up all of these; Markdown exports alone do not preserve document highlights.
Remove from library asks for confirmation and removes the saved entry and its notebook. Downloaded files and KOReader passage annotations remain.

## Troubleshooting

- **No menu entry:** verify folder nesting, enable the plugin, and restart KOReader.
- **No home shortcut:** install the optional patch and navigate to KOReader's configured home folder. Other directories intentionally have no shortcut.
- **Read says download first:** saving a paper only saves metadata. Download that format first.
- **No HTML / conversion fails:** try PDF. Some papers have no usable HTML.
- **Incorrect equations or layout:** compare with the PDF; HTML conversion is not guaranteed to reproduce every scientific layout.
- **Network error:** check Wi-Fi and retry later. Avoid rapid retries if arXiv is limiting requests.
- **Large PDF:** files above 40 MiB require manual transfer. Use the exact filename/version shown by the paper's arXiv ID if you want the app's Read action to find it.
- **Crash mentioning method 'path':** update all plugin files. Version 0.1.0 includes the fix for KOReader's reserved plugin-directory field.

For bug reports, include the KOReader version, device model, steps, paper ID, and relevant crash.log excerpt. Remove personal notes and unrelated reading history before sharing logs.
