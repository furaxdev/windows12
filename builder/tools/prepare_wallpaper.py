#!/usr/bin/env python3
"""
prepare_wallpaper.py — redimensionne une image source pour remplacer un fond d'écran
Windows par défaut (ex. Windows/Web/Wallpaper/Windows/img0.jpg), en "cover fit"
(remplit toute la surface cible sans déformer l'image, recadrée au centre si les
ratios diffèrent) plutôt qu'un simple resize qui étirerait l'image.

Peut optionnellement superposer un logo (filigrane semi-transparent, façon logo "Windows 12"
flottant sur le bureau vu dans la vidéo concept — voir docs/VIDEO_ANALYSIS.md) en bas à
droite de l'image finale.

Usage:
    python3 prepare_wallpaper.py <source> <sortie> <largeur> <hauteur> [<logo>]
"""
import sys

from PIL import Image


def cover_fit(im: Image.Image, target_w: int, target_h: int) -> Image.Image:
    src_w, src_h = im.size
    src_ratio = src_w / src_h
    target_ratio = target_w / target_h

    if src_ratio > target_ratio:
        # Source plus "large" que la cible : on cale la hauteur, on recadre la largeur.
        new_h = target_h
        new_w = round(new_h * src_ratio)
    else:
        new_w = target_w
        new_h = round(new_w / src_ratio)

    resized = im.resize((new_w, new_h), Image.LANCZOS)
    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def overlay_logo(base: Image.Image, logo_path: str) -> Image.Image:
    """Superpose le logo, redimensionné à ~18% de la largeur de l'image, en bas à droite,
    avec une marge et une opacité légèrement réduite pour un rendu "filigrane" discret
    plutôt qu'un autocollant plaqué à 100% d'opacité."""
    base = base.convert("RGBA")
    logo = Image.open(logo_path).convert("RGBA")

    target_logo_w = round(base.width * 0.18)
    scale = target_logo_w / logo.width
    logo = logo.resize((target_logo_w, round(logo.height * scale)), Image.LANCZOS)

    # Réduit l'opacité du logo (canal alpha) à 85% pour un rendu filigrane plus doux.
    alpha = logo.getchannel("A").point(lambda a: int(a * 0.85))
    logo.putalpha(alpha)

    margin = round(base.width * 0.04)
    pos_x = base.width - logo.width - margin
    pos_y = base.height - logo.height - margin

    composited = base.copy()
    composited.alpha_composite(logo, (pos_x, pos_y))
    return composited.convert("RGB")


def main():
    if len(sys.argv) not in (5, 6):
        print(f"Usage: {sys.argv[0]} <source> <sortie> <largeur> <hauteur> [<logo>]", file=sys.stderr)
        return 2

    src_path, out_path, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    logo_path = sys.argv[5] if len(sys.argv) == 6 else None

    im = Image.open(src_path).convert("RGB")
    out = cover_fit(im, w, h)

    if logo_path:
        out = overlay_logo(out, logo_path)
        print(f"Logo superposé : {logo_path}")

    out.save(out_path, "JPEG", quality=92)
    print(f"OK: {src_path} ({im.size[0]}x{im.size[1]}) -> {out_path} ({w}x{h})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
