# Furax Windows 12 Beta 🚀

**Statut du projet : Phase 1 — Analyse** (voir `docs/` — aucune modification d'ISO n'a encore été effectuée).

Furax Windows 12 Beta est un projet expérimental qui vise à reproduire, de façon aussi fidèle que raisonnablement possible, l'expérience visuelle et fonctionnelle présentée dans une vidéo concept "Windows 12.1", **par-dessus une image Windows 11 25H2 officielle et légalement possédée par l'utilisateur**.

Ce n'est **pas** un fork du noyau Windows, **pas** un contournement d'activation/licence, et **pas** un outil de piratage. C'est un pipeline de *customisation offline* (registre, policies, assets, applications tierces) appliqué à une ISO Windows 11 que tu fournis toi-même.

## Documents clés

| Document | Contenu |
|---|---|
| [`docs/VIDEO_ANALYSIS.md`](docs/VIDEO_ANALYSIS.md) | Analyse chronologique exhaustive de la vidéo de référence, timestampée |
| [`docs/FEATURES.md`](docs/FEATURES.md) | Inventaire des fonctionnalités par catégorie, avec état (`PLANNED`/`PROTOTYPE`/`PARTIAL`/`IMPLEMENTED`/`TESTED`) et faisabilité |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Architecture du projet, environnement de dev réel, outils requis |
| [`docs/BUILD.md`](docs/BUILD.md) | Comment préparer l'environnement et lancer un build |
| [`docs/TESTING.md`](docs/TESTING.md) | Stratégie de tests (build/config/runtime) et VM de test |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Diagnostic des échecs de build |
| [`docs/ROLLBACK.md`](docs/ROLLBACK.md) | Annuler les personnalisations (fond d'écran, thème, branding) |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Design system (couleurs, typo, motion...) extrait de la vidéo |

## Environnement de développement

Le développement se fait sous **Ubuntu 24.04 LTS** (Debian-compatible), pas sous Windows. Le pipeline de build tourne entièrement en bash/Python côté Linux (extraction ISO, montage/édition WIM via `wimlib-imagex`, édition de registre offline via `hivex`, régénération ISO via `xorriso`), puis produit une ISO testée dans une VM Windows via QEMU/KVM. Détails complets dans `docs/ARCHITECTURE.md`.

## Règle absolue

Aucune fonctionnalité n'est présentée comme fonctionnelle si elle ne l'est pas. Chaque élément de `docs/FEATURES.md` porte un état honnête :

- `PLANNED` — pas encore commencé
- `PROTOTYPE` — ébauche non fiable
- `PARTIAL` — fonctionne partiellement
- `IMPLEMENTED` — fonctionne
- `TESTED` — fonctionne et vérifié dans une VM Windows

Certains éléments de la vidéo sont des `CONCEPT ONLY` : des démonstrations non réalistes avec les composants actuellement modifiables de Windows 11. Ils sont documentés comme tels avec, quand c'est possible, une alternative réaliste.

## Utilisation (prévue — Phase 2, pas encore implémenté)

```bash
./builder/build.sh --iso ./input/Windows11.iso --profile full
./builder/build.sh --iso ./input/Windows11.iso --profile minimal
./builder/build.sh --iso ./input/Windows11.iso --dry-run
```

```bash
./vm/test-vm.sh
```

## Licence et légalité

- Ce projet ne fournit, ne télécharge et ne distribue **aucune** copie de Windows. Tu dois fournir ta propre ISO Windows 11 25H2 obtenue légalement (Microsoft officiel).
- Aucune protection de licence/activation n'est contournée ou supprimée.
- Le hash de l'ISO fournie est vérifié avant tout traitement.
