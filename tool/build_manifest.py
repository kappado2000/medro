"""Scrie assets/data/manifest.json: versiunea datelor si suma de control a
fiecarui fisier. Aplicatia il foloseste ca sa afle ce fisiere s-au schimbat
cand verifica actualizarile (vezi lib/services/data_store.dart).

Se ruleaza dupa orice script care regenereaza date.
Rulare:  python tool/build_manifest.py
"""
import datetime
import gzip
import hashlib
import json
from pathlib import Path

DATE = Path(__file__).resolve().parent.parent / "assets" / "data"


def main() -> None:
    fisiere = {}
    for f in sorted(DATE.rglob("*.json.gz")):
        date = f.read_bytes()
        fisiere[f.relative_to(DATE).as_posix()] = {
            "sha256": hashlib.sha256(date).hexdigest(),
            "marime": len(date),
        }
    surse = {}
    med = DATE / "medicamente.json.gz"
    if med.exists():
        surse["Nomenclator ANMDM"] = json.loads(gzip.open(med).read())["updated"]
    comp = DATE / "compensare.json.gz"
    if comp.exists():
        surse["Lista CNAS"] = json.loads(gzip.open(comp).read())["data"]
    surse["Interacțiuni"] = "DDInter 2.0"
    surse["ICD-10"] = "RoDRG, 2011"
    versiune = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M")
    tinta = DATE / "manifest.json"
    if tinta.exists():
        vechi = json.loads(tinta.read_text(encoding="utf-8"))
        # date neschimbate: versiunea ramane, ca aplicatiile sa nu descarce nimic
        if vechi.get("fisiere") == fisiere and vechi.get("surse") == surse:
            versiune = vechi["versiune"]
    manifest = {
        # ordinea alfabetica a versiunilor este si cea cronologica
        "versiune": versiune,
        "surse": surse,
        "fisiere": fisiere,
    }
    (DATE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    total = sum(v["marime"] for v in fisiere.values())
    print(f"manifest: versiunea {manifest['versiune']}, {len(fisiere)} fisiere, {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
