param(
    [string]$InputFile = "project_1.srcs\sim_1\new\LWC_CXOF_KAT_128_512.txt",
    [string]$OutputFile = "project_1.srcs\sim_1\new\cxof_kat_vectors.mem"
)

$ErrorActionPreference = "Stop"

function Convert-ToPaddedWords {
    param([string]$Hex)

    $byteCount = $Hex.Length / 2
    $words = [UInt64[]]::new(5)

    for ($i = 0; $i -lt $byteCount; $i++) {
        $byte = [Convert]::ToUInt64($Hex.Substring(2 * $i, 2), 16)
        $wordIndex = [Math]::Floor($i / 8)
        $shift = 8 * ($i % 8)
        $words[$wordIndex] = $words[$wordIndex] -bor ($byte -shl $shift)
    }

    $paddingWord = [Math]::Floor($byteCount / 8)
    $paddingShift = 8 * ($byteCount % 8)
    $words[$paddingWord] = $words[$paddingWord] -bor ([UInt64]1 -shl $paddingShift)

    return @{
        Count = $paddingWord + 1
        Words = $words
    }
}

$records = (Get-Content -Raw -LiteralPath $InputFile) -split "\r?\n\r?\n"
$lines = [System.Collections.Generic.List[string]]::new()

foreach ($record in $records) {
    if ($record -notmatch "(?m)^Count = (\d+)\s*$") {
        continue
    }

    $count = [int]$Matches[1]
    $null = $record -match "(?m)^Msg = ([0-9A-F]*)\s*$"
    $messageHex = $Matches[1]
    $null = $record -match "(?m)^Z = ([0-9A-F]*)\s*$"
    $customHex = $Matches[1]
    $null = $record -match "(?m)^MD = ([0-9A-F]+)\s*$"
    $digestHex = $Matches[1]

    $message = Convert-ToPaddedWords $messageHex
    $custom = Convert-ToPaddedWords $customHex

    $fields = [System.Collections.Generic.List[string]]::new()
    $fields.Add($count.ToString())
    $fields.Add(($customHex.Length / 2).ToString())
    $fields.Add(($messageHex.Length / 2).ToString())
    $fields.Add(($customHex.Length * 4).ToString())
    $fields.Add($custom.Count.ToString())
    foreach ($word in $custom.Words) {
        $fields.Add($word.ToString("x16"))
    }
    $fields.Add($message.Count.ToString())
    foreach ($word in $message.Words) {
        $fields.Add($word.ToString("x16"))
    }
    for ($i = 0; $i -lt 8; $i++) {
        $fields.Add($digestHex.Substring(16 * $i, 16).ToLowerInvariant())
    }

    $lines.Add(($fields -join " "))
}

if ($lines.Count -ne 1089) {
    throw "Expected 1089 KAT records, generated $($lines.Count)."
}

[System.IO.File]::WriteAllLines(
    (Join-Path (Get-Location) $OutputFile),
    $lines,
    [System.Text.Encoding]::ASCII
)

Write-Host "Generated $($lines.Count) CXOF KAT records in $OutputFile"
