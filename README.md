# AI-guided small-molecule design against TEM-1 β-lactamase

PowerShell pipeline for designing, validating and ranking small-molecule
inhibitors of TEM-1 β-lactamase (PDB **1BTL**) using the Boltz API.

Final-year research project, Department of Chemistry, University of Benin,
Nigeria. Target: restore ampicillin activity against β-lactamase-producing
*Escherichia coli*.

---

## What this pipeline does

```
  1BTL (cleaned PDB)
          │
          ▼
  BoltzMol-1 generative design ──────────── 1,000 molecules
  constrained to Enamine REAL space          (chemical_space = "enamine_real")
          │
          ▼
  Boltz-2.1 independent refold ──────────── 2 × 500 molecules
  (same target, different model, cold scoring)
          │
          ▼
  Join on SMILES → ranked CSV ───────────── final shortlist
```

The refold step exists because the design model scored its own output.
Re-scoring with a different model against the same target gives an
independent check before anything gets ordered.

---

## Scripts — run in order

| # | Script | What it does |
|---|---|---|
| 1 | `scripts/01_auth.ps1` | Locate `boltz-api.exe`, log in, confirm workspace |
| 2 | `scripts/02_submit_design.ps1` | Build the job spec, price it, submit 1,000-molecule design |
| 3 | `scripts/03_check_status.ps1` | Poll progress |
| 4 | `scripts/04_download_designs.ps1` | Paginate all 1,000 designs out, write JSON + CSV + ADMETLab batches |
| 5 | `scripts/05_refold_boltz21.ps1` | Submit 2 × 500 refold jobs to Boltz-2.1 |
| 6 | `scripts/06_download_refold_results.ps1` | Collect both batches, join on SMILES, write the final ranked CSV |

Every script carries a header explaining what it does and a footer showing
**exactly what the terminal should print if it worked**, plus the failure
modes that actually occurred during this project and how each was fixed.

Open PowerShell, paste one block, read the output, move on. `$boltz` and
`$jobId` live in the session, so if you close the window, re-run Block 1
before continuing.

---

## Reference run

These are the real job IDs that produced the dataset:

| Stage | Job ID | Result |
|---|---|---|
| Design | `sm_des_v2_AAR7FZn7jhbDYxMzcitf` | 1000 / 1000 succeeded — $25 |
| Refold batch 1 | `sm_scr_87F8ZAKkTuMPHCIQttcB` | 500 / 500 |
| Refold batch 2 | `sm_scr_3HzrUdHIgvoelkOqTaoS` | 500 / 500 |

Workspace: `ws_ofxdZ7MGM889W5ZPN7R4`

---

## The four settings that decide what you get back

**`chemical_space = "enamine_real"`** — the most consequential line in the
whole pipeline. It restricts generation to Enamine REAL: ~94.5 billion
molecules enumerated from ~202,000 in-stock building blocks through ~170
validated parallel-synthesis reactions. This is why the output is orderable
at ~$100 and three weeks per compound instead of being beautiful and
unmakeable.

It is also why **no β-lactam warheads appear in the output**. A strained
four-membered lactam is not reachable by parallel amide coupling, so those
molecules are absent from the sampling pool by construction. That is a
deliberate trade — synthetic accessibility bought at the cost of warhead
chemistry — and it belongs in any write-up of this method.

**`pocket_residues`** — zero-indexed positions of the six catalytic residues
(Ser70, Lys73, Ser130, Asn132, Glu166, Lys234). See `data/pocket_residues.md`
for the index arithmetic and the docking-box coordinates derived from them.

**`reference_ligands`** — five FDA-approved TEM-1 active-site binders. These
sit inside the `target` block alongside `pocket_residues`, and everything in
that block answers one question: *where on this protein should molecules
bind?* They define the pocket by the volume they occupy. They are **not** a
chemotype instruction — the model is not being asked to imitate their
β-lactam rings.

**`molecule_filters`** — the recommended SMARTS catalog, PAINS, and Lipinski
with one violation allowed. All three are **exclusion** filters; they remove
molecules. No positive "must contain this substructure" filter is used.

---

## Reference data

| File | Contents |
|---|---|
| `data/1BTL_TEM1_sequence.txt` | 263-residue mature TEM-1 sequence (FASTA) |
| `data/reference_ligands.csv` | The five reference drugs with SMILES, formula, MW, InChIKey |
| `data/pocket_residues.md` | Catalytic-residue indices, index arithmetic, and PyRx/Vina grid coordinates |

---

## Known failure modes, already solved

These all happened during this project. The fixes are in the script footers.

**Wrong command name.** It is `small-molecule:design`, not `molecule:design`.
The short form prints help text rather than erroring, and that help text can
be mistaken for output. `--idempotency-key` was never the problem.

**UTF-8 BOM.** `Out-File` and `Set-Content` add a byte-order mark by default
and the API rejects the file. Use `[System.IO.File]::WriteAllText` with an
explicit `UTF8Encoding $false`.

**Backslashes in `@json://`.** Convert to forward slashes before building the
input reference.

**ADMETLab 3.0 returns HTTP 504** on 1,000 SMILES at once. Split into ten
batches of 100 — Block 4 writes them for you.

**Joining to ADMETLab output.** ADMETLab returns both `raw_smiles` (what you
submitted) and `smiles` (its own re-canonicalisation). Joining on `smiles`
lost 2 of 1,000 rows; joining on `raw_smiles` gave a clean 1000/1000. Always
join on the un-canonicalised column.

**Refold jobs are prefixed `sm_scr_`.** The prefix names the endpoint
(`small-molecule:screen` — "score these against this target"), not the model.
Boltz-2.1 is selected separately. This is correct behaviour.

---

## Subcommand names

The flags used here (`--input`, `--idempotency-key`, `--raw-output`,
`--transform`, `--limit`, `--after-id`) are stable. Subcommand vocabulary has
changed between CLI releases. If one is rejected, discover the current name
with:

```powershell
& $boltz small-molecule:design --help
& $boltz small-molecule:screen --help
```

and substitute. The pagination logic and payload structure are what matter
and do not change.

---

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Boltz API account with credit
- `boltz-api.exe` installed
- Optional, for downstream analysis: RDKit, ADMETLab 3.0 (web), PyRx /
  AutoDock Vina, Discovery Studio Visualizer

---

## Citation

If this pipeline is useful to you, please cite the accompanying paper
(in preparation).

**Laurence Jaboro** — Department of Chemistry, University of Benin, Nigeria
Co-founder & President, Protein Design for Africa
