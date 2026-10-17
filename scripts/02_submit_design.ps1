# =============================================================================
# BLOCK 2 - DESIGN 1,000 SMALL MOLECULES AGAINST TEM-1 BETA-LACTAMASE
# =============================================================================
#
# WHAT THIS DOES
#   Builds the full job specification as a PowerShell hashtable, writes it to
#   disk as UTF-8 JSON, asks the API what it will cost, then submits the job.
#
#   The four things that actually control the chemistry you get back:
#
#   1. $proteinSeq        The 263-residue TEM-1 mature sequence, taken from the
#                         cleaned 1BTL PDB (waters, sulfate and altloc B removed;
#                         chain A only). This is the target.
#
#   2. $pocketResidues    Zero-indexed positions of the six catalytic residues.
#                         Index 44 = Ser70, 47 = Lys73, 104 = Ser130,
#                         106 = Asn132, 140 = Glu166, 208 = Lys234.
#                         (Zero-indexed position = PDB number minus 26, because
#                         the mature protein starts at His26 in PDB numbering.)
#                         This tells the model WHERE on the protein to bind.
#
#   3. $referenceLigands  Five FDA-approved compounds that bind the TEM-1 active
#                         site: ampicillin, amoxicillin, clavulanate, sulbactam,
#                         avibactam. These define the pocket a second way, by
#                         the volume they occupy. They are a TARGETING signal,
#                         not a chemotype instruction - the model is not copying
#                         their beta-lactam rings.
#
#   4. chemical_space     "enamine_real" restricts generation to molecules
#                         Enamine can actually synthesise - roughly 94.5 billion
#                         compounds built from ~202,000 in-stock building blocks
#                         through ~170 validated parallel-synthesis reactions.
#                         THIS IS THE MOST CONSEQUENTIAL SETTING IN THE SCRIPT.
#                         It is why the output is orderable. It is also why no
#                         beta-lactam warheads appear: strained four-membered
#                         lactams are not reachable by parallel amide coupling,
#                         so they are absent from the sampling pool entirely.
#
#   Filters applied: the recommended SMARTS catalog, PAINS (pan-assay
#   interference compounds), and Lipinski's rule of five allowing one violation.
#   All three are EXCLUSION filters - they remove molecules. There is no
#   "must contain this substructure" filter in use here.
#
# PREREQUISITE: Block 1 must have run in this same window ($boltz must be set).
#
# COST: roughly $25 for 1,000 molecules. estimate-cost prints the real figure
#       before you commit - read it before answering the prompt.
# =============================================================================

# --- Job identity ------------------------------------------------------------
$runName      = "PDFA-1BTL-TEM1-smallmol-design-v1"
$numMolecules = 1000
$inputJson    = "$env:USERPROFILE\Downloads\boltz_input_$runName.json"

# --- Target: TEM-1 mature sequence from cleaned 1BTL -------------------------
$proteinSeq = "HPETLVKVKDAEDQLGARVGYIELDLNSGKILESFRPEERFPMMSTFKVLLCGAVLSRIDAGQEQLGRRIHYSQNDLVEYSPVTEKHLTDGMTVRELCSAAITMSDNTAANLLLTTIGGPKELTAFLHNMGDHVTRLDRWEPELNEAIPNDERDTTMPVAMATTLRKLLTGELLTLASRQQLIDWMEADKVAGPLLRSALPAGWFIADKSGAGERGSRGIIAALGPDGKPSRIVVIYTTGSQATMDERNRQIAEIGASLIKHW"

# --- Binding site: catalytic residues, zero-indexed --------------------------
# 44=Ser70  47=Lys73  104=Ser130  106=Asn132  140=Glu166  208=Lys234
$pocketResidues = @{ A = @(44, 47, 104, 106, 140, 208) }

# --- Reference ligands: five FDA-approved TEM-1 active-site binders ----------
$referenceLigands = @(
    # Ampicillin      C16H19N3O4S  MW 349.41  - substrate
    "CC1(C(N2C(S1)C(C2=O)NC(=O)C(C3=CC=CC=C3)N)C(=O)O)C",
    # Amoxicillin     C16H19N3O5S  MW 365.41  - substrate
    "CC1(C(N2C(S1)C(C2=O)NC(=O)C(C3=CC=C(C=C3)O)N)C(=O)O)C",
    # Clavulanic acid C8H9NO5      MW 199.16  - mechanism-based inhibitor
    "C1C2N(C1=O)C(C(=CCO)O2)C(=O)O",
    # Sulbactam       C8H11NO5S    MW 233.24  - mechanism-based inhibitor
    "CC1(C(N2C(S1(=O)=O)CC2=O)C(=O)O)C",
    # Avibactam       C7H11N3O6S   MW 265.25  - non-beta-lactam (DBO) inhibitor
    "C1CC(N2CC1N(C2=O)OS(=O)(=O)O)C(=O)N"
)

