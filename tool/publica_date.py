"""Pregateste folderul hosting/date/ din care aplicatia isi descarca datele noi
(vezi lib/services/data_store.dart) si verifica intai ca datele sunt intregi.

Dupa rulare, publicarea se face cu:  firebase deploy --only hosting
Rulare:  python tool/publica_date.py [--doar-verifica]
"""
import gzip
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATE = ROOT / "assets" / "data"
TINTA = ROOT / "hosting" / "date"

# sub aceste praguri, sursa a raspuns incomplet si datele nu se publica
MINIM = {
    "medicamente.json.gz": ("medicamente", 6500),
    "compensare.json.gz": ("ambalaje compensate", 4000),
    "icd10.json.gz": ("coduri", 10000),
}


def numara(continut) -> int:
    """Marimea celei mai mari colectii din fisier."""
    if isinstance(continut, list):
        return len(continut)
    return max(
        (len(v) for v in continut.values() if isinstance(v, (list, dict))), default=0
    )


def verifica() -> list[str]:
    probleme = []
    manifest = json.loads((DATE / "manifest.json").read_text(encoding="utf-8"))
    for nume, info in manifest["fisiere"].items():
        f = DATE / nume
        if not f.exists():
            probleme.append(f"{nume}: lipseste")
        elif hashlib.sha256(f.read_bytes()).hexdigest() != info["sha256"]:
            probleme.append(f"{nume}: difera de manifest (ruleaza build_manifest.py)")
    for nume, (ce, minim) in MINIM.items():
        f = DATE / nume
        if not f.exists():
            probleme.append(f"{nume}: lipseste")
            continue
        n = numara(json.loads(gzip.open(f).read()))
        print(f"  {nume}: {n} {ce}")
        if n < minim:
            probleme.append(f"{nume}: doar {n} {ce}, sub pragul de {minim}")
    return probleme


def main() -> None:
    probleme = verifica()
    if probleme:
        print("Datele NU se publica:")
        for p in probleme:
            print("  -", p)
        sys.exit(1)
    if "--doar-verifica" in sys.argv:
        print("Datele sunt intregi.")
        return
    if TINTA.exists():
        shutil.rmtree(TINTA)
    shutil.copytree(DATE, TINTA, ignore=shutil.ignore_patterns(".gitkeep"))
    total = sum(f.stat().st_size for f in TINTA.rglob("*") if f.is_file())
    print(f"hosting/date pregatit: {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
