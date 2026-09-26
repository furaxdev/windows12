using System;
using System.Windows;
using FuraxTaskbar.Native;
using FuraxTaskbar.Pills;

namespace FuraxTaskbar;

/// <summary>
/// Point d'entrée. Cache la vraie barre des tâches au démarrage, affiche les 3 pilules
/// flottantes, la restaure systématiquement à la sortie — y compris en cas d'exception
/// non gérée ou de fermeture forcée (ProcessExit), pour ne JAMAIS laisser l'utilisateur
/// sans barre des tâches du tout si cette appli plante. C'est la garde-fou de sécurité le
/// plus important de tout ce module : mieux vaut un crash visible avec la vraie barre qui
/// revient, qu'un écran sans aucune barre des tâches.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main()
    {
        AppDomain.CurrentDomain.ProcessExit += (_, _) => NativeMethods.ShowRealTaskbar();
        AppDomain.CurrentDomain.UnhandledException += (_, _) => NativeMethods.ShowRealTaskbar();

        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.DispatcherUnhandledException += (_, e) =>
        {
            // Non-fatal pour la session Windows : on restaure la vraie barre puis on
            // laisse l'exception se propager normalement (pas de Handled = true qui
            // masquerait un vrai bug).
            NativeMethods.ShowRealTaskbar();
        };

        NativeMethods.HideRealTaskbar();

        try
        {
            var weather = new WeatherPill();
            var dock = new DockPill();
            var system = new SystemPill();

            int loadedCount = 0;
            void OnAnyPillLoaded(object? sender, RoutedEventArgs e)
            {
                loadedCount++;
                if (loadedCount == 3)
                {
                    LayoutPills(weather, dock, system);
                }
            }

            weather.Loaded += OnAnyPillLoaded;
            dock.Loaded += OnAnyPillLoaded;
            system.Loaded += OnAnyPillLoaded;

            weather.Show();
            dock.Show();
            system.Show();

            app.Run();
        }
        finally
        {
            NativeMethods.ShowRealTaskbar();
        }
    }

    /// <summary>
    /// Positionne les 3 pilules côte à côte, centrées horizontalement sur l'écran, en
    /// bas avec une marge — même disposition que la maquette (docs/VIDEO_ANALYSIS.md,
    /// vraie frame extraite de Windows_12.1.mp4 à ~7:00). Calculé après que les 3
    /// fenêtres aient fini leur layout (SizeToContent), donc que leurs ActualWidth
    /// soient fiables.
    /// </summary>
    private static void LayoutPills(Window weather, Window dock, Window system)
    {
        const double gap = 10;
        const double bottomMargin = 22;

        double totalWidth = weather.ActualWidth + dock.ActualWidth + system.ActualWidth + gap * 2;
        double screenWidth = SystemParameters.WorkArea.Width;
        double screenHeight = SystemParameters.WorkArea.Height;

        double startX = (screenWidth - totalWidth) / 2;
        double top = screenHeight - Math.Max(weather.ActualHeight, Math.Max(dock.ActualHeight, system.ActualHeight)) - bottomMargin;

        weather.Left = startX;
        weather.Top = top;

        dock.Left = weather.Left + weather.ActualWidth + gap;
        dock.Top = top;

        system.Left = dock.Left + dock.ActualWidth + gap;
        system.Top = top;
    }
}
