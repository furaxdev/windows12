using System.Windows;
using System.Windows.Controls;

namespace FuraxTaskbar.Pills;

/// <summary>
/// Pilule météo. Honnêteté : affiche des valeurs STATIQUES pour ce MVP — brancher une
/// vraie API météo demanderait une clé API à gérer (donc une dépendance de configuration
/// et un appel réseau au démarrage), hors périmètre de ce premier jet. Backlog : rendre
/// ça configurable (ville + clé API optionnelle) dans une itération suivante.
/// </summary>
public sealed class WeatherPill : PillWindow
{
    public WeatherPill()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Height = 58, VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(new FrameworkElement { Width = 4 });
        row.Children.Add(Wrap(Icons.Sun(26)));
        row.Children.Add(new FrameworkElement { Width = 8 });

        var tempCol = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        tempCol.Children.Add(Controls.Text("28°", 17, bold: true));
        tempCol.Children.Add(Controls.Text("Denpasar", 11, opacity: 0.65));
        row.Children.Add(tempCol);

        row.Children.Add(Controls.VerticalSeparator());

        var condCol = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        condCol.Children.Add(Controls.Text("Sunny", 13));
        condCol.Children.Add(Controls.Text("H:34° L:23°", 11, opacity: 0.65));
        row.Children.Add(condCol);

        Content = Controls.PillChrome(row);
    }

    private static FrameworkElement Wrap(UIElement el) => new Border { Child = el, VerticalAlignment = VerticalAlignment.Center };
}
