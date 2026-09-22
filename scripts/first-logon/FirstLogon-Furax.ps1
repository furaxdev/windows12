<#
.SYNOPSIS
    Exécuté UNE SEULE FOIS au tout premier login, via une entrée HKLM\...\RunOnce
    déposée par builder/modules/41-first-logon.sh. Windows supprime automatiquement
    l'entrée RunOnce après exécution (mécanisme natif, pas un script qui se boucle).

.DESCRIPTION
    - Crée un point de restauration système ("Furax Windows 12 Beta - post-install"),
      pour que l'utilisateur puisse revenir en arrière facilement même sans le rollback
      applicatif (backlog #79).
    - Affiche un message de bienvenue ponctuel (backlog #77).

    Chaque étape est dans son propre try/catch : un échec de l'une n'empêche pas
    l'autre de s'exécuter, et aucune des deux n'empêche jamais l'ouverture de session.
#>

try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "Furax Windows 12 Beta - post-install" `
        -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
} catch {
    # Non-fatal : la Restauration système peut être désactivée par policy, ou un point
    # de restauration a déjà été créé trop récemment (Windows impose un délai minimum
    # entre deux points MODIFY_SETTINGS). Dans les deux cas, on continue.
}

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    [System.Windows.Forms.MessageBox]::Show(
        "Bienvenue sur Furax Windows 12 Beta !`n`n" +
        "Projet de customisation par FuraxDev, base Windows 11 officielle.`n" +
        "Un raccourci de rollback est disponible sur le Bureau si tu veux annuler" +
        " les personnalisations (fond d'ecran, theme, etc.).",
        "Furax Windows 12 Beta",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} catch {
    # Non-fatal : environnement sans assembly WinForms disponible (rare), on n'empêche
    # jamais l'ouverture de session pour un message de bienvenue.
}
