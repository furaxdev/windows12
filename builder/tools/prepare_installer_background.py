#!/usr/bin/env python3
"""
prepare_installer_background.py — prépare le fond d'écran de l'assistant Windows Setup
(sources/background.bmp et Windows/System32/setup.bmp dans boot.wim, index 2).

Contrairement au fond de bureau (JPEG), ces fichiers portent l'extension .bmp mais
contiennent en réalité des PNG RGBA (vérifié par inspection directe d'une vraie ISO
Windows 11 25H2 : `file sources/background.bmp` -> "PNG image data ... RGBA"). Le format
de sortie est donc PNG, pas BMP ni JPEG, pour rester cohérent avec ce que le loader de
Windows Setup attend à cet emplacement.

Overlay logo+texte (optionnel, backlog demande utilisateur 26/09/2026 — "setup
personnalisé") : reproduit la disposition vue dans la vraie frame vidéo extraite
(Windows_12.1.mp4, écran "Almost ready...") — logo carré 4 panneaux + texte, centrés en
haut de l'écran. Tout est cuit dans un PNG statique au moment du build (aucune police ni
ressource requise sur la machine Windows cible à l'exécution).

Usage:
    python3 prepare_installer_background.py <source> <sortie> <largeur> <hauteur> \
        [--logo <chemin_png>] [--text "<texte>"] [--font <chemin_ttf>]
"""
import argparse

from PIL import Image, ImageDraw, ImageFont


def crop_right(im: Image.Image, frac: float) -> Image.Image:
    """Retire la fraction `frac` la plus à droite de l'image AVANT le cover-fit — sert à
    exclure le logo déjà intégré par l'artiste original dans furax-wave-primary.jpg
    (visible vers x≈1420-1650 sur les 2048px de large de la source), constaté par
    inspection visuelle directe (26/09/2026, demande utilisateur), pas par une supposition
    de position. Ne touche PAS au fichier source ni à 45-wallpaper.sh (bureau) — seulement
    la copie de travail utilisée pour le fond de l'assistant Setup."""
    w, h = im.size
    new_w = round(w * (1 - frac))
    return im.crop((0, 0, new_w, h))


def cover_fit(im: Image.Image, target_w: int, target_h: int) -> Image.Image:
    src_w, src_h = im.size
    src_ratio = src_w / src_h
    target_ratio = target_w / target_h

    if src_ratio > target_ratio:
        new_h = target_h
        new_w = round(new_h * src_ratio)
    else:
        new_w = target_w
        new_h = round(new_w / src_ratio)

    resized = im.resize((new_w, new_h), Image.LANCZOS)
    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def add_branding_overlay(
    base: Image.Image, logo_path: str | None, text: str | None, font_path: str | None
) -> Image.Image:
    """Colle le logo + texte centrés en haut, taille proportionnelle à l'image cible
    (jamais une taille en pixels fixe, pour rester cohérent sur des résolutions
    différentes — vérifié sur 1024x768, l'ISO 25H2 testée)."""
    w, h = base.size
    out = base.convert("RGBA")

    logo_h = round(h * 0.11)
    gap = round(logo_h * 0.35)

    logo_img = None
    if logo_path:
        logo_img = Image.open(logo_path).convert("RGBA")
        logo_w = round(logo_img.width * (logo_h / logo_img.height))
        logo_img = logo_img.resize((logo_w, logo_h), Image.LANCZOS)

    text_w = 0
    text_h = 0
    font = None
    if text:
        font_size = round(logo_h * 0.62)
        font = ImageFont.truetype(font_path, font_size) if font_path else ImageFont.load_default()
        draw_tmp = ImageDraw.Draw(out)
        bbox = draw_tmp.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]

    total_w = (logo_img.width if logo_img else 0) + (gap if (logo_img and text) else 0) + text_w
    start_x = (w - total_w) // 2
    top_y = round(h * 0.08)

    x = start_x
    if logo_img:
        out.alpha_composite(logo_img, (x, top_y))
        x += logo_img.width + (gap if text else 0)

    if text and font:
        draw = ImageDraw.Draw(out)
        text_y = top_y + (logo_h - text_h) // 2 - bbox[1]
        # Léger liseré sombre pour la lisibilité sur un fond clair/dégradé (même logique
        # que le bandeau de la maquette artifact précédente), puis le texte blanc.
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            draw.text((x + dx, text_y + dy), text, font=font, fill=(0, 0, 0, 110))
        draw.text((x, text_y), text, font=font, fill=(255, 255, 255, 255))

    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("sortie")
    parser.add_argument("largeur", type=int)
    parser.add_argument("hauteur", type=int)
    parser.add_argument("--logo", default=None)
    parser.add_argument("--text", default=None)
    parser.add_argument("--font", default=None)
    parser.add_argument("--crop-right-frac", type=float, default=0.0)
    args = parser.parse_args()

    im = Image.open(args.source).convert("RGB")
    if args.crop_right_frac > 0:
        im = crop_right(im, args.crop_right_frac)
    out = cover_fit(im, args.largeur, args.hauteur).convert("RGBA")

    if args.logo or args.text:
        out = add_branding_overlay(out, args.logo, args.text, args.font)

    out.save(args.sortie, "PNG")
    print(
        f"OK: {args.source} ({im.size[0]}x{im.size[1]}) -> {args.sortie} "
        f"({args.largeur}x{args.hauteur}, PNG/RGBA"
        f"{', overlay logo+texte' if (args.logo or args.text) else ''})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
