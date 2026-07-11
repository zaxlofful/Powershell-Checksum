# Directory containing the manifest
$directoryPath = (Get-Location).Path
$hashFilePath = Join-Path $directoryPath "SHA256"

if (-not (Test-Path $hashFilePath)) {
    Write-Host "Hash file 'SHA256' not found."
    exit 1
}

# Read manifest
$manifestLines = Get-Content $hashFilePath

if ($manifestLines.Count -lt 3 -or $manifestLines[0] -notmatch '^# MASTER SHA256: ([0-9A-F]{64})$') {
    Write-Host "Invalid SHA256 manifest."
    exit 1
}

$expectedMasterHash = $Matches[1].ToUpper()

# Remove header and blank lines
$entries = $manifestLines |
    Select-Object -Skip 2 |
    Where-Object { $_.Trim() -ne "" }

# Compute master hash from the entries
$manifestText = $entries -join "`n"

$memoryStream = [System.IO.MemoryStream]::new(
    [System.Text.Encoding]::UTF8.GetBytes($manifestText)
)

$actualMasterHash = (
    Get-FileHash -Algorithm SHA256 -InputStream $memoryStream
).Hash.ToUpper()

$memoryStream.Dispose()

if ($actualMasterHash -ne $expectedMasterHash) {
    Write-Host ""
    Write-Host "MASTER HASH FAILED!"
    Write-Host "Expected: $expectedMasterHash"
    Write-Host "Actual:   $actualMasterHash"
    Write-Host ""
    Write-Host "The manifest has been modified or corrupted."
    exit 1
}

Write-Host "Master hash verified."

# Build lookup table
$hashDictionary = @{}

foreach ($entry in $entries) {
    if ($entry -match '^([0-9A-Fa-f]{64})\s+(.+)$') {
        $hashDictionary[$Matches[2]] = $Matches[1].ToUpper()
    }
}

$allOK = $true

# Verify every file except the manifest itself
Get-ChildItem -File -Recurse |
    Where-Object { $_.Name -ne "SHA256" } |
    Sort-Object FullName |
    ForEach-Object {

        $relativePath = $_.FullName.Substring($directoryPath.Length + 1)

        if (-not $hashDictionary.ContainsKey($relativePath)) {
            Write-Host "Missing manifest entry: $relativePath"
            $allOK = $false
            return
        }

        $expectedHash = $hashDictionary[$relativePath]
        $actualHash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToUpper()

        if ($expectedHash -eq $actualHash) {
            Write-Host "[OK] $relativePath"
        }
        else {
            Write-Host "[FAIL] $relativePath"
            Write-Host "  Expected: $expectedHash"
            Write-Host "  Actual:   $actualHash"
            $allOK = $false
        }
    }

# Detect files that are listed in the manifest but don't exist
foreach ($path in $hashDictionary.Keys) {
    if (-not (Test-Path (Join-Path $directoryPath $path))) {
        Write-Host "Missing file: $path"
        $allOK = $false
    }
}

if ($allOK) {
    Write-Host ""
    Write-Host "All OK"
    exit 0
}
else {
    Write-Host ""
    Write-Host "Something's fishy"
    exit 1
}
