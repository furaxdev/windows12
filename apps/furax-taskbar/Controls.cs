using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace FuraxTaskbar;

internal static class Controls
{
    /// <summary>Enveloppe le contenu d'une pilule : fond semi-transparent, coins arrondis,
    /// ombre portée — le DWM (voir NativeMethods.ApplyAcrylicBackdrop) ajoute le vrai flou
    /// natif par-dessus une fois la fenêtre affichée ; ce fond sert de repli visuel avant/
    /// pendant que le matériau DWM s'applique et sur les configurations où il échoue.</summary>
    internal static Border PillChrome(UIElement content, double cornerRadius = 16)
    {
        return new Border
        {
            CornerRadius = new CornerRadius(cornerRadius),
            Background = new SolidColorBrush(Color.FromArgb(0xB8, 0x0E, 0x0C, 0x14)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x1A, 0xFF, 0xFF, 0xFF)),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12, 0, 12, 0),
            Effect = new System.Windows.Media.Effects.DropShadowEffect
            {
                Color = Colors.Black,
                Opacity = 0.45,
                BlurRadius = 28,
                ShadowDepth = 6,
                Direction = 270,
            },
            Child = content,
        };
    }

    /// <summary>Bouton icône rond avec un fond qui apparaît au survol — imite le
    /// comportement natif Windows (aucun état visuel par défaut, highlight discret au
    /// survol/clic), construit avec les Style/Trigger WPF standard.</summary>
    internal static Button IconButton(UIElement icon, string tooltip, RoutedEventHandler onClick, bool active = false)
    {
        var button = new Button
        {
            Width = 38,
            Height = 38,
            Content = icon,
            ToolTip = tooltip,
            Cursor = Cursors.Hand,
            Focusable = false,
        };
        AutomationProperties.SetName(button, tooltip);

        var template = new ControlTemplate(typeof(Button));
        var borderFactory = new FrameworkElementFactory(typeof(Border));
        borderFactory.SetValue(Border.CornerRadiusProperty, new CornerRadius(10));
        borderFactory.SetValue(Border.BackgroundProperty,
            active ? new SolidColorBrush(Color.FromArgb(0x24, 0xFF, 0xFF, 0xFF)) : Brushes.Transparent);
        borderFactory.Name = "Chrome";

        var contentFactory = new FrameworkElementFactory(typeof(ContentPresenter));
        contentFactory.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        contentFactory.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        borderFactory.AppendChild(contentFactory);

        template.VisualTree = borderFactory;

        var hoverTrigger = new Trigger { Property = Button.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(Border.BackgroundProperty,
            new SolidColorBrush(Color.FromArgb(0x1E, 0xFF, 0xFF, 0xFF)), "Chrome"));
        template.Triggers.Add(hoverTrigger);

        button.Template = template;
        button.Click += onClick;
        return button;
    }

    internal static TextBlock Text(string text, double size = 13, bool bold = false, double opacity = 1.0)
    {
        return new TextBlock
        {
            Text = text,
            FontSize = size,
            FontFamily = new FontFamily("Segoe UI"),
            FontWeight = bold ? FontWeights.SemiBold : FontWeights.Normal,
            Foreground = new SolidColorBrush(Color.FromArgb((byte)(0xFF * opacity), 0xF2, 0xEE, 0xE8)),
        };
    }

    internal static Border VerticalSeparator(double height = 26)
    {
        return new Border
        {
            Width = 1,
            Height = height,
            Background = new SolidColorBrush(Color.FromArgb(0x1E, 0xFF, 0xFF, 0xFF)),
            Margin = new Thickness(6, 0, 6, 0),
        };
    }
}
