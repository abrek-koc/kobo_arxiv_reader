# Installation, updates, and removal

## Requirements

- A Kobo with KOReader installed. The development target is Clara BW, KOReader v2026.07.1.
- Wi-Fi for searches and downloads.
- KOReader's native HTML balancer and ZIP writer (bundled with the development target).
- USB access to the device's visible storage. Enable hidden-folder display to see .adds.

## Manual installation

Copy the repository's arxivreader.koplugin directory to:

```text
<Kobo drive>/
  .adds/
    koreader/
      plugins/
        arxivreader.koplugin/
          _meta.lua
          core.lua
          main.lua
          scientific.lua
          assets/
            STIXTwoMath-Regular.otf
            OFL.txt
```

Avoid nesting arxivreader.koplugin inside another copy of that folder.
Restart KOReader after safely ejecting the device. Check its plugin manager if the entry does not appear.

## Optional front-page shortcut

Copy patches/2-arxivreader-shortcut.lua into .adds/koreader/patches/.
It adds a row only to KOReader's configured home folder, preserving ordinary file and folder behavior.
It does not add a NickelMenu entry or change the stock Kobo home page.

Existing custom home patches may already provide an arXiv shortcut. In that case, omit this optional file. In particular, the original device-specific 2-rakuyomi-shortcut.lua used during development already contains an arXiv row. That combined patch is deliberately not included in this repository.

## Updating

Close KOReader and back up settings/arxivreader.lua and its backups, Articles/, and document metadata.
Replace the plugin files and assets/ folder inside plugins/arxivreader.koplugin with the new version.
Replace the optional shortcut only if you installed this repository's shortcut.
Eject and restart. Installation does not require deleting saved data.

## Uninstall

Disable arXiv Reader in KOReader's plugin manager and restart.
Remove only .adds/koreader/plugins/arxivreader.koplugin and, if installed, .adds/koreader/patches/2-arxivreader-shortcut.lua.
Keep Articles/, settings/arxivreader.lua, and document metadata to retain papers and notes.
Do not remove the entire .adds directory.
