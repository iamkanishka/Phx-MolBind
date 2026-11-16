#!/usr/bin/env python3
"""Audit priv/catalog/molecules.json against RDKit.

Requires RDKit (`pip install rdkit`). RDKit is an audit tool only; the
Phoenix app never imports it. Exits non-zero on any mismatch so it can run in CI.

Checks, per molecule:
  * the SMILES parses;
  * the stored formula equals the formula RDKit computes;
  * the listed molecular weight is within 0.02 g/mol of the computed weight;
  * the stored stereocentre counts match RDKit's (total and defined);
  * ids and names are unique.
"""
import json
import pathlib
import sys

from rdkit import Chem
from rdkit.Chem import Descriptors, rdMolDescriptors

path = pathlib.Path(__file__).with_name("molecules.json")
data = json.loads(path.read_text(encoding="utf-8"))
problems = []
seen_ids, seen_names = set(), set()

for entry in data["molecules"]:
    name = entry["name"]
    if entry["id"] in seen_ids or name.lower() in seen_names:
        problems.append(f"{name}: duplicate id or name")
    seen_ids.add(entry["id"])
    seen_names.add(name.lower())

    mol = Chem.MolFromSmiles(entry["smiles"])
    if mol is None:
        problems.append(f"{name}: SMILES does not parse")
        continue

    formula = rdMolDescriptors.CalcMolFormula(mol)
    if formula != entry["formula"]:
        problems.append(f"{name}: formula {entry['formula']} != computed {formula}")

    weight = Descriptors.MolWt(mol)
    if abs(weight - entry["molecular_weight"]) > 0.02:
        problems.append(f"{name}: listed MW {entry['molecular_weight']} != computed {weight:.2f}")

    centres = Chem.FindMolChiralCenters(mol, includeUnassigned=True, useLegacyImplementation=False)
    defined = sum(1 for _, label in centres if label != "?")
    if (len(centres), defined) != (entry["stereocentres"], entry["stereocentres_defined"]):
        problems.append(
            f"{name}: stereocentres {entry['stereocentres_defined']}/{entry['stereocentres']} "
            f"!= computed {defined}/{len(centres)}"
        )

if problems:
    print("CATALOG AUDIT FAILED")
    for p in problems:
        print(" -", p)
    sys.exit(1)
print(f"Catalog audit passed: {len(data['molecules'])} molecules")
