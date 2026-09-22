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
    - Enregistre une tâche planifiée de nettoyage des fichiers temporaires (backlog #84).
      Le backlog envisageait une fréquence "mensuelle" ; le déclencheur `-Monthly` n'existe
      pas dans le module `ScheduledTasks` de PowerShell (seuls `-Daily`/`-Weekly`/`-Once`
      sont exposés par `New-ScheduledTaskTrigger` sans passer par l'API CIM bas niveau,
      plus fragile à écrire correctement sans pouvoir tester sur un vrai Windows démarré) —
      HEBDOMADAIRE a été choisi à la place, écart assumé et documenté ici plutôt que
      prétendre "mensuel" sans l'avoir vérifié.

    Chaque étape est dans son propre try/catch : un échec de l'une n'empêche pas
    les autres de s'exécuter, et aucune des trois n'empêche jamais l'ouverture de session.
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

try {
    $taskName = "FuraxWindows12-NettoyageTemp"
    if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
        # Résolus maintenant (contexte de l'utilisateur qui vient d'ouvrir sa session) et
        # figés en chemins littéraux dans l'action planifiée : la tâche tourne en tant que
        # SYSTEM, où $env:TEMP au moment de l'exécution pointerait vers le TEMP de SYSTEM,
        # pas celui de cet utilisateur — d'où la résolution immédiate plutôt que différée.
        $userTemp = $env:TEMP
        $winTemp  = Join-Path $env:WINDIR "Temp"
        $cleanupCmd = "Remove-Item -Path '$userTemp\*','$winTemp\*' -Recurse -Force -ErrorAction SilentlyContinue"
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -Command `"$cleanupCmd`""
        $trigger    = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
        $principal  = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings   = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Description `
            "Furax Windows 12 Beta : nettoyage hebdomadaire des fichiers temporaires (backlog #84)." `
            -ErrorAction Stop | Out-Null
    }
} catch {
    # Non-fatal : Register-ScheduledTask peut échouer selon la policy locale (Task
    # Scheduler désactivé, droits insuffisants) — on n'empêche jamais l'ouverture de
    # session pour une tâche de nettoyage.
}
