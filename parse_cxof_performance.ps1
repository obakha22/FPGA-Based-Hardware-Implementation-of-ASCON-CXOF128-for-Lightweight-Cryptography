param(
    [string]$LogFile = "project_1.sim\sim_1\behav\xsim\cxof_sweep_simulate.log",
    [string]$ReportsDir = "reports"
)

$ErrorActionPreference = "Stop"
$pattern = '^PERF,count=(\d+),z_bytes=(\d+),msg_bytes=(\d+),out_bits=(\d+),start_cycle=(\d+),done_cycle=(\d+),cycles=(\d+),throughput_mbps=([0-9.]+)$'
$rows = [System.Collections.Generic.List[object]]::new()

foreach ($line in Get-Content -LiteralPath $LogFile) {
    if ($line -match $pattern) {
        $rows.Add([pscustomobject]@{
            Count = [int]$Matches[1]
            ZBytes = [int]$Matches[2]
            MsgBytes = [int]$Matches[3]
            OutBits = [int]$Matches[4]
            StartCycle = [int]$Matches[5]
            DoneCycle = [int]$Matches[6]
            Cycles = [int]$Matches[7]
            ThroughputMbps = [double]$Matches[8]
        })
    }
}

if ($rows.Count -ne 1089) {
    throw "Expected 1089 PERF records in $LogFile, found $($rows.Count)."
}

New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null
$rows | Export-Csv -NoTypeInformation -Encoding ASCII `
    -Path (Join-Path $ReportsDir "cxof_kat_performance_sweep.csv")

$summary = $rows |
    Group-Object MsgBytes |
    Sort-Object { [int]$_.Name } |
    ForEach-Object {
        $cycles = $_.Group.Cycles
        $throughput = $_.Group.ThroughputMbps
        [pscustomobject]@{
            MsgBytes = [int]$_.Name
            Vectors = $_.Count
            MinCycles = ($cycles | Measure-Object -Minimum).Minimum
            AvgCycles = [Math]::Round(
                ($cycles | Measure-Object -Average).Average, 3)
            MaxCycles = ($cycles | Measure-Object -Maximum).Maximum
            MinThroughputMbps = [Math]::Round(
                ($throughput | Measure-Object -Minimum).Minimum, 6)
            AvgThroughputMbps = [Math]::Round(
                ($throughput | Measure-Object -Average).Average, 6)
            MaxThroughputMbps = [Math]::Round(
                ($throughput | Measure-Object -Maximum).Maximum, 6)
        }
    }

$summary | Export-Csv -NoTypeInformation -Encoding ASCII `
    -Path (Join-Path $ReportsDir "cxof_kat_performance_by_message_size.csv")

$md = [System.Collections.Generic.List[string]]::new()
$md.Add("| Message bytes | Vectors | Min cycles | Avg cycles | Max cycles | Avg throughput (Mbit/s) |")
$md.Add("|---:|---:|---:|---:|---:|---:|")
foreach ($row in $summary) {
    $md.Add("| $($row.MsgBytes) | $($row.Vectors) | $($row.MinCycles) | $($row.AvgCycles) | $($row.MaxCycles) | $($row.AvgThroughputMbps) |")
}
[System.IO.File]::WriteAllLines(
    (Join-Path (Join-Path (Get-Location) $ReportsDir) "cxof_kat_performance_summary.md"),
    $md,
    [System.Text.Encoding]::ASCII
)

$plotRows = @($summary | Where-Object { $_.MsgBytes -gt 0 })
$width = 900
$height = 520
$left = 75
$right = 25
$top = 35
$bottom = 65
$plotWidth = $width - $left - $right
$plotHeight = $height - $top - $bottom
$maxX = ($plotRows.MsgBytes | Measure-Object -Maximum).Maximum
$maxY = ($plotRows.AvgThroughputMbps | Measure-Object -Maximum).Maximum
$points = foreach ($row in $plotRows) {
    $x = $left + ($row.MsgBytes / $maxX) * $plotWidth
    $y = $top + $plotHeight - ($row.AvgThroughputMbps / $maxY) * $plotHeight
    "{0:F1},{1:F1}" -f $x, $y
}

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">
  <rect width="100%" height="100%" fill="white"/>
  <text x="$($width / 2)" y="22" text-anchor="middle" font-family="Arial" font-size="17">ASCON-CXOF128 effective throughput at 100 MHz</text>
  <line x1="$left" y1="$top" x2="$left" y2="$($top + $plotHeight)" stroke="black"/>
  <line x1="$left" y1="$($top + $plotHeight)" x2="$($left + $plotWidth)" y2="$($top + $plotHeight)" stroke="black"/>
  <polyline points="$($points -join ' ')" fill="none" stroke="#1565c0" stroke-width="3"/>
  <text x="$($width / 2)" y="$($height - 18)" text-anchor="middle" font-family="Arial" font-size="14">Message size (bytes)</text>
  <text x="18" y="$($height / 2)" transform="rotate(-90 18 $($height / 2))" text-anchor="middle" font-family="Arial" font-size="14">Average throughput (Mbit/s)</text>
  <text x="$left" y="$($top + $plotHeight + 22)" text-anchor="middle" font-family="Arial" font-size="12">0</text>
  <text x="$($left + $plotWidth)" y="$($top + $plotHeight + 22)" text-anchor="middle" font-family="Arial" font-size="12">$maxX</text>
  <text x="$($left - 8)" y="$($top + $plotHeight)" text-anchor="end" font-family="Arial" font-size="12">0</text>
  <text x="$($left - 8)" y="$($top + 5)" text-anchor="end" font-family="Arial" font-size="12">$([Math]::Round($maxY, 2))</text>
</svg>
"@
[System.IO.File]::WriteAllText(
    (Join-Path (Join-Path (Get-Location) $ReportsDir) "cxof_throughput_vs_message_size.svg"),
    $svg,
    [System.Text.Encoding]::ASCII
)

Write-Host "Parsed $($rows.Count) performance records."
Write-Host "Message sizes present: $((($summary.MsgBytes) -join ', ')) bytes"
