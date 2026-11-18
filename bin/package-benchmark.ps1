param([Parameter(Mandatory)][string]$Csv)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repo = Split-Path -Parent $PSScriptRoot
$csvFile = Get-Item -LiteralPath $Csv
$rows = @(Import-Csv -LiteralPath $csvFile.FullName)
$first = $rows[0]
$bundle = $csvFile.Directory.FullName
$raw = Join-Path $repo "output/benchmarks/$($first.dataset)/$($first.run)"
$archive = Join-Path $bundle "$($first.dataset)-$($first.run).zip"
if (Test-Path -LiteralPath $archive) { throw "Archive already exists: $archive" }
$entries = [ordered]@{ 'results.csv' = $csvFile.FullName }
foreach ($row in $rows) {
    $trial = "p$([int]$row.sample_pct)-bp$([int]$row.minsup_bp)/rep-$([int]$row.rep)"
    foreach ($engine in @('scan', 'hash-tree', 'spmf')) {
        foreach ($ext in @('txt', 'log')) {
            $name = "$trial/$engine.$ext"
            $entries[$name] = (Get-Item -LiteralPath (Join-Path $raw $name) -ErrorAction Stop).FullName
        }
    }
}
$png = Join-Path $raw 'figures.png'
if (Test-Path -LiteralPath $png -PathType Leaf) { $entries['figures.png'] = $png }
$stream = [IO.File]::Open("$archive.partial", [IO.FileMode]::CreateNew)
try {
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($entry in $entries.GetEnumerator()) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $entry.Value, $entry.Key)
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
[IO.File]::Move("$archive.partial", $archive)
Write-Output $archive
