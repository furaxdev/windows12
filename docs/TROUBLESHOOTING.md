# TROUBLESHOOTING.md — Diagnostiquer un échec de build

## Méthode générale

1. Lis le rapport : `build/_out/rapport-build-<id>.txt` — indique quelle étape a échoué (`FAILED`) et son détail.
2. Lis le log complet correspondant : `build/_out/build-<id>.log` (copié automatiquement même en cas d'échec, avant suppression éventuelle du dossier de travail).
3. Si le build a échoué, le dossier de travail (`build/_work/furax-build-<id>/`) est **conservé** pour inspection (contrairement à un build réussi, nettoyé automatiquement).

## Problèmes rencontrés et résolus pendant le développement de ce projet (documentés pour référence)

### "Aucun sources/install.wim ni sources/install.esd trouvé" alors que l'ISO est valide

**Cause réelle rencontrée :** les ISO Windows modernes (>4 Go, cas de toutes les ISO Windows 11 actuelles) sont au format **UDF Bridge**, avec une arborescence ISO9660 quasiment vide (seul `README.TXT` y figure). `xorriso -osirrox`/`xorriso -find` ne lisent que l'arborescence ISO9660 et ne voient donc presque aucun fichier sur ce type d'image.

**Solution appliquée :** le pipeline utilise `7z l`/`7z x` (qui lit correctement l'UDF, vérifié en pratique) pour l'inspection (`00-validate.sh`) et l'extraction (`10-extract.sh`), plutôt que `xorriso -osirrox`.

### Régénération d'ISO non bootable / `xorriso -boot_image any replay` ne fonctionne pas

**Cause réelle rencontrée :** en lisant une ISO Windows en UDF Bridge, xorriso journalise lui-même `"Detected El-Torito boot information which currently is set to be discarded"` — il n'a pas de catalogue de boot fiable à "rejouer" sur la nouvelle ISO.

**Solution appliquée :** `60-build-iso.sh` reconstruit explicitement le catalogue El Torito double (BIOS via `boot/etfsboot.com`, UEFI via `efi/microsoft/boot/efisys.bin`) avec `xorriso -as mkisofs`, plutôt que de compter sur un rejeu automatique.

### `ModuleNotFoundError: No module named 'hivex'` avec `python3 -c "import hivex"`

**Cause réelle rencontrée (spécifique à cet environnement de dev, à vérifier sur le tien) :** plusieurs versions de Python coexistent ; `python3` par défaut pointait vers 3.11 alors que `python3-hivex` (paquet Ubuntu) fournit le binding compilé pour 3.12.

**Solution appliquée :** `builder/tools/hivex_set_value.py` est toujours invoqué explicitement via `/usr/bin/python3.12`, jamais via `python3` nu. Si `python3.12` n'existe pas sur ta machine, adapte ce chemin — et vérifie d'abord avec `python3 -c "import hivex"` quelle version fonctionne chez toi.

### "Espace disque insuffisant" alors qu'il semble y avoir de la place

Le calcul est volontairement conservateur : `taille_ISO × 2.5` (extraction ≈ 1x + ISO régénérée ≈ 1x + marge de sécurité 25%) sur le volume contenant `build/_work` (par défaut, sous le dossier du projet). Si ton disque de travail est différent du disque contenant l'ISO source, utilise `--work-dir` pour pointer vers un volume avec plus d'espace libre.

### Mount résiduel après un échec (`wimlib-imagex mountrw` reste actif)

Le trap `cleanup_on_exit` (dans `builder/lib/common.sh`) tente un démontage de sécurité automatiquement à la sortie du script, quelle que soit la cause de l'arrêt. Si malgré tout un mount reste actif (ex. : process tué avec `kill -9`, qui empêche tout trap de s'exécuter), démonte manuellement :

```bash
wimlib-imagex unmount /chemin/vers/mount-dir
# ou, si ça échoue :
fusermount -uz /chemin/vers/mount-dir
```

Puis vérifie qu'aucun mount ne subsiste avec `mount | grep wimlib` ou `mountpoint /chemin/vers/mount-dir`.

## En cas de nouveau problème

Ouvre le log complet et cherche la dernière ligne `[ERROR]` avant l'arrêt — chaque module logue explicitement la commande qui a échoué (`[CMD]`) avant de rapporter l'erreur. N'hésite pas à relancer avec `--keep-work` pour inspecter manuellement le dossier de travail après un succès (normalement supprimé automatiquement).
