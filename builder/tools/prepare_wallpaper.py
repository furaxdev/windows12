#!/usr/bin/env python3
"""
prepare_wallpaper.py — redimensionne une image source pour remplacer un fond d'écran
Windows par défaut (ex. Windows/Web/Wallpaper/Windows/img0.jpg), en "cover fit"
(remplit toute la surface cible sans déformer l'image, recadrée au centre si les
ratios diffèrent) plutôt qu'un simple resize qui étirerait l'image.

Usage:
    python3 prepare_wallpaper.py <source> <sortie> <largeur> <hauteur>
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


def main():
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <source> <sortie> <largeur> <hauteur>", file=sys.stderr)
        return 2

    src_path, out_path, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])

    im = Image.open(src_path).convert("RGB")
    out = cover_fit(im, w, h)
    out.save(out_path, "JPEG", quality=92)
    print(f"OK: {src_path} ({im.size[0]}x{im.size[1]}) -> {out_path} ({w}x{h})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
