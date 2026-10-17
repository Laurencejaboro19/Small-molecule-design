# =============================================================================
# BLOCK 4 - DOWNLOAD ALL 1,000 DESIGNS
# =============================================================================
#
# WHAT THIS DOES
#   Pulls every generated molecule out of the finished design job and writes
#   them to one JSON file, then flattens that into a CSV you can open in Excel
#   or feed to ADMETLab.
#
#   WHY IT PAGINATES
#   The API will not hand back 1,000 records in a single response. It returns
#   a page at a time and gives you the ID of the last record on that page;
#   you pass that back as --after-id to get the next page. The loop below runs
#   until a page comes back empty.
#
#   Each record carries:
#       id                      the design ID, e.g. pres_j3ajhUF8YoC7f9wURXcq
#       smiles                  the molecule
#       binding_confidence      0-1, higher is better
#       iptm / ptm              interface and overall structure confidence
#       optimization_score      how far the optimizer moved it
#       complex_plddt / iplddt  per-atom confidence measures
#
# PREREQUISITE: the job must report status "succeeded" (Block 3).
# =============================================================================

if (-not $jobId) {
    $jobId = Get-Content "$env:USERPROFILE\Downloads\boltz_design_jobid.txt"
}

$outDir  = "$env:USERPROFILE\Downloads\boltz_designs"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$allResults = @()
$afterId    = $null
$page       = 0

do {
    $page++

    if ($afterId) {
        $raw = & $boltz small-molecule:design results --id $jobId --limit 100 --after-id $afterId --raw-output
    } else {
        $raw = & $boltz small-molecule:design results --id $jobId --limit 100 --raw-output
    }

    $batch = $raw | ConvertFrom-Json

    # Different CLI versions wrap the array differently - handle both shapes
    if ($batch.PSObject.Properties.Name -contains 'data') { $items = $batch.data }
    else                                                   { $items = $batch }

    if (-not $items -or $items.Count -eq 0) { break }

    $allResults += $items
    $afterId     = $items[-1].id

    Write-Host "Page $page : pulled $($items.Count), running total $($allResults.Count)"

} while ($items.Count -gt 0)

Write-Host "`nTotal designs retrieved: $($allResults.Count)" -ForegroundColor Green

# --- Save the raw JSON (keep this - it is your primary record) ---------------
$jsonPath = "$outDir\1BTL_1000_designs_raw.json"
$allResults | ConvertTo-Json -Depth 20 | Set-Content $jsonPath -Encoding UTF8
Write-Host "Raw JSON : $jsonPath"

# --- Flatten to CSV ----------------------------------------------------------
$csvPath = "$outDir\1BTL_1000_designs.csv"
$allResults |
    Select-Object id,
                  smiles,
                  binding_confidence,
                  iptm,
                  ptm,
                  optimization_score,
                  complex_plddt,
                  complex_iplddt |
    Sort-Object binding_confidence -Descending |
    Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "CSV      : $csvPath"

# --- SMILES-only file for ADMETLab 3.0 batch upload --------------------------
# ADMETLab's batch endpoint times out on 1,000 at once (HTTP 504). Split into
# ten files of 100 and upload them one at a time.
$smilesDir = "$outDir\admetlab_batches"
New-Item -ItemType Directory -Force -Path $smilesDir | Out-Null

$sorted = $allResults | Sort-Object binding_confidence -Descending
for ($i = 0; $i -lt $sorted.Count; $i += 100) {
    $chunk = $sorted[$i..([Math]::Min($i+99, $sorted.Count-1))]
    $n     = [int]($i/100) + 1
    $chunk | Select-Object @{N='smiles';E={$_.smiles}} |
        Export-Csv "$smilesDir\batch_$n.csv" -NoTypeInformation -Encoding UTF8
}
Write-Host "ADMETLab batches written to: $smilesDir" -ForegroundColor Green


# =============================================================================
# WHAT YOU SHOULD SEE IF IT WORKED
# =============================================================================
#
#   Page 1 : pulled 100, running total 100
#   Page 2 : pulled 100, running total 200
#   ...
#   Page 10 : pulled 100, running total 1000
#
#   Total designs retrieved: 1000
#   Raw JSON : C:\Users\<you>\Downloads\boltz_designs\1BTL_1000_designs_raw.json
#   CSV      : C:\Users\<you>\Downloads\boltz_designs\1BTL_1000_designs.csv
#   ADMETLab batches written to: ...\boltz_designs\admetlab_batches
#
#   The CSV opens in Excel with 1,000 rows sorted by binding confidence,
#   highest first. In the reference run only 4 molecules scored >= 0.5,
#   so do not be alarmed that the top of the column sits around 0.3-0.5.
#   That range is normal for this target.
#
# IF IT FAILS
#
#   The loop never ends / repeats the same page
#       --after-id is not advancing. Check that $items[-1].id is a real ID and
#       not $null. Print it inside the loop to see.
#
#   "Cannot convert value to JSON"
#       The CLI returned an error message instead of JSON. Drop --raw-output
#       and run one call by hand to read what it actually said.
#
#   Fewer than 1,000 records
#       Check the job status first - a partial run returns partial results.
#       990/1000 is a normal outcome and the data is still usable.
#
#   NOTE ON SUBCOMMAND NAMES
#       `results`, `--limit` and `--after-id` are the pagination pattern this
#       API uses. If your CLI version names them differently, run
#           & $boltz small-molecule:design --help
#       and substitute. The pagination LOGIC above is what matters and does
#       not change.
# =============================================================================
