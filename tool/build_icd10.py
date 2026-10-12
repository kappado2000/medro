"""Construieste assets/data/icd10.json.gz din Lista tabelara a diagnosticelor
RoDRG (CIM-10-AM in romana, iulie 2011).

Sursa: https://www.hosptm.ro/files/drg/rodrgv1/Lista_tabelara_a_diagnosticelor_RODRGv1.pdf

In PDF, codul si titlul sunt in Verdana 9, pe acelasi rand; titlul continua pe
randurile urmatoare la aceeasi pozitie orizontala. Descrierile de glosar sunt
in Garamond, iar notele (Include, Exclude) incep cu o eticheta in Arial.

Rulare:  python tool/build_icd10.py [--debug]
"""
import gzip
import io
import json
import re
import sys
import urllib.request
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "tool" / "cache" / "icd_rodrg.pdf"
OUT = ROOT / "assets" / "data" / "icd10.json.gz"
URL = "https://www.hosptm.ro/files/drg/rodrgv1/Lista_tabelara_a_diagnosticelor_RODRGv1.pdf"
# codul poate purta semnul de etiologie/manifestare (pumnal sau asterisc)
COD_SI_TITLU = re.compile(r"^([A-Z]\d\d(?:\.\d{1,2})?)[*†+]?(?:\s+(\S.*))?$")
# un titlu care se termina asa continua sigur pe randul urmator
NETERMINAT = re.compile(r"(,| (si|sau|de|a|la|cu|in|al|ale|din|prin|pe|parte))$")
# capitolele CIM-10, dupa prima litera si numarul categoriei
CAPITOLE = [
    ("A00", "B99", "I", "Boli infecțioase și parazitare"),
    ("C00", "D48", "II", "Tumori"),
    ("D50", "D89", "III", "Bolile sângelui și tulburări imunitare"),
    ("E00", "E90", "IV", "Boli endocrine, de nutriție și metabolism"),
    ("F00", "F99", "V", "Tulburări mentale și de comportament"),
    ("G00", "G99", "VI", "Bolile sistemului nervos"),
    ("H00", "H59", "VII", "Bolile ochiului și anexelor sale"),
    ("H60", "H95", "VIII", "Bolile urechii și apofizei mastoide"),
    ("I00", "I99", "IX", "Bolile aparatului circulator"),
    ("J00", "J99", "X", "Bolile aparatului respirator"),
    ("K00", "K93", "XI", "Bolile aparatului digestiv"),
    ("L00", "L99", "XII", "Bolile pielii și țesutului subcutanat"),
    ("M00", "M99", "XIII", "Bolile sistemului osteo-articular și țesutului conjunctiv"),
    ("N00", "N99", "XIV", "Bolile aparatului genito-urinar"),
    ("O00", "O99", "XV", "Sarcina, nașterea și lăuzia"),
    ("P00", "P96", "XVI", "Afecțiuni cu origine în perioada perinatală"),
    ("Q00", "Q99", "XVII", "Malformații congenitale și anomalii cromozomiale"),
    ("R00", "R99", "XVIII", "Simptome, semne și rezultate anormale"),
    ("S00", "T98", "XIX", "Leziuni traumatice și otrăviri"),
    ("U00", "U99", "XXII", "Coduri pentru scopuri speciale"),
    ("V01", "Y98", "XX", "Cauze externe de morbiditate și mortalitate"),
    ("Z00", "Z99", "XXI", "Factori care influențează starea de sănătate"),
]


def fragmente(pagina) -> list[dict]:
    """Fragmentele de text ale paginii, cu pozitie si font."""
    out = []
    mijloc = pagina.rect.width / 2
    for bloc in pagina.get_text("dict")["blocks"]:
        for linie in bloc.get("lines", []):
            for s in linie["spans"]:
                text = s["text"].strip()
                # simbolurile (Wingdings, Webdings) marcheaza doar reguli de codificare
                if not text or "dings" in s["font"]:
                    continue
                out.append(
                    {
                        "x": s["bbox"][0],
                        "y": linie["bbox"][1],
                        "col": 1 if s["bbox"][0] > mijloc else 0,
                        "font": s["font"],
                        "size": round(s["size"], 1),
                        "text": text,
                    }
                )
    return out


