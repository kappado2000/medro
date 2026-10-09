"""Construieste assets/data/interactiuni.json.gz din fisierele descarcabile DDInter 2.0
(https://ddinter2.scbdd.com/download/, licenta CC BY-NC-SA 4.0 - doar uz necomercial).

Fisierele contin perechi de substante cu nivelul de severitate (Major, Moderate,
Minor, Unknown), fara mecanism sau conduita. Denumirile sunt in engleza si se
potrivesc cu substantele active (DCI, in latina) din nomenclatorul ANMDM.

Se ruleaza dupa build_medicamente.py.   Rulare:  python tool/build_interactiuni.py [--debug]
"""
import collections
import csv
import gzip
import io
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tool" / "cache" / "ddinter"
MEDICAMENTE = ROOT / "assets" / "data" / "medicamente.json.gz"
OUT = ROOT / "assets" / "data" / "interactiuni.json.gz"
URL = "https://ddinter2.scbdd.com/static/media/download/ddinter_downloads_code_{}.csv"
# pagina de descarcare listeaza doar 8 clase ATC, dar exista fisiere pentru toate 14
CLASE = "ABCDGHJLMNPRSV"
NIVELURI = {"Major": 0, "Moderate": 1, "Minor": 2, "Unknown": 3}

# DCI din nomenclator -> denumirea folosita de DDInter, unde regula generala nu ajunge
# (denumiri americane, saruri, greseli de scriere din nomenclator)
ALIAS = {
    "PARACETAMOLUM": "Acetaminophen",
    "ADRENALINUM": "Epinephrine",
    "NORADRENALINUM": "Norepinephrine",
    "PETHIDINUM": "Meperidine",
    "CHLORPHENAMINUM": "Chlorpheniramine",
    "HCT": "Hydrochlorothiazide",
    "IRBERSARTANUM": "Irbesartan",
    "LITHIUM": "Lithium carbonate",
    "LITHII CARBONAS": "Lithium carbonate",
    "CICLOSPORINUM": "Cyclosporine",
    "GLIBENCLAMIDUM": "Glyburide",
    "LEVOMEPROMAZINUM": "Methotrimeprazine",
    "BECLOMETASONUM": "Beclomethasone dipropionate",
    "COLECALCIFEROLUM": "Cholecalciferol",
    "NATRII VALPROAS": "Valproic acid",
}


# substante fara niciun produs in nomenclator, pastrate pentru importanta lor clinica
SUPLIMENTARE = {"Lithium carbonate": "LITHIUM"}


def cheie(nume: str) -> str:
    """Forma comuna pentru denumirea latina si cea engleza a aceleiasi substante."""
    n = nume.lower().strip()
    n = re.sub(r"^acidum (\w+)um$", r"\1 acid", n)
    n = re.sub(r"(um|e|a)$", "", n)
    for a, b in (("ph", "f"), ("th", "t"), ("y", "i"), ("ae", "e"), ("oe", "e")):
        n = n.replace(a, b)
    n = re.sub(r"(.)\1", r"\1", n)
    return re.sub(r"[^a-z0-9]", "", n)


def componente(dci: str) -> list[str]:
    """Substantele dintr-un DCI: "COMBINATII (A+B)" -> ["A", "B"]."""
    fara = re.sub(r"^COMBINATII\s*\(?", "", dci).rstrip(")")
    return [c.strip(" ()") for c in re.split(r"\s*\+\s*", fara) if c.strip(" ()")]


