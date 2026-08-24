<#
.SYNOPSIS
    Installs aria2c via winget, downloads the latest Ubuntu LTS desktop ISO
    using aria2c's multi-connection download, and verifies its SHA256 checksum.
.NOTES
    Run it with:
        powershell -ExecutionPolicy Bypass -File .\get-ubuntu-lts.ps1
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # avoid the slow progress-bar overhead
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "== Step 1: Ensure aria2c is installed =="
$aria2 = Get-Command aria2c -ErrorAction SilentlyContinue
if (-not $aria2) {
    Write-Host "aria2c not found. Installing via winget..."
    winget install --id aria2.aria2 -e --accept-source-agreements --accept-package-agreements

    # winget installs are picked up on new PATH sessions, so refresh PATH in-process
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
                [System.Environment]::GetEnvironmentVariable("Path","User")

    $aria2 = Get-Command aria2c -ErrorAction SilentlyContinue
    if (-not $aria2) {
        throw "aria2c installed but not found on PATH. Try opening a new terminal and re-running."
    }
} else {
    Write-Host "aria2c already installed."
}

Write-Host "`n== Step 2: Find the latest Ubuntu LTS version =="
$indexHtml = (Invoke-WebRequest -Uri "https://releases.ubuntu.com/" -UseBasicParsing).Content
$plainText = $indexHtml -replace '<[^>]+>', ' '
$pattern = '(\d{2}\.04)/\s+\S+\s+\S+\s+-\s+Ubuntu\s+\1(?:\.\d+)?\s+LTS'
$ltsMatches = [regex]::Matches($plainText, $pattern)

if ($ltsMatches.Count -eq 0) {
    throw "Could not find any LTS release entries on releases.ubuntu.com. The page format may have changed."
}

$version = $ltsMatches |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object { [int]($_.Split('.')[0]) } -Descending |
    Select-Object -First 1

Write-Host "Latest Ubuntu LTS version: $version"

$isoName  = "ubuntu-$version-desktop-amd64.iso"
$baseUrl  = "https://releases.ubuntu.com/$version"
$isoUrl   = "$baseUrl/$isoName"
$sumsUrl  = "$baseUrl/SHA256SUMS"
$sumsFile = "SHA256SUMS"

Write-Host "`n== Step 3: Download the ISO with aria2c (16 connections) =="
Write-Host "  $isoUrl"
aria2c -x16 -s16 -o $isoName $isoUrl
if ($LASTEXITCODE -ne 0) {
    throw "aria2c failed with exit code $LASTEXITCODE"
}

Write-Host "`n== Step 4: Download the checksum file =="
Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsFile

Write-Host "`n== Step 5: Verify checksum =="
$expectedLine = Get-Content $sumsFile | Where-Object { $_ -match [regex]::Escape($isoName) }
if (-not $expectedLine) {
    throw "No checksum entry found for $isoName in $sumsFile."
}

$expectedHash = ($expectedLine -split "\s+")[0].ToUpper()
$actualHash   = (Get-FileHash -Path $isoName -Algorithm SHA256).Hash.ToUpper()

Write-Host "Expected: $expectedHash"
Write-Host "Actual:   $actualHash"

if ($actualHash -eq $expectedHash) {
    Write-Host "`nChecksum OK - $isoName is verified." -ForegroundColor Green
} else {
    Write-Host "`nCHECKSUM MISMATCH! The file may be corrupt or incomplete." -ForegroundColor Red
    exit 1
}
