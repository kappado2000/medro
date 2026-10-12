"""Construieste assets/data/medicamente.json.gz din Nomenclatorul ANMDM.

Surse:
  - https://nomenclator.anm.ro/files/nomenclator.xlsx  (datele despre ambalaje)
  - https://nomenclator.anm.ro/medicamente?page=N&limit=2000  (linkuri RCP / prospect)
  - tool/ema_links.json, generat de tool/resolve_ema.py  (medicamente autorizate centralizat)

Rulare:  python tool/build_medicamente.py
"""
import gzip
import html
import io
import json
import re
import sys
import time
import urllib.request
from collections import OrderedDict
from pathlib import Path

import openpyxl

from resolve_ema import base_name

BASE = "https://nomenclator.anm.ro"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tool" / "cache"
OUT = ROOT / "assets" / "data" / "medicamente.json.gz"
EMA_LINKS = ROOT / "tool" / "ema_links.json"
PAGE_SIZE = 2000
UA = {"User-Agent": "Mozilla/5.0 (medro data build)"}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers=UA)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except OSError as e:
            if attempt == 4:
                raise
            wait = 30 * (attempt + 1)
            print(f"  eroare retea ({e}); reincerc in {wait}s")
            time.sleep(wait)


def clean(v) -> str:
    if v is None:
        return ""
    # exportul contine caractere de control scrise ca _x0002_
    return re.sub(r"\s+", " ", re.sub(r"_x[0-9A-Fa-f]{4}_", "", str(v))).strip()


def pdf_link(url: str) -> str:
    """Pastreaza doar linkurile directe catre PDF (cele din registrul UE sunt generice)."""
    if not url.lower().endswith(".pdf"):
        return ""
    return url.replace("http://", "https://", 1)


def load_links() -> dict:
    """CIM -> (rcp, prospect), citite din paginile HTML ale nomenclatorului."""
    links = {}
    page = 1
    while True:
        cached = CACHE / f"page_{page}.html"
        if cached.exists():
            text = cached.read_text(encoding="utf-8")
        else:
            text = fetch(f"{BASE}/medicamente?page={page}&limit={PAGE_SIZE}").decode("utf-8")
            cached.write_text(text, encoding="utf-8")
            time.sleep(5)
        tags = re.findall(r"<[^>]*data-cim=\"[^\"]*\"[^>]*>", text)
        for tag in tags:
            attrs = dict(re.findall(r"data-([a-z]+)=\"([^\"]*)\"", tag))
            links[attrs["cim"]] = (
                html.unescape(attrs.get("linkrcp", "")).strip(),
                html.unescape(attrs.get("linkpro", "")).strip(),
            )
        print(f"  pagina {page}: {len(tags)} randuri")
        if len(tags) < PAGE_SIZE:
            return links
        page += 1


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    CACHE.mkdir(parents=True, exist_ok=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)

    xlsx = CACHE / "nomenclator.xlsx"
    if not xlsx.exists():
        print("Descarc nomenclator.xlsx ...")
        xlsx.write_bytes(fetch(f"{BASE}/files/nomenclator.xlsx"))

    print("Citesc linkurile RCP / prospect ...")
    links = load_links()

    ws = openpyxl.load_workbook(xlsx, read_only=True).worksheets[0]
    rows = ws.iter_rows(values_only=True)
    col = {name: i for i, name in enumerate(next(rows))}

    products = OrderedDict()
    updated = ""
    total = 0
    for r in rows:
        g = lambda name: clean(r[col[name]])
        cim = g("Cod CIM")
        if not cim:
            continue
        total += 1
        updated = g("Data actualizare") or updated
        key = (
            g("Denumire comerciala"),
            g("DCI"),
            g("Forma farmaceutica"),
            g("Concentratie"),
            g("Firma / tara detinatoare APP"),
        )
        p = products.get(key)
        if p is None:
            p = products[key] = {
                "n": key[0],
                "d": key[1],
                "f": key[2],
                "c": key[3],
                "h": key[4],
                "m": g("Firma / tara producatoare APP"),
                "a": g("Cod ATC"),
                "t": g("Actiune terapeutica"),
                "p": g("Prescriptie"),
                "e": 0,
                "r": "",
                "l": "",
                "k": [],
            }
        rcp, pro = links.get(cim, ("", ""))
        p["r"] = p["r"] or pdf_link(rcp)
        p["l"] = p["l"] or pdf_link(pro)
        # fara PDF la ANMDM = autorizat centralizat, documentele sunt la EMA
        if "ec.europa.eu" in rcp:
            p["e"] = 1
        p["k"].append([cim, g("Ambalaj"), g("Volum ambalaj"), g("Valabilitate ambalaj")])

    # PDF-ul EMA in romana (RCP + prospect intr-un singur document), daca a fost
    # gasit de tool/resolve_ema.py
    if EMA_LINKS.exists():
        ema = json.loads(EMA_LINKS.read_text(encoding="utf-8"))
        for p in products.values():
            if p["e"]:
                p["r"] = ema.get(base_name(p["n"]), "")

    data = {"updated": updated, "products": list(products.values())}
    raw = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    OUT.write_bytes(gzip.compress(raw, 9, mtime=0))  # mtime fix: acelasi continut da acelasi fisier

    with_rcp = sum(1 for p in products.values() if p["r"])
    with_pro = sum(1 for p in products.values() if p["l"])
    print(f"Autorizate centralizat (EMA): {sum(p['e'] for p in products.values())}")
    print(f"Ambalaje: {total}  Produse: {len(products)}  Linkuri gasite: {len(links)}")
    print(f"Produse cu RCP: {with_rcp}  cu prospect: {with_pro}")
    print(f"JSON: {len(raw) / 1e6:.2f} MB  gzip: {OUT.stat().st_size / 1e6:.2f} MB  -> {OUT}")


if __name__ == "__main__":
    main()
