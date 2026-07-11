$outputFile = "SHA256"
$currentDirectory = (Get-Location).Path

Write-Host "Generating SHA-256 manifest..."

# Gather file hashes in a deterministic order
$entries = Get-ChildItem -File -Recurse |
    Where-Object { $_.Name -ne $outputFile } |
    Sort-Object FullName |
    ForEach-Object {
        $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToUpper()
        $relativePath = $_.FullName.Substring($currentDirectory.Length + 1)

        "$hash  $relativePath"
    }

# Compute the master hash from the manifest entries
$manifestText = $entries -join "`n"

$memoryStream = [System.IO.MemoryStream]::new(
    [System.Text.Encoding]::UTF8.GetBytes($manifestText)
)

$masterHash = (Get-FileHash -Algorithm SHA256 -InputStream $memoryStream).Hash.ToUpper()

$memoryStream.Dispose()

# Write the manifest
@(
    "# MASTER SHA256: $masterHash"
    ""
    $entries
) | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "SHA256 manifest written to '$outputFile'."
Write-Host "Master SHA256: $masterHash"
