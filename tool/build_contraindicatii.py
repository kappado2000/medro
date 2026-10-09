"""Construieste assets/data/contraindicatii.json.gz: sectiunea 4.3 „Contraindicatii”
extrasa din RCP-ul fiecarui medicament (PDF-urile ANMDM si EMA din nomenclator).

Textul este cel din RCP, nemodificat in afara curatarii spatiilor. Descarcarea
e lenta (mii de PDF-uri, servere care limiteaza ritmul), asa ca rezultatele se
pastreaza in tool/cache/contraindicatii.json si scriptul reia de unde a ramas.
Psihotropele (ATC N05, N06, N03) se proceseaza primele.

Se ruleaza dupa build_medicamente.py.
Rulare:  python tool/build_contraindicatii.py [--limita N] [--reia-goale] [--doar-asset] [--test URL]
"""
import gzip
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parent.parent
MEDICAMENTE = ROOT / "assets" / "data" / "medicamente.json.gz"
CACHE = ROOT / "tool" / "cache" / "contraindicatii.json"
OUT = ROOT / "assets" / "data" / "contraindicatii.json.gz"
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "Chrome/126 Safari/537.36"
)
MAX_CARACTERE = 4000
# Titlul sectiunii, cu sau fara diacritice. Numarul "4.3" poate fi lipit de
# titlu, separat prin spatii sau pe alt rand (in unele PDF-uri e in alta coloana).
INCEPUT = re.compile(r"(?m)^\s*(?:4\s*\.\s*3\.?\s*)?Contraindica[tţț]ii\s*$", re.I)
SFARSIT = re.compile(
    r"(?m)^\s*(?:4\s*\.\s*4\.?\s*)?"
    r"(?:Aten[tţț]ion[aăã]ri\s+[sşș]i\s+precau[tţț]ii|Precau[tţț]ii\s+[sşș]i\s+aten[tţț]ion[aăã]ri"
    r"|Aten[tţț]ion[aăã]ri\s+speciale|Precau[tţț]ii\s+speciale)",
    re.I,
)


def descarca(url: str, destinatie: str) -> str:
    """Intoarce "ok", "lipsa" (404) sau ridica dupa mai multe incercari esuate."""
    for asteptare in (30, 120, 300, 900, 1800, None):
        r = subprocess.run(
            ["curl", "-s", "-L", "-o", destinatie, "--max-time", "180", "-A", UA,
             "-w", "%{http_code}", url],
            capture_output=True,
            text=True,
        )
        cod = r.stdout.strip()
        if cod == "200":
            return "ok"
        if cod in ("404", "410"):
            return "lipsa"
        if asteptare is None:
            raise RuntimeError(f"serverul nu raspunde (HTTP {cod or '000'}) pentru {url}")
        print(f"  HTTP {cod or '000'}; astept {asteptare}s", flush=True)
        time.sleep(asteptare)
    return "lipsa"


def curata(text: str) -> str:
    randuri = [re.sub(r"[ \t]+", " ", r).strip() for r in text.split("\n")]
    # numerele de pagina raman ca randuri izolate
    # numerele de pagina si numerele de sectiune ramase singure pe rand
    randuri = [r for r in randuri if r and not re.fullmatch(r"\d{1,3}|\d\s*\.\s*\d\.?", r)]
    out: list[str] = []
    for r in randuri:
        # un rand nou incepe la liniuta/bulina sau dupa un rand incheiat cu punct
        nou = (
            not out
            or re.match(r"^[-•–·]\s*", r)
            or out[-1].endswith((".", ":", ";"))
        )
        if nou:
            out.append(re.sub(r"^[•–·]\s*", "- ", r))
        else:
            out[-1] += " " + r
    return "\n".join(out).strip()


def extrage(cale_pdf: str) -> str:
    """Sectiunea 4.3 din primul RCP al documentului, sau "" daca nu se gaseste."""
    try:
        doc = fitz.open(cale_pdf)
    except Exception:
        return ""
    text = ""
    for i, pagina in enumerate(doc):
        text += pagina.get_text() + "\n"
        # sectiunea 4.3 e in primele pagini; nu citim tot un document de sute de pagini
        if i >= 3 and SFARSIT.search(text) and INCEPUT.search(text):
            break
        if i >= 40:
            break
    inceput = INCEPUT.search(text)
    if not inceput:
        return ""
    sfarsit = SFARSIT.search(text, inceput.end())
    if not sfarsit:
        return ""
    return curata(text[inceput.end() : sfarsit.start()])[:MAX_CARACTERE]


def scrie_asset(cache: dict) -> None:
    gasite = {u: t for u, t in cache.items() if t}
    raw = json.dumps(gasite, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    OUT.write_bytes(gzip.compress(raw, 9))
    print(f"Asset: {len(gasite)} RCP-uri cu contraindicatii extrase, "
          f"{OUT.stat().st_size / 1e6:.2f} MB gzip", flush=True)


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    tmp = os.path.join(tempfile.gettempdir(), "medro_rcp.pdf")

    if "--test" in sys.argv:
        url = sys.argv[sys.argv.index("--test") + 1]
        print(descarca(url, tmp))
        print(extrage(tmp) or "(sectiunea nu a fost gasita)")
        return

    produse = json.loads(gzip.open(MEDICAMENTE).read())["products"]
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    if "--reia-goale" in sys.argv:
        # documentele fara text se reincearca (de exemplu dupa imbunatatirea regulilor)
        cache = {u: t for u, t in cache.items() if t}
    if "--doar-asset" in sys.argv:
        scrie_asset(cache)
        return

    # psihotropele intai, apoi restul; fiecare RCP o singura data
    psihotrop = lambda p: p["a"][:3] in ("N05", "N06", "N03")
    ordine = sorted(produse, key=lambda p: (not psihotrop(p), p["e"], p["n"]))
    urluri = list(dict.fromkeys(p["r"] for p in ordine if p["r"]))
    de_facut = [u for u in urluri if u not in cache]
    limita = int(sys.argv[sys.argv.index("--limita") + 1]) if "--limita" in sys.argv else None
    if limita is not None:
        de_facut = de_facut[:limita]
    print(f"{len(urluri)} RCP-uri unice, {len(cache)} deja procesate, {len(de_facut)} de procesat",
          flush=True)

    for i, url in enumerate(de_facut, 1):
        stare = descarca(url, tmp)
        cache[url] = extrage(tmp) if stare == "ok" else ""
        if i % 20 == 0 or i == len(de_facut):
            CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
            gasite = sum(1 for t in cache.values() if t)
            print(f"  {i}/{len(de_facut)}  cu text: {gasite} din {len(cache)}", flush=True)
        if i % 200 == 0:
            scrie_asset(cache)
        time.sleep(1.5 if "ema.europa.eu" not in url else 4)
    scrie_asset(cache)


if __name__ == "__main__":
    main()