def e_titlu(r: dict) -> bool:
    # categoriile de 3 caractere sunt ingrosate, subcategoriile de obicei nu
    return r["font"] in ("Verdana", "Verdana,Bold") and r["size"] == 9.0


def extrage(doc) -> dict[str, str]:
    """Codurile si titlurile lor. PDF-ul foloseste mai multe asezari:
    cod si titlu in fragmente separate pe acelasi rand, cod si titlu in acelasi
    fragment, iar la categoriile de 3 caractere titlul centrat vertical fata de cod."""
    coduri: dict[str, str] = {}
    for pagina in doc:
        mijloc = pagina.rect.width / 2
        toate = fragmente(pagina)
        # randurile care incep cu o eticheta (Include:, Exclude:, Nota:) nu sunt titluri
        etichete = {(r["col"], round(r["y"])) for r in toate if r["font"].startswith("Arial")}
        titluri = [r for r in toate if e_titlu(r)]

        intrari = []
        for r in titluri:
            m = COD_SI_TITLU.match(r["text"])
            # codul sta la marginea stanga a coloanei; trimiterile din note nu
            margine = mijloc if r["col"] else 0
            if not m or r["x"] - margine > 95 or (m.group(2) or "").startswith(("-", "–")):
                continue
            intrari.append((r, m.group(1), m.group(2) or ""))
        y_coduri = [(r["col"], r["y"], cod) for r, cod, _ in intrari]
        fragmente_cod = {id(r) for r, _, _ in intrari}

        def liber(t: dict, cod: str) -> bool:
            """Randul nu e o nota si nu apartine altui cod."""
            if (t["col"], round(t["y"])) in etichete:
                return False
            return not any(
                c == t["col"] and k != cod and abs(y - t["y"]) <= 5 for c, y, k in y_coduri
            )

        for r, cod, inline in intrari:
            candidati = [
                t
                for t in titluri
                if t["col"] == r["col"] and id(t) not in fragmente_cod and t["x"] > r["x"] + 15
            ]
            if inline:
                randuri, x_titlu, font = [(r["y"], r["x"], inline)], None, r["font"]
            else:
                # titlul e pe randul codului; la categorii poate incepe putin mai sus
                toleranta = 13 if len(cod) == 3 else 3
                aproape = [t for t in candidati if abs(t["y"] - r["y"]) <= toleranta]
                if not aproape:
                    continue
                ancora = min(aproape, key=lambda t: (abs(t["y"] - r["y"]), t["x"]))
                x_titlu, font = ancora["x"], ancora["font"]
                randuri = [(ancora["y"], ancora["x"], ancora["text"])]

            def continua(y_curent: float, sens: int):
                nonlocal x_titlu
                while True:
                    urm = [
                        t
                        for t in candidati
                        if t["font"] == font
                        and 8 <= sens * (t["y"] - y_curent) <= 12.5
                        and (
                            x_titlu is None
                            or abs(t["x"] - x_titlu) <= 1
                            # subdiviziunile isi continua uneori titlul cu alta indentare
                            or (sens == 1 and NETERMINAT.search(randuri[-1][2]))
                        )
                        and liber(t, cod)
                    ]
                    if not urm:
                        return
                    t = min(urm, key=lambda t: t["x"])
                    x_titlu = t["x"]
                    randuri.append((t["y"], t["x"], t["text"]))
                    y_curent = t["y"]

            continua(randuri[0][0], 1)
            if len(cod) == 3 and not inline:
                continua(randuri[0][0], -1)

            titlu = re.sub(r"\s+", " ", " ".join(t for _, _, t in sorted(randuri))).strip()
            if titlu:
                coduri.setdefault(cod, titlu)
    return coduri


