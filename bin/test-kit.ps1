param(
    [string]$Julia = 'julia',
    [string]$KitPath = '',
    [string]$OutputDirectory = '',
    [switch]$Explain,
    [ValidateRange(0, 2147483647)]
    [int]$Warmup = 0
)

# PowerShell orchestrates the supplied JSON manifest; mining runs in Julia.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $KitPath) { $KitPath = Join-Path $projectRoot 'Apriori_Test_Kit_8_Datasets' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'output/test-kit' }
$KitPath = (Resolve-Path -LiteralPath $KitPath -ErrorAction Stop).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not (Get-Command $Julia -ErrorAction SilentlyContinue)) {
    throw 'Julia not found. Pass -Julia with the full path to julia.exe.'
}
$parsedCases = Get-Content -LiteralPath (Join-Path $KitPath 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = @($parsedCases)
if ($cases.Count -eq 0) { throw 'The manifest contains no test cases.' }
$batchId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '_' + [Guid]::NewGuid().ToString()
$batchDirectory = Join-Path (Join-Path $OutputDirectory 'runs') $batchId
if (Test-Path -LiteralPath $batchDirectory) { throw "Batch directory already exists: $batchDirectory" }
[IO.Directory]::CreateDirectory($batchDirectory) | Out-Null

function Read-Patterns([string]$Path) {
    $patterns = @{}
    $lineNumber = 0
    foreach ($raw in @(Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $lineNumber++
        $line = $raw.Trim()
        if (-not $line -or $line -match '^[#%@]') { continue }
        if ($line -notmatch '^(.+?)\s+#SUP:\s*(\d+)\s*$') {
            throw "${Path}:${lineNumber}: invalid SPMF output"
        }
        $support = [long]$Matches[2]
        $items = @($Matches[1] -split '\s+' | ForEach-Object { [long]$_ } | Sort-Object)
        if ($items.Count -eq 0 -or @($items | Select-Object -Unique).Count -ne $items.Count -or $items[0] -lt 0) {
            throw "${Path}:${lineNumber}: invalid itemset"
        }
        $key = $items -join ' '
        if ($patterns.ContainsKey($key)) { throw "${Path}:${lineNumber}: duplicate itemset $key" }
        $patterns[$key] = $support
    }
    return $patterns
}

$results = @()
foreach ($case in $cases) {
    if ([string]$case.name -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid case name in manifest.' }
    $expected = Read-Patterns (Join-Path $KitPath ([string]$case.expected))
    if ($expected.Count -ne [int]$case.expected_itemsets) { throw "Expected count disagrees with manifest: $($case.name)" }
    foreach ($counter in @('scan', 'hash-tree')) {
        $counterDirectory = Join-Path $batchDirectory $counter
        [IO.Directory]::CreateDirectory($counterDirectory) | Out-Null
        $caseDirectory = Join-Path $counterDirectory ([string]$case.name)
        $output = Join-Path $caseDirectory 'itemsets.txt'
        $arguments = @('--startup-file=no', "--project=$projectRoot", (Join-Path $projectRoot 'bin/apriori.jl'),
            '--input', (Join-Path $KitPath ([string]$case.dataset)), '--output', $output,
            '--minsup', [string]$case.minsup_relative, '--counter', $counter,
            '--report-dir', $caseDirectory, '--warmup', [string]$Warmup, '--quiet')
        if ($Explain) {
            $explanation = Join-Path $caseDirectory 'trace.txt'
            $arguments += @('--explain-file', $explanation)
        }
        $processWatch = [Diagnostics.Stopwatch]::StartNew()
        & $Julia @arguments
        $processWatch.Stop()
        if ($LASTEXITCODE -ne 0) { throw "Julia failed: $($case.name) / $counter (exit $LASTEXITCODE)" }
        $timings = @(Import-Csv -LiteralPath (Join-Path $caseDirectory 'timings.csv'))
        $miningRows = @($timings | Where-Object { $_.phase -eq 'mining_total' })
        $cliRows = @($timings | Where-Object { $_.phase -eq 'cli_total' })
        if ($miningRows.Count -ne 1 -or $cliRows.Count -ne 1) {
            throw "Missing timing totals: $($case.name) / $counter"
        }
        $culture = [Globalization.CultureInfo]::InvariantCulture
        $miningMs = [double]::Parse($miningRows[0].elapsed_ms, $culture)
        $cliMs = [double]::Parse($cliRows[0].elapsed_ms, $culture)
        $actual = Read-Patterns $output
        $missing = @($expected.Keys | Where-Object { -not $actual.ContainsKey($_) }).Count
        $extra = @($actual.Keys | Where-Object { -not $expected.ContainsKey($_) }).Count
        $wrong = @($expected.Keys | Where-Object { $actual.ContainsKey($_) -and $actual[$_] -ne $expected[$_] }).Count
        $status = if (($missing + $extra + $wrong) -eq 0) { 'PASS' } else { 'FAIL' }
        $results += [pscustomobject]@{
            Dataset = $case.name; Counter = $counter; Minsup = $case.minsup_relative
            Expected = $expected.Count; Actual = $actual.Count
            Missing = $missing; Extra = $extra; WrongSupport = $wrong; Status = $status
            MiningMs = $miningMs; CliMs = $cliMs; ProcessWallMs = $processWatch.Elapsed.TotalMilliseconds
            ReportPath = Join-Path $caseDirectory 'report.txt'; RunId = $miningRows[0].run_id
            ExplanationEnabled = [bool]$Explain; WarmupRuns = $Warmup
        }
        Write-Output "$($case.name) / ${counter}: $status; MiningMs=$([Math]::Round($miningMs, 3)); ProcessWallMs=$([Math]::Round($processWatch.Elapsed.TotalMilliseconds, 3))"
    }
}

$report = Join-Path $batchDirectory 'results.csv'
$results | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8
$results | Format-Table Dataset, Counter, Minsup, Expected, Actual, Status, MiningMs, ProcessWallMs -AutoSize
Write-Output "Report: $report"
Write-Output "Run bundles: $batchDirectory"
Write-Output "TotalMiningMs: $(($results | Measure-Object -Property MiningMs -Sum).Sum)"
Write-Output "TotalProcessWallMs: $(($results | Measure-Object -Property ProcessWallMs -Sum).Sum)"
Write-Output 'Mining and process totals have different scopes; process time includes Julia startup and report writing.'
$failed = @($results | Where-Object { $_.Status -ne 'PASS' }).Count
Write-Output "Passed: $($results.Count - $failed)/$($results.Count)"
if ($failed -gt 0) { exit 1 }
