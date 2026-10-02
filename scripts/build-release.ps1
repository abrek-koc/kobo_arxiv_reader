$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -Raw (Join-Path $repo 'package.json') | ConvertFrom-Json).version
$dist = Join-Path $repo 'dist'
[System.IO.Directory]::CreateDirectory($dist) | Out-Null
$archive = Join-Path $dist ("kobo-arxiv-reader-" + $version + ".zip")
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [System.IO.File]::Open($archive, [System.IO.FileMode]::Create)
$zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in @('_meta.lua', 'core.lua', 'main.lua')) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $repo ("arxivreader.koplugin/" + $name)), (".adds/koreader/plugins/arxivreader.koplugin/" + $name)) | Out-Null
    }
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $repo 'patches/2-arxivreader-shortcut.lua'), '.adds/koreader/patches/2-arxivreader-shortcut.lua') | Out-Null
    foreach ($name in @('README.md', 'LICENSE', 'docs/INSTALLATION.md', 'docs/USAGE.md', 'docs/DEVELOPMENT.md', 'docs/ROADMAP.md')) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $repo $name), $name) | Out-Null
    }
} finally {
    $zip.Dispose()
    $stream.Dispose()
}
Write-Output $archive
