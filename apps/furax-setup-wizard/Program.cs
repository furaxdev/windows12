using System;
using System.IO;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace FuraxSetupWizard;

/// <summary>
/// Écran de bienvenue Furax affiché AVANT le vrai Windows Setup (backlog #6-bis, demande
/// explicite de l'utilisateur du 26/09/2026 : "l'UI, pas l'exe système" — cette app est
/// UNIQUEMENT une fenêtre d'accueil, elle ne partitionne rien, ne formate rien, n'installe
/// rien. Le vrai moteur d'installation reste intégralement celui de Microsoft
/// (X:\sources\setup.exe, jamais touché).
///
/// Mécanisme d'accroche (voir builder/modules/43b-setup-wizard.sh) : un winpeshl.ini
/// déposé dans boot.wim (fichier texte, mécanisme WinPE officiellement documenté par
/// Microsoft pour cet usage — PAS un patch de binaire signé) enchaîne cette app PUIS
/// X:\sources\setup.exe. Filet de sécurité : winpeshl.exe lance les entrées de
/// [LaunchApps] en séquence, donc même si cette app plante, ne s'affiche pas (WinPE est un
/// environnement minimal, WPF dépend de composants de composition qui n'y sont pas
/// forcément tous présents — risque assumé et documenté), ou que l'utilisateur ferme la
/// fenêtre via Alt+F4, l'entrée suivante (le vrai setup.exe) démarre quand même. Cette app
/// ne lance JAMAIS elle-même setup.exe : elle se contente d'exister puis de se terminer,
/// winpeshl.ini gère l'enchaînement.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main()
    {
        var app = new Application();
        app.DispatcherUnhandledException += (_, e) =>
        {
            // Non-fatal pour le déroulé de l'installation : cette fenêtre n'est qu'un
            // accueil, jamais une étape bloquante. On ferme proprement ; winpeshl.ini
            // enchaîne sur le vrai setup.exe quoi qu'il arrive.
            e.Handled = true;
            Application.Current.Shutdown();
        };

        try
        {
            var window = BuildWindow();
            app.Run(window);
        }
        catch
        {
            // Échec total de construction de la fenêtre (ex. composants de composition
            // WPF absents dans cet environnement WinPE) : on se termine simplement, sans
            // relancer quoi que ce soit nous-mêmes — winpeshl.ini s'en charge.
        }
    }

    private static Window BuildWindow()
    {
        var background = LoadEmbeddedImageBrush("wave.jpg");

        var root = new Grid();
        if (background is not null)
        {
            root.Background = background;
        }
        else
        {
            root.Background = new SolidColorBrush(Color.FromRgb(0x14, 0x10, 0x24));
        }

        var stack = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };

        var title = new TextBlock
        {
            Text = "Windows 12",
            FontSize = 56,
            FontWeight = FontWeights.SemiBold,
            FontFamily = new FontFamily("Segoe UI"),
            Foreground = Brushes.White,
            HorizontalAlignment = HorizontalAlignment.Center,
            Effect = new System.Windows.Media.Effects.DropShadowEffect
            {
                Color = Colors.Black,
                Opacity = 0.5,
                BlurRadius = 16,
                ShadowDepth = 2,
            },
        };

        var subtitle = new TextBlock
        {
            Text = "By FuraxDev — installation personnalisée sur base Windows 11 officielle",
            FontSize = 16,
            FontFamily = new FontFamily("Segoe UI"),
            Foreground = new SolidColorBrush(Color.FromArgb(0xCC, 0xFF, 0xFF, 0xFF)),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 12, 0, 48),
        };

        var continueButton = new Button
        {
            Content = "Continuer",
            FontSize = 18,
            FontWeight = FontWeights.SemiBold,
            Foreground = Brushes.White,
            Padding = new Thickness(36, 14, 36, 14),
            Cursor = System.Windows.Input.Cursors.Hand,
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        StylePillButton(continueButton);
        continueButton.Click += (_, _) => Application.Current.Shutdown();

        stack.Children.Add(title);
        stack.Children.Add(subtitle);
        stack.Children.Add(continueButton);
        root.Children.Add(stack);

        return new Window
        {
            Content = root,
            WindowStyle = WindowStyle.None,
            WindowState = WindowState.Maximized,
            Topmost = true,
            ResizeMode = ResizeMode.NoResize,
            Title = "Furax Windows 12",
        };
    }

    private static void StylePillButton(Button button)
    {
        var template = new ControlTemplate(typeof(Button));
        var borderFactory = new FrameworkElementFactory(typeof(Border));
        borderFactory.SetValue(Border.CornerRadiusProperty, new CornerRadius(999));
        borderFactory.SetValue(Border.BackgroundProperty, new LinearGradientBrush(
            Color.FromRgb(0xA7, 0x8B, 0xFA), Color.FromRgb(0xF4, 0x72, 0xB6), 0));
        borderFactory.Name = "Chrome";

        var contentFactory = new FrameworkElementFactory(typeof(ContentPresenter));
        contentFactory.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        contentFactory.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        borderFactory.AppendChild(contentFactory);
        template.VisualTree = borderFactory;

        var hoverTrigger = new Trigger { Property = Button.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(Border.OpacityProperty, 0.88, "Chrome"));
        template.Triggers.Add(hoverTrigger);

        button.Template = template;
    }

    private static ImageBrush? LoadEmbeddedImageBrush(string logicalName)
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            using Stream? stream = assembly.GetManifestResourceStream(logicalName);
            if (stream is null)
            {
                return null;
            }
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.StreamSource = stream;
            bitmap.EndInit();
            bitmap.Freeze();
            return new ImageBrush(bitmap) { Stretch = Stretch.UniformToFill };
        }
        catch
        {
            return null;
        }
    }
}
