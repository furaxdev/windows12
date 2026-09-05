# 🟦 Barre des tâches "pilule flottante" — EXPERIMENTAL / UNTESTED

**État : `EXPERIMENTAL`, `UNTESTED`.** Ne pas confondre avec les réglages natifs déjà appliqués par le builder (alignement centré, accent coloré — ceux-là sont `IMPLEMENTED`, voir `docs/FEATURES.md`).

## Ce que c'est

Reproduire la barre des tâches "flottante", détachée des bords, aux coins très arrondis, vue dans la vidéo concept Windows 12.1 (voir `docs/VIDEO_ANALYSIS.md`) **n'est pas possible avec les réglages/registre natifs de Windows 11**. `explorer.exe`/`ShellExperienceHost` qui dessinent la barre des tâches sont des composants Microsoft fermés, non thémables à ce niveau par des moyens supportés.

La seule voie réaliste identifiée est un **patch de shell tiers** : [Windhawk](https://windhawk.net/) — un framework d'injection de DLL open source (MIT), largement utilisé par la communauté pour ce type de personnalisation visuelle, qui fonctionne par mods activables/désactivables individuellement, sans modifier le binaire `explorer.exe` sur disque.

## Pourquoi ce n'est PAS intégré au pipeline de build automatique

Ce projet a une règle absolue : ne jamais prétendre qu'une fonctionnalité marche si elle n'a pas été vérifiée. Dans l'environnement de développement utilisé pour ce projet (sandbox Linux sans KVM), il est impossible de démarrer un vrai bureau Windows pour vérifier visuellement qu'un mod Windhawk :

- s'installe et s'active correctement au premier démarrage ;
- ne provoque pas de plantage ou de boucle de `explorer.exe` ;
- rend visuellement ce qui est attendu.

Injecter automatiquement un patch de shell dans l'image Windows **sans pouvoir vérifier son effet** serait exactement le genre de fonctionnalité "prétendument terminée" que ce projet refuse de livrer. C'est pourquoi :

- **rien n'est installé automatiquement par le builder** pour cette fonctionnalité, même avec le profil `full` ;
- ce dossier ne contient que de la documentation + des scripts à lancer **manuellement, volontairement, après l'installation de Windows** ;
- aucun flag de profil n'active d'injection automatique de DLL dans l'ISO.

## Comment l'essayer manuellement (à tes risques, sur une VM de test — pas ta machine principale)

1. Installe l'ISO Furax Windows 12 Beta normalement (aucune différence avec une installation Windows 11 standard à ce stade).
2. Une fois sur le bureau, télécharge et installe **toi-même** Windhawk depuis le site officiel : https://windhawk.net/ (ne fais confiance qu'à cette source officielle).
3. Dans l'application Windhawk, parcours la bibliothèque de mods dans la catégorie liée à la barre des tâches ("Taskbar") et essaie un mod de style de barre des tâches (marges, coins arrondis, hauteur). Le choix exact du mod est laissé à l'utilisateur : la bibliothèque Windhawk évolue, et ce projet ne fige pas une version/ID de mod précis qu'il n'a pas pu tester lui-même.
4. Ajuste les paramètres du mod pour te rapprocher de l'esthétique vue dans `docs/VIDEO_ANALYSIS.md` (barre détachée des bords, coins très arrondis).

## Rollback (retour en arrière propre)

Windhawk est conçu pour être réversible sans dommage :
- **Désactiver un mod** : dans l'app Windhawk, bascule l'interrupteur du mod sur "désactivé" — l'effet disparaît immédiatement, `explorer.exe` n'est jamais modifié sur disque.
- **Désinstaller complètement Windhawk** : utilise le désinstalleur standard Windows (Paramètres → Applications, ou le désinstalleur fourni par Windhawk) — restaure le comportement 100% natif de la barre des tâches.

Aucune étape de ce projet ne modifie `explorer.exe` de façon irréversible : si tu n'installes jamais Windhawk toi-même, ton système reste un Windows 11 25H2 standard avec uniquement les personnalisations natives listées dans `docs/FEATURES.md` (thème, fond d'écran, branding, accent).

## Statut détaillé

| Aspect | Statut |
|---|---|
| Mécanisme identifié et documenté | `PROTOTYPE` (documentation uniquement) |
| Intégration automatique au builder | Non fait, volontairement |
| Test visuel réel (rendu correct, pas de plantage) | `UNTESTED` |
| Rollback | Documenté, repose sur les mécanismes natifs de Windhawk (non testé dans ce projet faute d'installation Windows démarrable dans l'environnement de développement) |
