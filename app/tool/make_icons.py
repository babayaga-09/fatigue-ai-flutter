"""Draw Touchline's launcher and web icons from a 16x16 stitch grid (run from app/)."""
from pathlib import Path

from PIL import Image

PITCH, PINK = (15, 61, 46, 255), (242, 167, 195, 255)
STRIPE = "PPGGPPGGPPGGPPGG"
GRID = [STRIPE, STRIPE, "G" * 16,
        "GGPPPPPPPPPPPPGG", "GGPPPPPPPPPPPPGG"] + ["GGGGGGGPPGGGGGGG"] * 8 + [
        "G" * 16, STRIPE, STRIPE]


def stitch(size: int, inset: float = 0.0) -> Image.Image:
    cell = 16
    img = Image.new("RGBA", (cell, cell), PITCH)
    for y, row in enumerate(GRID):
        for x, ch in enumerate(row):
            img.putpixel((x, y), PINK if ch == "P" else PITCH)
    if inset:
        inner = round(size * (1 - 2 * inset))
        canvas = Image.new("RGBA", (size, size), PITCH)
        canvas.paste(img.resize((inner, inner), Image.NEAREST), ((size - inner) // 2,) * 2)
        return canvas
    return img.resize((size, size), Image.NEAREST)


def main() -> None:
    res = Path("android/app/src/main/res")
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        stitch(px).save(res / f"mipmap-{folder}" / "ic_launcher.png")
    web = Path("web")
    stitch(64).save(web / "favicon.png")
    stitch(192).save(web / "icons" / "Icon-192.png")
    stitch(512).save(web / "icons" / "Icon-512.png")
    stitch(192, inset=0.1).save(web / "icons" / "Icon-maskable-192.png")
    stitch(512, inset=0.1).save(web / "icons" / "Icon-maskable-512.png")


if __name__ == "__main__":
    main()
