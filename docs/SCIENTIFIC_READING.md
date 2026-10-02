# Scientific reading

Version 0.3.0 uses a dedicated EPUB 3 builder.

## Improvements
- Preserves original MathML, including fractions, roots, matrices, and annotations.
- Embeds STIX Two Math for mathematical glyphs and layout.
- Removes fixed browser display dimensions while keeping figure source pixels.
- Packages inline SVG and external SVG object figures as zoomable image assets.
- Splits recognized wide tables into groups of up to four columns, expanding merged row labels and repeating headers. Original layouts are retained in an appendix; unsupported structures stay unchanged.
- Preserves captions, table cells, source IDs, and internal reference targets.
- Generates a section table of contents in EPUB 3 and NCX formats.
- Downloads each distinct figure once. Missing/invalid figures abort conversion, and disk-write failures discard the partial file.

## Upgrade
Restart KOReader, open a saved paper, and choose Download EPUB again.
The builder creates Articles/<id>.science-v3.epub. Old <id>.science.epub and <id>.epub files and annotations are kept.
Read EPUB prefers the scientific edition. To see old annotations, open the old file through KOReader's file browser; annotations do not transfer.

## Reading
Keep embedded styles and fonts enabled.
Use the table of contents for section jumps. Long-press a graph for KOReader's zoom/pan viewer.
For wide equations or tables, use landscape orientation or a smaller text size.

This improves conversion, not the underlying renderer. Native MathML and complex scientific layouts still depend on KOReader.
A six-inch screen cannot fit every wide expression at a comfortable size. Compare ambiguous content against the PDF.
Equations are not rasterized or rewritten. Unsupported image formats currently require PDF fallback.

## Validation
Automated tests cover preserved mathematics, namespace handling, captions, table content, SVG extraction, figure deduplication, font packaging, navigation, cancellation, invalid downloads, and disk-write failures.
Generated package XML is checked for well-formedness during development.
The EAGLE-3 regression checks all 10 source image elements and cell/header parity for three wide tables. All 10 packaged images decoded in a 536-pixel-wide desktop browser preview.
Final e-ink appearance and touchscreen zoom still require device acceptance testing.

## Font provenance
Unmodified STIX Two Math from release v2.13b171:
https://github.com/stipub/stixfonts/tree/v2.13b171

Source archive:
https://raw.githubusercontent.com/stipub/stixfonts/v2.13b171/zipfiles/static_otf.zip

OTF SHA-256:
3a5f3f26f40d5698b3c62dd085d48d6663696a3f80825aab8b553d5097518e8c

The font's SIL Open Font License is in assets/OFL.txt and included in each generated EPUB.
