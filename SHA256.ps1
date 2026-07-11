# Directory containing the manifest
$directoryPath = (Get-Location).Path
$hashFilePath = Join-Path $directoryPath "SHA256"

# Check manifest exists
if (-not (Test-Path $hashFilePath)) {
    Write-Host "Hash file 'SHA256' not found."
    exit 1
}

# Read manifest
$manifestLines = Get-Content $hashFilePath

# Validate manifest header
if (
    $manifestLines.Count -lt 3 -or
    $manifestLines[0] -notmatch '^# AGGREGATE SHA256: ([0-9A-F]{64})$'
) {
    Write-Host "Invalid SHA256 manifest."
    exit 1
}

$expectedAggregateHash = $Matches[1]

# Extract manifest entries
$entries = $manifestLines |
    Select-Object -Skip 2 |
    Where-Object { $_.Trim() -ne "" }

# Recalculate aggregate hash
$manifestText = $entries -join "`n"

$memoryStream = [System.IO.MemoryStream]::new(
    [System.Text.Encoding]::UTF8.GetBytes($manifestText)
)

try {
    $actualAggregateHash = (
        Get-FileHash -Algorithm SHA256 -InputStream $memoryStream
    ).Hash.ToUpperInvariant()
}
finally {
    $memoryStream.Dispose()
}

if ($actualAggregateHash -ne $expectedAggregateHash) {
    Write-Host ""
    Write-Host "AGGREGATE HASH FAILED!"
    Write-Host "Expected: $expectedAggregateHash"
    Write-Host "Actual:   $actualAggregateHash"
    Write-Host ""
    Write-Host "The manifest has been modified or corrupted."
    exit 1
}

Write-Host "Aggregate hash verified."

# Build hash lookup table
$hashDictionary = @{}

foreach ($entry in $entries) {
    if ($entry -match '^([0-9A-F]{64})  (.+)$') {
        $hashDictionary[$Matches[2]] = $Matches[1]
    }
    else {
        Write-Host "Invalid manifest entry: $entry"
        exit 1
    }
}

$allOK = $true

# Verify all files
Get-ChildItem -File -Recurse |
    Where-Object { $_.Name -ne "SHA256" } |
    Sort-Object FullName |
    ForEach-Object {

        $relativePath = $_.FullName.Substring($directoryPath.Length + 1)

        if (-not $hashDictionary.ContainsKey($relativePath)) {
            Write-Host "[NEW]  $relativePath"
            $allOK = $false
            return
        }

        $expectedHash = $hashDictionary[$relativePath]

        $actualHash = (
            Get-FileHash -Algorithm SHA256 -Path $_.FullName
        ).Hash.ToUpperInvariant()

        if ($actualHash -eq $expectedHash) {
            Write-Host "[OK]   $relativePath"
        }
        else {
            Write-Host "[FAIL] $relativePath"
            Write-Host "       Expected: $expectedHash"
            Write-Host "       Actual:   $actualHash"
            $allOK = $false
        }
    }

# Detect files listed in manifest but missing from disk
foreach ($path in $hashDictionary.Keys) {
    if (-not (Test-Path (Join-Path $directoryPath $path))) {
        Write-Host "[MISSING] $path"
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
