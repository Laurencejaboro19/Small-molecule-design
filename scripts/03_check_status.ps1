# =============================================================================
# BLOCK 3 - CHECK JOB STATUS
# =============================================================================
#
# WHAT THIS DOES
#   Polls the design job and prints how many of the 1,000 molecules have been
#   generated so far. A 1,000-molecule design run takes roughly 1-3 hours
#   depending on queue load, so expect to run this several times.
#
# PREREQUISITE: Blocks 1 and 2 ($boltz and $jobId must be set).
#   If you reopened PowerShell, re-run Block 1 and then set $jobId by hand:
#       $jobId = Get-Content "$env:USERPROFILE\Downloads\boltz_design_jobid.txt"
# =============================================================================

if (-not $jobId) {
    $jobId = Get-Content "$env:USERPROFILE\Downloads\boltz_design_jobid.txt"
}

Write-Host "Checking job: $jobId" -ForegroundColor Cyan
& $boltz small-molecule:design get --id $jobId


# --- Optional: poll every 5 minutes until it finishes ------------------------
# Uncomment the block below to let it watch on its own. Ctrl+C stops it.
#
# while ($true) {
#     $status = & $boltz small-molecule:design get --id $jobId --raw-output --transform status
#     $stamp  = Get-Date -Format "HH:mm:ss"
#     Write-Host "[$stamp] status: $status"
#     if ($status -in @("succeeded","failed","cancelled")) { break }
#     Start-Sleep -Seconds 300
# }


# =============================================================================
# WHAT YOU SHOULD SEE IF IT WORKED
# =============================================================================
#
#   While running:
#       status:     running
#       progress:   412 / 1000
#
#   When finished:
#       status:     succeeded
#       progress:   1000 / 1000
#
#   Partial failures are normal and acceptable. A run that reports
#   990/1000 succeeded is fine - some molecules fail generation or filtering.
#   The reference run came back 1000/1000.
#
# IF IT FAILS
#
#   "job not found"
#       Wrong ID, or you are logged into a different workspace than the one
#       that submitted it. Re-run `& $boltz auth whoami` and compare.
#
#   Status stuck at "queued" for over an hour
#       Normal under load. Leave it. Nothing you do locally speeds it up.
#
#   Status "failed"
#       Run the command without --raw-output to see the error message. The
#       usual causes are a malformed sequence or pocket indices that fall
#       outside the sequence length (the sequence here is 263 residues, so
#       every index must be between 0 and 262).
#
#   NOTE ON SUBCOMMAND NAMES
#       If `get` is not a valid subcommand on your CLI version, discover the
#       right one with:
#           & $boltz small-molecule:design --help
#       and substitute. The CLI's subcommand vocabulary has changed between
#       releases; the flags shown here (--id, --raw-output, --transform) are
#       stable.
# =============================================================================