# F10-F19 nu enumera subcategoriile: al patrulea caracter e comun tuturor
# substantelor. Formularile de mai jos sunt cele standard din CIM-10.
SUBSTANTE_F1 = {
    "0": "intoxicatie acuta",
    "1": "utilizare nociva",
    "2": "sindrom de dependenta",
    "3": "stare de sevraj",
    "4": "stare de sevraj cu delirium",
    "5": "tulburare psihotica",
    "6": "sindrom amnezic",
    "7": "tulburare psihotica reziduala si cu debut tardiv",
    "8": "alte tulburari mentale si de comportament",
    "9": "tulburare mentala si de comportament nespecificata",
}


def completeaza_f1(coduri: dict[str, str]) -> int:
    adaugate = 0
    for n in range(10, 20):
        categorie = f"F{n}"
        if categorie not in coduri:
            continue
        for caracter, stare in SUBSTANTE_F1.items():
            cod = f"{categorie}.{caracter}"
            if cod not in coduri:
                coduri[cod] = f"{coduri[categorie]} – {stare}"
                adaugate += 1
    return adaugate


# F70-F79 (retardarea mentala): al patrulea caracter descrie deficienta de
# comportament, cu formularile standard din CIM-10.
COMPORTAMENT_F7 = {
    "0": "deficienta de comportament absenta sau minima",
    "1": "deficienta semnificativa de comportament, necesitand supraveghere sau tratament",
    "8": "alte deficiente de comportament",
    "9": "fara mentionarea deficientei de comportament",
}


def completeaza_f7(coduri: dict[str, str]) -> int:
    adaugate = 0
    for n in (70, 71, 72, 73, 78, 79):
        categorie = f"F{n}"
        if categorie not in coduri:
            continue
        for caracter, stare in COMPORTAMENT_F7.items():
            cod = f"{categorie}.{caracter}"
            if cod not in coduri:
                coduri[cod] = f"{coduri[categorie]} – {stare}"
                adaugate += 1
    return adaugate


def capitol(cod: str) -> int:
    categorie = cod[:3]
    for i, (de_la, pana_la, _, _) in enumerate(CAPITOLE):
        if de_la <= categorie <= pana_la:
            return i
    return -1


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if not PDF.exists():
        PDF.parent.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=600) as r:
            PDF.write_bytes(r.read())
    coduri = extrage(fitz.open(PDF))
    sintetizate = completeaza_f1(coduri) + completeaza_f7(coduri)

    if "--debug" in sys.argv:
        import collections

        print("total:", len(coduri), "din care F10-F19 compuse:", sintetizate)
        categorii = [c for c in coduri if len(c) == 3]
        fara = [c for c in categorii if not any(k.startswith(c + ".") for k in coduri)]
        print("categorii:", len(categorii), "fara subcategorii:", len(fara), fara[:40])
        print("pe lungime cod:", collections.Counter(len(c) for c in coduri))
        print("pe capitol:", collections.Counter(capitol(c) for c in coduri))
        for c in ("F20", "F20.0", "F32", "F32.0", "F32.00", "F41.1", "I10", "J18.0", "E11.9",
                  "K35.9", "A09", "Z00.0", "F10.2", "G40.0", "S72.0", "S72.00", "O80",
                  "F31.4", "F33.2", "F43.1", "F90.0", "F84.0", "G30.0", "J18.1", "F06.3"):
            print(f"  {c:8} {coduri.get(c)}")
        lungi = sorted(coduri.items(), key=lambda kv: -len(kv[1]))[:12]
        for c, t in lungi:
            print(f"  LUNG {c:8} ({len(t)}) {t[:230]}")
        return

    out = {
        "sursa": "Lista tabelară a bolilor RoDRG (CIM-10-AM), iulie 2011",
        "capitole": [[nr, titlu, de_la, pana_la] for de_la, pana_la, nr, titlu in CAPITOLE],
        "coduri": [[c, coduri[c], capitol(c)] for c in sorted(coduri)],
    }
    raw = json.dumps(out, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    OUT.write_bytes(gzip.compress(raw, 9, mtime=0))  # mtime fix: acelasi continut da acelasi fisier
    print(f"{len(coduri)} coduri; JSON {len(raw) / 1e6:.2f} MB, gzip {OUT.stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
