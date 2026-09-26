using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using FuraxTaskbar.Native;

namespace FuraxTaskbar.Pills;

/// <summary>
/// Pilule centrale : Démarrer / Recherche / Vue des tâches / Widgets / apps épinglées.
/// Démarrer et Recherche ouvrent les VRAIS panneaux Windows (simulent la touche Windows) —
/// on ne réimplémente pas le Menu Démarrer, on habille son déclencheur. Les icônes d'apps
/// lancent de vrais processus (Process.Start), qui échoueront silencieusement (try/catch,
/// pas de crash) si le chemin n'existe pas sur la machine cible — comportement à vérifier
/// sur un vrai Windows, voir docs/FEATURES.md.
/// </summary>
public sealed class DockPill : PillWindow
{
    public DockPill()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Height = 58, VerticalAlignment = VerticalAlignment.Center };

        row.Children.Add(Controls.IconButton(Icons.StartLogo(), "Démarrer", (_, _) => NativeMethods.PressWindowsKey()));
        row.Children.Add(Controls.IconButton(Icons.Search(), "Rechercher", (_, _) => NativeMethods.PressWindowsS()));
        row.Children.Add(Controls.IconButton(Icons.TaskView(), "Vue des tâches", (_, _) => LaunchByPath("explorer.exe", "shell:::{3080F90D-D7AD-11D9-BD98-0000947B0257}")));
        row.Children.Add(Controls.IconButton(Icons.Widgets(), "Widgets", (_, _) => LaunchByPath("explorer.exe", "shell:::{2CCA0D5E-CDA8-4AD1-84EE-1DC1B0BF6871}")));

        row.Children.Add(Controls.VerticalSeparator());

        row.Children.Add(Controls.IconButton(Icons.Folder(), "Explorateur de fichiers", (_, _) => LaunchByPath("explorer.exe"), active: true));
        row.Children.Add(Controls.IconButton(Icons.Browser(), "Navigateur", (_, _) => LaunchByPath("msedge.exe")));
        row.Children.Add(Controls.IconButton(Icons.Store(), "Microsoft Store", (_, _) => LaunchByPath("explorer.exe", "ms-windows-store:")));

        Content = Controls.PillChrome(row);
    }

    private static void LaunchByPath(string executable, string? arguments = null)
    {
        try
        {
            var info = new ProcessStartInfo(executable)
            {
                UseShellExecute = true,
            };
            if (arguments is not null)
            {
                info.Arguments = arguments;
            }
            Process.Start(info);
        }
        catch
        {
            // Non-fatal : un clic qui ne lance rien n'est pas grave, un crash de la
            // barre des tâches remplaçante l'est — jamais de UIElement.Content vide non
            // plus, l'utilisateur voit juste que rien ne se passe.
        }
    }
}
