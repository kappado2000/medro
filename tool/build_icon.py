"""Genereaza iconita aplicatiei (emblema din antet: cruce rosie pe patrat alb,
pe degradeul albastru) pentru iOS, Android si web.

Rulare:  python tool/build_icon.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ALBASTRU = (0x15, 0x58, 0xD6)
ALBASTRU_INCHIS = (0x0B, 0x2F, 0x7A)
ROSU = (0xE0, 0x2B, 0x3C)
ALB = (255, 255, 255)


def emblema(marime: int, margine: float = 0.0) -> Image.Image:
    """Iconita patrata, fara transparenta. `margine` micsoreaza emblema pentru
    variantele pe care sistemul le decupeaza (iconite mascabile)."""
    n = marime * 4  # desenat marit, apoi micsorat, pentru margini netede
    img = Image.new("RGB", (n, n))
    # degrade pe diagonala, ca in antetul aplicatiei
    px = img.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(ALBASTRU, ALBASTRU_INCHIS))
    d = ImageDraw.Draw(img)
    latura = n * (0.58 - margine)
    x0 = (n - latura) / 2
    d.rounded_rectangle([x0, x0, x0 + latura, x0 + latura], radius=latura * 0.26, fill=ALB)
    brat, grosime = latura * 0.62, latura * 0.235
    c = n / 2
    raza = grosime * 0.12
    d.rounded_rectangle([c - brat / 2, c - grosime / 2, c + brat / 2, c + grosime / 2], raza, fill=ROSU)
    d.rounded_rectangle([c - grosime / 2, c - brat / 2, c + grosime / 2, c + brat / 2], raza, fill=ROSU)
    return img.resize((marime, marime), Image.LANCZOS)


def main() -> None:
    master = emblema(1024)

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for intrare in json.loads((ios / "Contents.json").read_text())["images"]:
        pixeli = round(float(intrare["size"].split("x")[0]) * int(intrare["scale"][0]))
        master.resize((pixeli, pixeli), Image.LANCZOS).save(ios / intrare["filename"])

    android = ROOT / "android/app/src/main/res"
    for densitate, pixeli in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        master.resize((pixeli, pixeli), Image.LANCZOS).save(android / f"mipmap-{densitate}/ic_launcher.png")

    web = ROOT / "web"
    for pixeli in (192, 512):
        master.resize((pixeli, pixeli), Image.LANCZOS).save(web / f"icons/Icon-{pixeli}.png")
        emblema(pixeli, margine=0.10).save(web / f"icons/Icon-maskable-{pixeli}.png")
    master.resize((32, 32), Image.LANCZOS).save(web / "favicon.png")
    print("iconite generate")


if __name__ == "__main__":
    main()
