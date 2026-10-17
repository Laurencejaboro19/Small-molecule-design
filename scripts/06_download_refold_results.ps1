# =============================================================================
# BLOCK 6 - DOWNLOAD BOTH REFOLD BATCHES AND MERGE INTO ONE RANKED CSV
# =============================================================================
#
# WHAT THIS DOES
#   Pulls results from both 500-molecule refold jobs, stitches them back into
#   one table of 1,000, joins them to the original design scores on SMILES,
#   and writes a single ranked CSV.
#
#   THE JOIN KEY IS SMILES, AND THAT MATTERS
#   Design IDs and refold IDs are different, so SMILES is the only thing
#   connecting the two tables. One warning from the reference run: when you
#   later merge with ADMETLab output, ADMETLab returns BOTH a `raw_smiles`
#   column (exactly what you submitted) and a `smiles` column (its own
#   re-canonicalised version). Matching on `smiles` loses rows -
#   998/1000 in the reference run. Matching on `raw_smiles` gave a clean
#   1000/1000. Always join on the un-canonicalised column.
#
# PREREQUISITE: both refold jobs report "succeeded".
# =============================================================================

$outDir = "$env:USERPROFILE\Downloads\boltz_designs"
$refoldJobIds = Get-Content "$outDir\boltz_refold_jobids.txt"

Write-Host "Refold jobs to collect: $($refoldJobIds.Count)" -ForegroundColor Cyan

$allRefold = @()

foreach ($rid in $refoldJobIds) {

    Write-Host "`n--- Collecting $rid ---" -ForegroundColor Cyan

    $afterId = $null
    $page    = 0

    do {
        $page++

        if ($afterId) {
            $raw = & $boltz small-molecule:screen results --id $rid --limit 100 --after-id $afterId --raw-output
        } else {
            $raw = & $boltz small-molecule:screen results --id $rid --limit 100 --raw-output
        }

        $batch = $raw | ConvertFrom-Json

        if ($batch.PSObject.Properties.Name -contains 'data') { $items = $batch.data }
        else                                                   { $items = $batch }

        if (-not $items -or $items.Count -eq 0) { break }

        $allRefold += $items
        $afterId    = $items[-1].id

        Write-Host "  page $page : $($items.Count) records (job total $($allRefold.Count))"

    } while ($items.Count -gt 0)
}

Write-Host "`nTotal refold records: $($allRefold.Count)" -ForegroundColor Green

# --- Save raw ----------------------------------------------------------------
$allRefold | ConvertTo-Json -Depth 20 |
    Set-Content "$outDir\1BTL_1000_refold_raw.json" -Encoding UTF8

# --- Build a SMILES -> refold-score lookup -----------------------------------
$refoldBySmiles = @{}
foreach ($r in $allRefold) { $refoldBySmiles[$r.smiles] = $r }

# --- Join design scores to refold scores on SMILES ---------------------------
$designs = Import-Csv "$outDir\1BTL_1000_designs.csv"
$merged  = foreach ($d in $designs) {

    $r = $refoldBySmiles[$d.smiles]

    [PSCustomObject]@{
        design_id                  = $d.id
        smiles                     = $d.smiles
        design_binding_confidence  = $d.binding_confidence
        design_iptm                = $d.iptm
        design_ptm                 = $d.ptm
        design_optimization_score  = $d.optimization_score
        refold_binding_confidence  = if ($r) { $r.binding_confidence } else { $null }
        refold_iptm                = if ($r) { $r.iptm }               else { $null }
        refold_ptm                 = if ($r) { $r.ptm }                else { $null }
        refold_complex_plddt       = if ($r) { $r.complex_plddt }      else { $null }
        refold_complex_iplddt      = if ($r) { $r.complex_iplddt }     else { $null }
        matched                    = [bool]$r
    }
}

$matchedCount = ($merged | Where-Object { $_.matched }).Count
Write-Host "Matched $matchedCount of $($designs.Count) designs to refold scores" -ForegroundColor Green

# --- Rank by refold score (the independent one) and write --------------------
$finalPath = "$outDir\1BTL_1000_FINAL_RANKED_refold.csv"
$merged |
    Sort-Object { [double]$_.refold_binding_confidence } -Descending |
    Export-Csv $finalPath -NoTypeInformation -Encoding UTF8

Write-Host "`nFinal ranked CSV: $finalPath" -ForegroundColor Green

# --- SMILES in ranked order, for ADMETLab ------------------------------------
$merged |
    Sort-Object { [double]$_.refold_binding_confidence } -Descending |
    Select-Object @{N='smiles';E={$_.smiles}} |
    Export-Csv "$outDir\1BTL_1000_smiles_ranked.csv" -NoTypeInformation -Encoding UTF8


# =============================================================================
# WHAT YOU SHOULD SEE IF IT WORKED
# =============================================================================
#
#   Refold jobs to collect: 2
#
#   --- Collecting sm_scr_87F8ZAKkTuMPHCIQttcB ---
#     page 1 : 100 records (job total 100)
#     ...
#     page 5 : 100 records (job total 500)
#
#   --- Collecting sm_scr_3HzrUdHIgvoelkOqTaoS ---
#     page 1 : 100 records (job total 600)
#     ...
#     page 5 : 100 records (job total 1000)
#
#   Total refold records: 1000
#   Matched 1000 of 1000 designs to refold scores
#
#   Final ranked CSV: ...\1BTL_1000_FINAL_RANKED_refold.csv
#
#   Open the CSV and sanity-check it: design_binding_confidence and
#   refold_binding_confidence should be broadly correlated but NOT identical.
#   If they are identical you have accidentally joined a table to itself.
#   If they are completely uncorrelated, check that the target sequence and
#   pocket residues in Block 5 match Block 2 exactly.
#
# IF IT FAILS
#
#   matched count is less than 1000
#       SMILES strings differ between the two tables - usually canonicalisation.
#       Canonicalise both sides with RDKit before joining:
#           from rdkit import Chem
#           Chem.MolToSmiles(Chem.MolFromSmiles(s))
#       and join on the canonical form.
#
#   Sorting puts small numbers on top
#       PowerShell sorted the column as text, not numbers. The [double] cast
#       in the Sort-Object block above prevents this - make sure it is there.
#
#   Blank refold columns throughout
#       The join found nothing. Print one SMILES from each table and compare
#       them character by character.
# =============================================================================
