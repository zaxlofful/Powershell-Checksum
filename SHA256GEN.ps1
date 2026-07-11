$outputFile = "SHA256"
$currentDirectory = (Get-Location).Path

Write-Host "Generating SHA-256 manifest..."

# Gather file hashes in deterministic order
$entries = Get-ChildItem -File -Recurse |
    Where-Object { $_.Name -ne $outputFile } |
    Sort-Object FullName |
    ForEach-Object {
        $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToUpperInvariant()
        $relativePath = $_.FullName.Substring($currentDirectory.Length + 1)

        "$hash  $relativePath"
    }

# Create deterministic manifest content
$manifestText = $entries -join "`n"

# Compute aggregate hash from manifest entries
$memoryStream = [System.IO.MemoryStream]::new(
    [System.Text.Encoding]::UTF8.GetBytes($manifestText)
)

try {
    $aggregateHash = (
        Get-FileHash -Algorithm SHA256 -InputStream $memoryStream
    ).Hash.ToUpperInvariant()
}
finally {
    $memoryStream.Dispose()
}

# Write manifest
@(
    "# AGGREGATE SHA256: $aggregateHash"
    ""
    $entries
) | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "SHA256 manifest written to '$outputFile'."
Write-Host "Aggregate SHA256: $aggregateHash"
