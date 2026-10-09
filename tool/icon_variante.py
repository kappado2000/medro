"""Deseneaza variantele de iconita pentru aplicatie si o plansa cu toate,
numerotate, din care se alege una.

Rulare:  python tool/icon_variante.py            (plansa in tool/cache/iconite/)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tool" / "cache" / "iconite"
ALBASTRU = (0x15, 0x58, 0xD6)
ALBASTRU_INCHIS = (0x0B, 0x2F, 0x7A)
ROSU = (0xE0, 0x2B, 0x3C)
ALB = (255, 255, 255)
S = 4  # factor de supraesantionare


def fundal(n: int) -> Image.Image:
    img = Image.new("RGBA", (n, n))
    px = img.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(ALBASTRU, ALBASTRU_INCHIS)) + (255,)
    return img


def strat(n: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def capsula(n: int, lungime: float, grosime: float, stanga, dreapta, unghi: float,
            contur=None, centru=(0.5, 0.5)) -> Image.Image:
    """Capsula in doua culori, rotita cu `unghi` grade, pe strat transparent."""
    img, d = strat(n)
    cx, cy = n * centru[0], n * centru[1]
    L, G = n * lungime, n * grosime
    cutie = [cx - L / 2, cy - G / 2, cx + L / 2, cy + G / 2]
    d.rounded_rectangle(cutie, radius=G / 2, fill=dreapta + (255,))
    masca, dm = strat(n)
    dm.rounded_rectangle(cutie, radius=G / 2, fill=stanga + (255,))
    dm.rectangle([cx, 0, n, n], fill=(0, 0, 0, 0))
    img.alpha_composite(masca)
    if contur:
        d.rounded_rectangle(cutie, radius=G / 2, outline=contur + (255,), width=round(n * 0.022))
    return img.rotate(unghi, resample=Image.BICUBIC, center=(cx, cy))


def v1(n):  # capsula rosu-alb
    img = fundal(n)
    img.alpha_composite(capsula(n, 0.66, 0.27, ROSU, ALB, 45))
    return img


def v2(n):  # capsula in patrat alb
    img = fundal(n)
    d = ImageDraw.Draw(img)
    a = n * 0.21
    d.rounded_rectangle([a, a, n - a, n - a], radius=n * 0.15, fill=ALB + (255,))
    img.alpha_composite(capsula(n, 0.44, 0.18, ROSU, ALBASTRU, 45))
    return img


def v3(n):  # capsula si comprimat
    img = fundal(n)
    img.alpha_composite(capsula(n, 0.50, 0.21, ROSU, ALB, 45, centru=(0.42, 0.42)))
    d = ImageDraw.Draw(img)
    cx, cy, r = n * 0.66, n * 0.66, n * 0.155
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ALB + (255,))
    g = n * 0.018
    d.line([cx - r * 0.62, cy + r * 0.62, cx + r * 0.62, cy - r * 0.62], fill=ALBASTRU + (255,), width=round(g * 1.6))
    return img


def v4(n):  # flacon cu cruce
    img = fundal(n)
    d = ImageDraw.Draw(img)
    # capac
    d.rounded_rectangle([n * 0.37, n * 0.20, n * 0.63, n * 0.31], radius=n * 0.03, fill=ROSU + (255,))
    # corp
    d.rounded_rectangle([n * 0.31, n * 0.33, n * 0.69, n * 0.80], radius=n * 0.07, fill=ALB + (255,))
    # cruce albastra pe eticheta
    cx, cy, b, g = n * 0.5, n * 0.565, n * 0.20, n * 0.07
    d.rounded_rectangle([cx - b / 2, cy - g / 2, cx + b / 2, cy + g / 2], n * 0.012, fill=ALBASTRU + (255,))
    d.rounded_rectangle([cx - g / 2, cy - b / 2, cx + g / 2, cy + b / 2], n * 0.012, fill=ALBASTRU + (255,))
    return img


def v5(n):  # blister
    img = fundal(n)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([n * 0.26, n * 0.20, n * 0.74, n * 0.80], radius=n * 0.07, fill=ALB + (255,))
    r = n * 0.075
    for i, y in enumerate((0.335, 0.50, 0.665)):
        for j, x in enumerate((0.395, 0.605)):
            culoare = ROSU if (i + j) % 2 == 0 else ALBASTRU
            d.ellipse([n * x - r, n * y - r, n * x + r, n * y + r], fill=culoare + (255,))
    return img


def v6(n):  # doua capsule incrucisate
    img = fundal(n)
    img.alpha_composite(capsula(n, 0.62, 0.20, ALB, ALB, -45))
    img.alpha_composite(capsula(n, 0.62, 0.20, ROSU, ALB, 45, contur=ALBASTRU_INCHIS))
    return img


def v7(n):  # Rx
    img = fundal(n)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arialbd.ttf", round(n * 0.46))
    except OSError:
        font = ImageFont.load_default()
    text = "Rx"
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
    d.text(((n - (x1 - x0)) / 2 - x0, (n - (y1 - y0)) / 2 - y0 - n * 0.02), text, font=font, fill=ALB + (255,))
    img.alpha_composite(capsula(n, 0.26, 0.10, ROSU, ALB, 45, centru=(0.74, 0.76)))
    return img


def v8(n):  # capsula alba simpla, conturata, ca in bara de jos
    img = fundal(n)
    img.alpha_composite(capsula(n, 0.64, 0.27, ALB, ALBASTRU, 45, contur=ALB))
    return img


def _degrade_vertical(n: int, y0: float, y1: float, culori) -> Image.Image:
    """Degrade pe verticala intre y0 si y1, prin trei culori (sus, mijloc, jos)."""
    img = Image.new("RGBA", (n, n))
    px = img.load()
    sus, mijloc, jos = culori
    for y in range(n):
        t = min(1.0, max(0.0, (y - y0) / (y1 - y0)))
        a, b, u = (sus, mijloc, t / 0.45) if t < 0.45 else (mijloc, jos, (t - 0.45) / 0.55)
        c = tuple(round(p + (q - p) * u) for p, q in zip(a, b)) + (255,)
        for x in range(n):
            px[x, y] = c
    return img


def capsula_lucioasa(n: int, scara: float = 1.0) -> Image.Image:
    """Capsula galben-rosu cu volum: umbra dedesubt, degrade pe fiecare jumatate
    si o dunga de luciu. Strat transparent; `scara` o micsoreaza in jurul centrului."""
    L, G = n * 0.70 * scara, n * 0.30 * scara
    cx = cy = n / 2
    x0, y0, x1, y1 = cx - L / 2, cy - G / 2, cx + L / 2, cy + G / 2

    forma = Image.new("L", (n, n), 0)
    ImageDraw.Draw(forma).rounded_rectangle([x0, y0, x1, y1], radius=G / 2, fill=255)
    stanga = forma.copy()
    ImageDraw.Draw(stanga).rectangle([cx, 0, n, n], fill=0)
    dreapta = forma.copy()
    ImageDraw.Draw(dreapta).rectangle([0, 0, cx, n], fill=0)

    galben = _degrade_vertical(n, y0, y1, ((255, 226, 110), (247, 181, 24), (205, 128, 6)))
    rosu = _degrade_vertical(n, y0, y1, ((246, 104, 96), (216, 34, 44), (150, 14, 28)))
    corp = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    corp.paste(galben, (0, 0), stanga)
    corp.paste(rosu, (0, 0), dreapta)

    # imbinarea celor doua jumatati
    d = ImageDraw.Draw(corp)
    d.line([cx, y0 + G * 0.04, cx, y1 - G * 0.04], fill=(90, 10, 16, 110), width=max(1, round(G * 0.022)))

    # luciul de sus si reflexia slaba de jos
    luciu = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dl = ImageDraw.Draw(luciu)
    dl.rounded_rectangle([x0 + G * 0.30, y0 + G * 0.11, x1 - G * 0.30, y0 + G * 0.33],
                         radius=G * 0.11, fill=(255, 255, 255, 150))
    dl.rounded_rectangle([x0 + G * 0.42, y1 - G * 0.17, x1 - G * 0.42, y1 - G * 0.10],
                         radius=G * 0.04, fill=(255, 255, 255, 55))
    luciu = luciu.filter(ImageFilter.GaussianBlur(G * 0.035))
    luciu.putalpha(Image.composite(luciu.getchannel("A"), Image.new("L", (n, n), 0), forma))
    corp.alpha_composite(luciu)
    corp = corp.rotate(30, resample=Image.BICUBIC, center=(cx, cy))

    # umbra moale sub capsula
    umbra = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(umbra).rounded_rectangle([x0, y0, x1, y1], radius=G / 2, fill=(0, 0, 0, 105))
    umbra = umbra.rotate(30, resample=Image.BICUBIC, center=(cx, cy))
    umbra = umbra.filter(ImageFilter.GaussianBlur(G * 0.16))
    rezultat = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    rezultat.alpha_composite(umbra, (round(G * 0.05), round(G * 0.20)))
    rezultat.alpha_composite(corp)
    return rezultat


def v9(n):  # capsula lucioasa pe albastru
    img = fundal(n)
    img.alpha_composite(capsula_lucioasa(n))
    return img


def v10(n):  # capsula lucioasa pe alb
    img = Image.new("RGBA", (n, n), ALB + (255,))
    img.alpha_composite(capsula_lucioasa(n))
    return img


VARIANTE = {
    1: ("Capsulă roșu-alb", v1),
    2: ("Capsulă în pătrat alb", v2),
    3: ("Capsulă și comprimat", v3),
    4: ("Flacon cu cruce", v4),
    5: ("Blister", v5),
    6: ("Două capsule", v6),
    7: ("Rx cu capsulă", v7),
    8: ("Capsulă albă", v8),
    9: ("Capsulă lucioasă, fond albastru", v9),
    10: ("Capsulă lucioasă, fond alb", v10),
}


def randeaza(numar: int, marime: int) -> Image.Image:
    return VARIANTE[numar][1](marime * S).resize((marime, marime), Image.LANCZOS).convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    m, pas, antet = 300, 360, 70
    coloane = 4
    randuri = -(-len(VARIANTE) // coloane)
    plansa = Image.new("RGB", (coloane * pas + 60, randuri * (m + 110) + antet), (244, 247, 252))
    d = ImageDraw.Draw(plansa)
    try:
        titlu = ImageFont.truetype("arialbd.ttf", 30)
        eticheta = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        titlu = eticheta = ImageFont.load_default()
    d.text((30, 20), "MedRO – variante de iconiță", font=titlu, fill=(20, 33, 61))
    for i, (numar, (nume, _)) in enumerate(VARIANTE.items()):
        x = 30 + (i % coloane) * pas
        y = antet + (i // coloane) * (m + 110)
        icon = randeaza(numar, m)
        # colturi rotunjite, cum apare pe telefon
        masca = Image.new("L", (m, m), 0)
        ImageDraw.Draw(masca).rounded_rectangle([0, 0, m, m], radius=66, fill=255)
        plansa.paste(icon, (x, y), masca)
        d.text((x, y + m + 12), f"{numar}. {nume}", font=eticheta, fill=(20, 33, 61))
        icon.save(OUT / f"varianta_{numar}.png")
    try:
        plansa.save(OUT / "variante.png")
        print(OUT / "variante.png")
    except OSError:
        # fisierul e deschis intr-un vizualizator care il blocheaza
        plansa.save(OUT / "variante_noi.png")
        print(OUT / "variante_noi.png")


if __name__ == "__main__":
    main()