def descarca() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    for clasa in CLASE:
        f = CACHE / f"code_{clasa}.csv"
        if f.exists() and f.read_bytes()[:7] == b"DDInter":
            continue
        req = urllib.request.Request(URL.format(clasa), headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=300) as r:
            f.write_bytes(r.read())
        time.sleep(2)


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    descarca()

    perechi: dict[tuple[str, str], int] = {}
    for clasa in CLASE:
        with open(CACHE / f"code_{clasa}.csv", encoding="utf-8", errors="replace") as f:
            for r in csv.DictReader(f):
                a, b = r["Drug_A"].strip(), r["Drug_B"].strip()
                if a != b:
                    perechi[tuple(sorted((a, b)))] = NIVELURI[r["Level"]]
    denumiri = {d for p in perechi for d in p}

    # variantele cu paranteze sunt cai de administrare locale ("(topical)", "(nasal)");
    # se potrivesc doar denumirile de baza, sistemice
    dupa_cheie = {}
    for d in sorted(denumiri):
        if "(" not in d:
            dupa_cheie.setdefault(cheie(d), d)

    def potriveste(componenta: str) -> str | None:
        if componenta in ALIAS:
            return ALIAS[componenta] if ALIAS[componenta] in denumiri else None
        gasit = dupa_cheie.get(cheie(componenta))
        if gasit:
            return gasit
        # sare sau ester: "DABIGATRANUM ETEXILATUM", "FLUTICASONUM PROPIONAT"
        primul = componenta.split()[0]
        # conjugatele anticorp-medicament sunt alte substante decat anticorpul simplu
        if re.search(r"EMTANSIN|DERUXTECAN|VEDOTIN|GOVITECAN|OZOGAMICIN", componenta):
            return None
        if len(primul) > 6 and primul != componenta:
            return dupa_cheie.get(cheie(primul))
        return None

    produse = json.loads(gzip.open(MEDICAMENTE).read())["products"]
    en_la_ro: dict[str, set[str]] = collections.defaultdict(set)
    dci_la_en: dict[str, list[str]] = {}
    nepotrivite = collections.Counter()
    for p in produse:
        dci = p["d"]
        if not dci:
            continue
        gasite = []
        for c in componente(dci):
            en = potriveste(c)
            if en:
                en_la_ro[en].add(c)
                gasite.append(en)
            else:
                nepotrivite[(c, p["a"][:1])] += 1
        if gasite:
            dci_la_en[dci] = sorted(set(gasite))

    for en, ro in SUPLIMENTARE.items():
        if en in denumiri:
            en_la_ro[en].add(ro)

    substante = sorted(en_la_ro)
    index = {en: i for i, en in enumerate(substante)}
    vecini: dict[int, list[list[int]]] = {}
    total = 0
    for (a, b), nivel in perechi.items():
        if a in index and b in index:
            i, j = sorted((index[a], index[b]))
            vecini.setdefault(i, [[], [], [], []])[nivel].append(j)
            total += 1

    if "--debug" in sys.argv:
        print("potriviri prin alias sau prima parte a denumirii:")
        for en, ro in sorted(en_la_ro.items()):
            for c in ro:
                if cheie(c) != cheie(en):
                    print(f"  {c} -> {en}")
        print("nepotrivite, sistem nervos:",
              [(c, n) for (c, cls), n in nepotrivite.most_common() if cls == "N"][:60])

    out = {
        "sursa": "DDInter 2.0 (ddinter2.scbdd.com), licență CC BY-NC-SA 4.0",
        # [denumire DDInter, denumirile DCI din nomenclator]
        "substante": [[en, sorted(en_la_ro[en])] for en in substante],
        "dci": {d: [index[e] for e in ens] for d, ens in sorted(dci_la_en.items())},
        # i -> [majore, moderate, minore, necunoscute], doar cu j > i
        "perechi": {str(i): [sorted(v) for v in n] for i, n in sorted(vecini.items())},
    }
    raw = json.dumps(out, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    OUT.write_bytes(gzip.compress(raw, 9))
    cu_dci = sum(1 for p in produse if p["d"] in dci_la_en)
    print(f"DDInter: {len(perechi)} perechi, {len(denumiri)} substante")
    print(f"Potrivite cu nomenclatorul: {len(substante)} substante, {total} perechi; "
          f"{cu_dci} din {len(produse)} produse au cel putin o substanta acoperita")
    print(f"JSON: {len(raw) / 1e6:.2f} MB  gzip: {OUT.stat().st_size / 1e6:.2f} MB  -> {OUT}")


if __name__ == "__main__":
    main()
