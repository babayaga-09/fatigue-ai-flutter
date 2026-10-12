"""Draws Touchline's app icons: a programme-cover T in Archivo (narrowest, heaviest) on
turnstile red, over a sponsor-strip yellow band. Run from app/: python tool/make_icons.py"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RED, WHITE, YELLOW = (215, 38, 45), (255, 255, 255), (242, 194, 0)
FONT = Path("assets/fonts/Archivo.ttf")


def icon(size: int, safe: float = 1.0) -> Image.Image:
    """safe < 1 shrinks the mark into the centre (Android/web maskable safe zone)."""
    big = size * 4  # draw large, downsample for clean edges
    im = Image.new("RGB", (big, big), RED)
    d = ImageDraw.Draw(im)
    band = round(big * (0.5 - 0.5 * safe + 0.16 * safe))
    d.rectangle([0, big - band, big, big], fill=YELLOW)
    f = ImageFont.truetype(str(FONT), round(big * 0.78 * safe))
    f.set_variation_by_axes([900, 62])  # wght, wdth
    box = d.textbbox((0, 0), "T", font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    top = (big - band - h) / 2 - box[1]
    d.text(((big - w) / 2 - box[0], top), "T", font=f, fill=WHITE)
    return im.resize((size, size), Image.LANCZOS)


res = Path("android/app/src/main/res")
for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    icon(px).save(res / f"mipmap-{folder}" / "ic_launcher.png")
icon(192).save("web/icons/Icon-192.png")
icon(512).save("web/icons/Icon-512.png")
icon(192, safe=0.8).save("web/icons/Icon-maskable-192.png")
icon(512, safe=0.8).save("web/icons/Icon-maskable-512.png")
icon(64).save("web/favicon.png")
print("icons written")
