# =============================================================================
# BLOCK 5 - REFOLD ALL 1,000 DESIGNS WITH BOLTZ-2.1
# =============================================================================
#
# WHAT THIS DOES AND WHY IT MATTERS
#   The design model scored its own output. That is a conflict of interest:
#   the generator is grading its own homework. Refolding takes the 1,000 SMILES
#   it produced, hands them to a DIFFERENT model (Boltz-2.1) as a plain
#   structure-and-binding prediction task against the same target, and asks it
#   to score them cold.
#
#   Agreement between design and refold scores is evidence the molecules are
#   real binders rather than artifacts of the generator. Disagreement tells you
#   which ones to distrust. In the reference run the refold scores were used
#   for the final ranking, not the design scores.
#
#   WHY TWO JOBS OF 500
#   Screening jobs have a per-job cap. Splitting into 2 x 500 stays inside it
#   and lets the two halves run in parallel. The halves are independent -
#   nothing is shared between them, so the split point does not matter.
#
#   WHY THE JOB IDS SAY "sm_scr" AND NOT SOMETHING WITH "2.1" IN IT
#   `small-molecule:screen` is the ENDPOINT - it means "score these molecules
#   against this target". The MODEL doing the scoring is set separately. The
#   job ID prefix reflects the endpoint, not the model, so refold jobs look
#   like sm_scr_XXXXXXXX. That is expected and does not mean you ran the
#   wrong thing.
#
# PREREQUISITE: Block 4 has run and the designs CSV exists.
# =============================================================================

$outDir = "$env:USERPROFILE\Downloads\boltz_designs"
$csvPath = "$outDir\1BTL_1000_designs.csv"

$designs = Import-Csv $csvPath
Write-Host "Loaded $($designs.Count) designs from $csvPath" -ForegroundColor Green

# Same target as the design run - must be identical or the comparison is void
$proteinSeq = "HPETLVKVKDAEDQLGARVGYIELDLNSGKILESFRPEERFPMMSTFKVLLCGAVLSRIDAGQEQLGRRIHYSQNDLVEYSPVTEKHLTDGMTVRELCSAAITMSDNTAANLLLTTIGGPKELTAFLHNMGDHVTRLDRWEPELNEAIPNDERDTTMPVAMATTLRKLLTGELLTLASRQQLIDWMEADKVAGPLLRSALPAGWFIADKSGAGERGSRGIIAALGPDGKPSRIVVIYTTGSQATMDERNRQIAEIGASLIKHW"
$pocketResidues = @{ A = @(44, 47, 104, 106, 140, 208) }

# --- Split 1,000 into two halves of 500 --------------------------------------
$half1 = $designs[0..499]
$half2 = $designs[500..999]

$batches = @(
    @{ Name = "1BTL-refold-boltz21-batch1"; Rows = $half1 },
    @{ Name = "1BTL-refold-boltz21-batch2"; Rows = $half2 }
)

$refoldJobIds = @()

foreach ($b in $batches) {

    $batchName = $b.Name
    $smilesList = $b.Rows | ForEach-Object { $_.smiles }

    Write-Host "`n--- $batchName : $($smilesList.Count) molecules ---" -ForegroundColor Cyan

    $payload = @{
        idempotency_key = $batchName
        model           = "boltz-2.1"
        molecules       = $smilesList
        target = @{
            type = "no_template"
            entities = @(
                @{ type = "protein"; chain_ids = @("A"); value = $proteinSeq }
            )
            pocket_residues = $pocketResidues
        }
    }

    $batchJson = "$outDir\boltz_refold_$batchName.json"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($batchJson, ($payload | ConvertTo-Json -Depth 20), $utf8NoBom)

    $inputRef = "@json://$($batchJson.Replace('\','/'))"

    & $boltz small-molecule:screen estimate-cost --input $inputRef

    $id = & $boltz small-molecule:screen start `
        --idempotency-key $batchName `
        --input $inputRef `
        --raw-output `
        --transform id

    Write-Host "$batchName job ID: $id" -ForegroundColor Green
    $refoldJobIds += $id
}

$refoldJobIds | Set-Content "$outDir\boltz_refold_jobids.txt"
Write-Host "`nRefold job IDs saved to: $outDir\boltz_refold_jobids.txt" -ForegroundColor Green


# =============================================================================
# WHAT YOU SHOULD SEE IF IT WORKED
# =============================================================================
#
#   Loaded 1000 designs from ...\1BTL_1000_designs.csv
#
#   --- 1BTL-refold-boltz21-batch1 : 500 molecules ---
#   <cost estimate>
#   1BTL-refold-boltz21-batch1 job ID: sm_scr_XXXXXXXXXXXXXXXXXXXX
#
#   --- 1BTL-refold-boltz21-batch2 : 500 molecules ---
#   <cost estimate>
#   1BTL-refold-boltz21-batch2 job ID: sm_scr_XXXXXXXXXXXXXXXXXXXX
#
#   Refold job IDs saved to: ...\boltz_refold_jobids.txt
#
#   The reference run produced:
#       sm_scr_87F8ZAKkTuMPHCIQttcB    500/500
#       sm_scr_3HzrUdHIgvoelkOqTaoS    500/500
#
#   Check progress the same way as Block 3, swapping the command:
#       & $boltz small-molecule:screen get --id <refold job id>
#
# IF IT FAILS
#
#   "batch too large"
#       Lower the split. Four jobs of 250 works the same way - change the
#       slicing at the $half1 / $half2 lines.
#
#   Model name rejected
#       Confirm the exact string your account accepts:
#           & $boltz small-molecule:screen --help
#       and substitute for "boltz-2.1".
#
#   Job IDs come back starting sm_scr_ and you expected something else
#       That is correct. See the note at the top of this file - the prefix
#       names the endpoint, not the model.
#
#   One batch succeeds and the other fails
#       They are independent. Re-run just the failed one by changing the
#       $batches array to contain only that entry. The idempotency key means
#       re-running the successful one costs nothing anyway.
# =============================================================================