# --- Filters (all exclusion-only) --------------------------------------------
$moleculeFilters = @{
    boltz_smarts_catalog_filter_level = "recommended"
    custom_filters = @(
        @{ type = "smarts_catalog_filter"; catalog = "PAINS" },
        @{ type = "lipinski_filter"
           max_mw  = 500
           max_logp = 5
           max_hbd = 5
           max_hba = 10
           allow_single_violation = $true }
    )
}

# --- Assemble the payload ----------------------------------------------------
$payload = @{
    num_molecules    = $numMolecules
    idempotency_key  = $runName
    chemical_space   = "enamine_real"
    molecule_filters = $moleculeFilters
    target = @{
        type = "no_template"
        entities = @(
            @{ type = "protein"; chain_ids = @("A"); value = $proteinSeq }
        )
        pocket_residues   = $pocketResidues
        reference_ligands = $referenceLigands
    }
}

# --- Write JSON as UTF-8 WITHOUT a byte-order mark ---------------------------
# PowerShell's Out-File and Set-Content add a BOM by default, and the API
# rejects the file if one is present. This is the single most common way this
# script fails. Use the .NET writer explicitly.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($inputJson, ($payload | ConvertTo-Json -Depth 20), $utf8NoBom)

Write-Host "Wrote input JSON to: $inputJson" -ForegroundColor Green

# --- Reference the file with forward slashes ---------------------------------
# The @json:// prefix tells the CLI to read the payload from a file. Backslashes
# are not accepted inside that reference, so convert them.
$inputRef = "@json://$($inputJson.Replace('\','/'))"

# --- Price the job before paying for it --------------------------------------
Write-Host "`n--- ESTIMATING COST ---" -ForegroundColor Cyan
& $boltz small-molecule:design estimate-cost --input $inputRef

# --- Submit ------------------------------------------------------------------
# NOTE ON THE COMMAND NAME: it is `small-molecule:design`, not `molecule:design`.
# The short form silently dumps the help text instead of erroring, and the help
# text can be mistaken for output. If you see a wall of usage information here,
# check the command name first.
Write-Host "`n--- SUBMITTING JOB ---" -ForegroundColor Cyan
$jobId = & $boltz small-molecule:design start `
    --idempotency-key $runName `
    --input $inputRef `
    --raw-output `
    --transform id

Write-Host "`nJob ID: $jobId" -ForegroundColor Green
$jobId | Set-Content "$env:USERPROFILE\Downloads\boltz_design_jobid.txt"


# =============================================================================
# WHAT YOU SHOULD SEE IF IT WORKED
# =============================================================================
#
#   Wrote input JSON to: C:\Users\<you>\Downloads\boltz_input_PDFA-1BTL-...json
#
#   --- ESTIMATING COST ---
#   a cost breakdown ending in a total around $25.00 for 1,000 molecules
#
#   --- SUBMITTING JOB ---
#
#   Job ID: sm_des_v2_XXXXXXXXXXXXXXXXXXXX
#
#   A real job ID starts with `sm_des_v2_` followed by 20 characters. It is
#   saved to Downloads\boltz_design_jobid.txt so you do not lose it.
#
#   The run that produced the published dataset was:
#       sm_des_v2_AAR7FZn7jhbDYxMzcitf       1000/1000 succeeded, $25
#
# IF IT FAILS
#
#   A page of usage text instead of a job ID
#       Wrong command name. It is `small-molecule:design`, not `molecule:design`.
#       The flag `--idempotency-key` is correct - that was never the problem.
#
#   "Incorrect Usage: flag provided but not defined"
#       You are on the wrong subcommand, so the flags do not exist there.
#       Run `& $boltz small-molecule:design --help` to see valid flags.
#
#   JSON parse error from the API
#       Almost always the byte-order mark. Re-run the WriteAllText line above;
#       do not substitute Out-File or Set-Content.
#
#   The job returns instantly with the same ID as a previous run
#       That is the idempotency key doing its job. Same key = same job, not a
#       new one. Change $runName if you genuinely want a fresh run.
# =============================================================================
