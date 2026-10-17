# TEM-1 catalytic residues used as the binding-site definition

Indices passed to the API are **zero-indexed positions in the 263-residue
mature sequence**. PDB numbering for 1BTL starts the mature chain at His26,
so: zero-index = PDB number − 26.

| Zero-index | PDB residue | Role |
|---|---|---|
| 44 | Ser70 | Catalytic nucleophile; attacks the beta-lactam carbonyl |
| 47 | Lys73 | General base; activates Ser70 |
| 104 | Ser130 | Proton shuttle to the leaving-group nitrogen |
| 106 | Asn132 | Oxyanion-hole / substrate recognition |
| 140 | Glu166 | Deacylation general base |
| 208 | Lys234 | Binds the substrate carboxylate |

Geometric centre of all 47 atoms of these six residues, computed from
`1BTL_clean.pdb` — use this as the docking grid centre in PyRx/AutoDock Vina:

```
center_x = 7.960
center_y = 5.879
center_z = 39.523
size_x   = 24
size_y   = 22
size_z   = 26
```

Anchor atom coordinates for visual confirmation that the box is right:

```
Ser70  OG   ( 9.468,  6.772, 37.805)
Ser130 OG   ( 6.908,  9.212, 37.660)
Lys234 NZ   ( 5.222,  7.590, 35.947)
Glu166 OE1  (13.166,  5.553, 41.654)
Lys73  NZ   ( 8.398,  6.538, 40.489)
Asn132 ND2  (10.672,  7.752, 41.955)
```

The single sulfate ion in 1BTL (residue 291) sits at (8.96, 10.72, 35.26),
4.73 Å from Ser70 OG — genuinely in the active site, occupying the anion
pocket. It is removed during cleaning; dock into the apo site.
