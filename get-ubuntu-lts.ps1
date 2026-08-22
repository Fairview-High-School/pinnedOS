<#
.SYNOPSIS
    Downloads the latest Ubuntu LTS desktop ISO (x64) and verifies its SHA256 checksum.

.NOTES
    Windows PowerShell does not ship with real GNU wget - "wget" in PowerShell is just
    an alias for Invoke-WebRequest, and it doesn't support the same flags as Linux wget.
    This script uses Invoke-WebRequest directly so it works out of the box.

    Run it with:
        powershell -ExecutionPolicy Bypass -File .\get-ubuntu-lts.ps1
#>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Looking up the latest Ubuntu LTS version..."

# releases.ubuntu.com lists every release directory (e.g. "26.04/") along with a
# description like "Ubuntu 26.04 LTS (Resolute Raccoon)". We scrape that listing,
# find every plain "NN.04/" entry that's tagged LTS, and take the highest version.
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

Write-Host "`nDownloading ISO:"
Write-Host "  $isoUrl"
Invoke-WebRequest -Uri $isoUrl -OutFile $isoName

Write-Host "`nDownloading checksum file:"
Write-Host "  $sumsUrl"
Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsFile

Write-Host "`nVerifying checksum..."
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
