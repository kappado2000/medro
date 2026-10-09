"""Construieste assets/data/protocoale.json.gz: indexul protocoalelor terapeutice
publicate de CNAS (https://cnas.ro/protocoale-terapeutice/).

CNAS publica o lista completa (un tabel cu codul, denumirea, sublista si cine
poate continua prescrierea) si volumele cu textul protocoalelor, apoi fisiere
lunare doar cu protocoalele modificate. Fiecare protocol are un semn de carte
"<COD>.pdf" in PDF, din care se afla pagina la care incepe. Aplicatia nu
copiaza textul: retine codul, denumirea si legatura catre pagina din PDF.

La o actualizare noua pe site se adauga fisierul la sfarsitul listei FISIERE.
Rulare:  python tool/build_protocoale.py
"""
import gzip
import io
import json
import re
import subprocess
import sys
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tool" / "cache" / "protocoale"
OUT = ROOT / "assets" / "data" / "protocoale.json.gz"
BAZA = "https://cnas.ro/wp-content/uploads/"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126 Safari/537.36"

# lista completa, fara textul protocoalelor
LISTA = "2025/12/lista-protocoalelor-terapeutice-NOV-2025-TOATE.pdf"
# in ordine cronologica: un protocol dintr-un fisier mai nou il inlocuieste pe cel vechi
FISIERE = [
    "2025/12/A-C-Inclusiv.pdf",
    "2025/12/D-L-PRIMA-PARTE.pdf",
    "2025/12/D-L-A-2-A-PARTE.pdf",
    "2025/12/M-V-Toate-combinate.pdf",
    "2026/01/ALL-lista-protocoalelor-terapeutice-ianuarie-2026-pentru-site.pdf",
    "2026/03/ALL.pdf",
    "2026/05/ALL-lista-protocoalelor-terapeutice-APRILIE-2026.pdf",
    "2026/07/ALL-lista-protocoalelor-terapeutice-IULIE-2026.pdf",
]
DATA = "iulie 2026"

# inceputul coloanei "sublista / cod boala / cod P"
SUBLISTA = re.compile(r"^\s*(A|B|D|C\s?[123])(\b|$)(?!\w)")


def descarca(cale: str) -> Path:
    tinta = CACHE / cale.replace("/", "_")
    if not tinta.exists() or tinta.stat().st_size == 0:
        print("  descarc", cale)
        # -k: certificatul site-ului CNAS a fost gasit expirat; documentele sunt publice
        subprocess.run(
            ["curl", "-s", "-k", "-L", "--max-time", "1200", "-A", UA, "-o", str(tinta), BAZA + cale],
            check=True,
        )
    return tinta


def curata(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def randuri_lista(pdf: fitz.Document, pagini, coduri: set) -> dict:
    """cod -> (denumire, sublista, continuare la medicul de familie), din tabel."""
    linii = []
    for i in pagini:
        linii += [l.strip() for l in pdf[i].get_text().split("\n")]
    # antetul tabelului se repeta pe fiecare pagina, dupa numarul ei ("5/6")
    antet = {"COD PROTOCOL", "COD", "PROTOCOL", "DENUMIRE", "sublista/cod boala/cod P",
             "continuare prescriere medic familie"}
    linii = [l for l in linii if l and l not in antet and not re.fullmatch(r"\d+/\d+", l)]
    starturi = [i for i, l in enumerate(linii) if l in coduri]
    rezultat = {}
    for n, i in enumerate(starturi):
        sfarsit = starturi[n + 1] if n + 1 < len(starturi) else len(linii)
        rand = linii[i + 1 : sfarsit]
        k = next((j for j, l in enumerate(rand) if j > 0 and SUBLISTA.match(l)), None)
        if k is None:
            rezultat[linii[i]] = (curata(" ".join(rand)), "", "")
            continue
        rezultat[linii[i]] = (
            curata(" ".join(rand[:k])),
            curata(rand[k]),
            curata(" ".join(rand[k + 1 :])),
        )
    return rezultat


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    CACHE.mkdir(parents=True, exist_ok=True)

    pagini = {}  # cod -> (url, pagina)
    liste = []  # (pdf, paginile cu tabel)
    for cale in FISIERE:
        pdf = fitz.open(descarca(cale))
        prima = None
        for _, titlu, pagina in pdf.get_toc():
            if not titlu.lower().endswith(".pdf"):
                continue
            cod = titlu[:-4].strip()
            if cod.lower().startswith("lista"):
                continue
            pagini[cod] = (BAZA + cale, pagina)
            prima = pagina if prima is None else min(prima, pagina)
        # fisierele lunare incep cu tabelul protocoalelor modificate
        if prima and prima > 1:
            liste.append((pdf, range(prima - 1)))
        print(f"  {cale}: {len(pdf)} pagini")

    coduri = set(pagini)
    complet = fitz.open(descarca(LISTA))
    detalii = randuri_lista(complet, range(len(complet)), coduri)
    for pdf, pg in liste:
        detalii.update(randuri_lista(pdf, pg, coduri))

    protocoale = []
    fara_detalii = []
    for cod in sorted(pagini):
        url, pagina = pagini[cod]
        denumire, sublista, mf = detalii.get(cod, ("", "", ""))
        if not denumire:
            fara_detalii.append(cod)
        protocoale.append([cod, denumire, sublista, mf, url, pagina])
    fara_text = sorted(set(detalii) - coduri)

    OUT.write_bytes(
        gzip.compress(
            json.dumps(
                {"data": DATA, "sursa": "https://cnas.ro/protocoale-terapeutice/", "protocoale": protocoale},
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8"),
            mtime=0,
        )
    )
    print(f"{len(protocoale)} protocoale -> {OUT.name} ({OUT.stat().st_size / 1024:.0f} KB)")
    print(f"fara rand in lista: {len(fara_detalii)} {fara_detalii[:20]}")
    print(f"in lista, fara text: {len(fara_text)} {fara_text[:20]}")
    for p in protocoale:
        if p[0].startswith("N0"):
            print("  ", p[0], "|", p[1][:70], "|", p[2][:22], "|", p[3][:60], "|", p[5])


if __name__ == "__main__":
    main()
