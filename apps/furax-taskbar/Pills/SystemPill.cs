using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using FuraxTaskbar.Native;

namespace FuraxTaskbar.Pills;

/// <summary>
/// Pilule système : clavier/volume/wifi (icônes statiques qui ouvrent les VRAIS
/// Paramètres rapides Windows au clic, via Win+A natif — on ne réimplémente PAS la vraie
/// zone système ni les flyouts volume/wifi/batterie, ni l'hébergement des icônes d'autres
/// apps (Shell_NotifyIcon) : c'est un sous-système connu pour être un des plus complexes
/// de tout remplacement de shell Windows, hors périmètre de ce premier jet — voir
/// docs/FEATURES.md #101 pour le détail de cette limite assumée), horloge en direct.
/// </summary>
public sealed class SystemPill : PillWindow
{
    private readonly TextBlock _clockText;
    private readonly DispatcherTimer _timer;

    public SystemPill()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Height = 58, VerticalAlignment = VerticalAlignment.Center };

        row.Children.Add(IconOnly(Icons.Keyboard(), "Clavier / paramètres rapides"));
        row.Children.Add(IconOnly(Icons.Volume(), "Volume"));
        row.Children.Add(IconOnly(Icons.Wifi(), "Réseau"));

        _clockText = Controls.Text(DateTime.Now.ToString("MMM d   HH:mm"));
        var clockButton = new Button
        {
            Content = _clockText,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = System.Windows.Input.Cursors.Hand,
            Margin = new Thickness(6, 0, 6, 0),
        };
        clockButton.Click += (_, _) => OpenQuickSettings();
        row.Children.Add(clockButton);

        var avatar = new Ellipse
        {
            Width = 26,
            Height = 26,
            Fill = new LinearGradientBrush(
                Color.FromRgb(0xFB, 0x92, 0x3C), Color.FromRgb(0xF4, 0x72, 0xB6), 45),
        };
        row.Children.Add(avatar);

        Content = Controls.PillChrome(row);

        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(15) };
        _timer.Tick += (_, _) => _clockText.Text = DateTime.Now.ToString("MMM d   HH:mm");
        _timer.Start();
        Closed += (_, _) => _timer.Stop();
    }

    private static Button IconOnly(UIElement icon, string tooltip)
    {
        return Controls.IconButton(icon, tooltip, (_, _) => OpenQuickSettings());
    }

    private static void OpenQuickSettings()
    {
        // Win+A : raccourci natif Windows 11 qui ouvre directement les Paramètres rapides
        // (wifi/volume/luminosité/etc.) — même logique que Win+S pour la recherche.
        try
        {
            NativeMethods.PressWindowsA();
        }
        catch
        {
            // Non-fatal.
        }
    }
}
