[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $env:TEMP ("ashen-depths-web-release-{0}" -f ([guid]::NewGuid().ToString("N"))))
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputPath = [IO.Path]::GetFullPath($OutputDir)

function Stop-ReleaseCheck([string]$Message) {
    Write-Host "[RELEASE] verdict=FAIL reason=$Message" -ForegroundColor Red
    exit 1
}

if (Test-Path -LiteralPath $outputPath) {
    if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
        Stop-ReleaseCheck "output_path_is_not_a_directory path=$outputPath"
    }
    if (Get-ChildItem -LiteralPath $outputPath -Force | Select-Object -First 1) {
        Stop-ReleaseCheck "output_directory_is_not_empty path=$outputPath"
    }
} else {
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}

$godot = Get-Command godot_console -ErrorAction SilentlyContinue
if ($null -eq $godot) {
    $godot = Get-Command godot -ErrorAction SilentlyContinue
}
if ($null -eq $godot) {
    Stop-ReleaseCheck "godot_executable_not_found"
}

$indexPath = Join-Path $outputPath "index.html"
Write-Host "[RELEASE] exporting project=$projectRoot output=$indexPath"

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$exportLog = @(& $godot.Source --headless --path $projectRoot --export-release "Web" $indexPath 2>&1 | ForEach-Object { $_.ToString() })
$exportExitCode = $LASTEXITCODE
$ErrorActionPreference = $oldPreference
$exportLog | ForEach-Object { Write-Host $_ }

$failureText = $exportLog | Select-String -Pattern "(^|\s)ERROR:|Project export .* failed|Export failed" -CaseSensitive:$false
if ($exportExitCode -ne 0 -or $failureText) {
    Stop-ReleaseCheck "godot_export_failed exit_code=$exportExitCode"
}

$requiredFiles = @(
    "index.html",
    "index.wasm",
    "index.pck",
    "index.manifest.json",
    "index.service.worker.js",
    "index.144x144.png",
    "index.180x180.png",
    "index.512x512.png"
)
foreach ($requiredFile in $requiredFiles) {
    $requiredPath = Join-Path $outputPath $requiredFile
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Stop-ReleaseCheck "missing_artifact file=$requiredFile"
    }
    if ((Get-Item -LiteralPath $requiredPath).Length -le 0) {
        Stop-ReleaseCheck "empty_artifact file=$requiredFile"
    }
}

$pckPath = Join-Path $outputPath "index.pck"
$pckBytes = (Get-Item -LiteralPath $pckPath).Length
$pckLimitBytes = 1572864
if ($pckBytes -gt $pckLimitBytes) {
    Stop-ReleaseCheck "pck_budget_exceeded bytes=$pckBytes limit=$pckLimitBytes"
}

$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -eq $rg) {
    Stop-ReleaseCheck "ripgrep_not_found"
}
$forbiddenPatterns = @(
    "res://tools/",
    "04_Barbarian",
    "05_Sorceress",
    "network_harness",
    "asset_compiler",
    "app_icon_source"
)
foreach ($pattern in $forbiddenPatterns) {
    $matches = @(& $rg.Source -a -n -F -- $pattern $pckPath 2>&1 | ForEach-Object { $_.ToString() })
    $rgExitCode = $LASTEXITCODE
    if ($rgExitCode -eq 0) {
        $matches | ForEach-Object { Write-Host $_ }
        Stop-ReleaseCheck "forbidden_content pattern=$pattern"
    }
    if ($rgExitCode -ne 1) {
        Stop-ReleaseCheck "content_scan_failed pattern=$pattern exit_code=$rgExitCode"
    }
}

Write-Host "[RELEASE] artifacts=$($requiredFiles.Count) pck_bytes=$pckBytes pck_limit_bytes=$pckLimitBytes"
Write-Host "[RELEASE] output=$outputPath"
Write-Host "[RELEASE] verdict=PASS" -ForegroundColor Green
