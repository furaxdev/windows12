using System;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using FuraxCortana.Native;

namespace FuraxCortana;

/// <summary>
/// "Furax Cortana" — assistant local, inspiré de Cortana (Windows 10), 100% offline : tout
/// tourne sur la machine via un petit LLM local (llama.cpp/LLamaSharp, voir LocalModel.cs),
/// jamais un appel réseau. Peut proposer d'exécuter des commandes/d'agir sur l'écran (voir
/// ActionProtocol.cs), mais JAMAIS sans confirmation explicite de l'utilisateur pour chaque
/// action — demande explicite de FuraxDev (29/10/2026) : un petit modèle local peut
/// halluciner une commande dangereuse, donc aucune exécution automatique.
///
/// Déclenché par un raccourci clavier global (Ctrl+Maj+F par défaut) qui affiche/masque la
/// fenêtre — n'importe où dans Windows, pas seulement quand l'appli a le focus.
/// </summary>
public static class Program
{
    private static Window? _window;
    private static LocalModel? _model;
    private static StackPanel? _chatLog;
    private static TextBox? _input;
    private static TextBlock? _statusText;
    private static Button? _sendButton;

    private const int HOTKEY_ID = 0xF11A;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint VK_F = 0x46;
    private const int WM_HOTKEY = 0x0312;

    [STAThread]
    public static void Main()
    {
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.DispatcherUnhandledException += (_, e) =>
        {
            // Une appli d'assistant qui plante ne doit JAMAIS emporter autre chose avec
            // elle — jamais de barre des tâches ni de session Windows affectée. On avale
            // l'exception et on continue, au pire le chat reste muet.
            e.Handled = true;
        };

        try
        {
            _window = BuildWindow();
            SetupGlobalHotkey();
            LoadModelInBackground();
            app.Run();
        }
        catch
        {
            // Échec total de construction de la fenêtre : on se termine simplement, sans
            // rien avoir touché au reste du système (aucune modification faite avant ce
            // point).
        }
    }

    private static Window BuildWindow()
    {
        var root = new Grid();
        var chrome = new Border
        {
            CornerRadius = new CornerRadius(18),
            Background = new SolidColorBrush(Color.FromArgb(0xE6, 0x14, 0x10, 0x20)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x26, 0xFF, 0xFF, 0xFF)),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(16),
        };

        var layout = new Grid();
        layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        layout.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var title = new TextBlock
        {
            Text = "Furax Cortana — assistant local (hors-ligne)",
            FontSize = 16,
            FontWeight = FontWeights.SemiBold,
            Foreground = Brushes.White,
            Margin = new Thickness(0, 0, 0, 4),
        };
        _statusText = new TextBlock
        {
            Text = "Chargement du modèle...",
            FontSize = 12,
            Foreground = new SolidColorBrush(Color.FromArgb(0xB0, 0xFF, 0xFF, 0xFF)),
            Margin = new Thickness(0, 0, 0, 10),
        };
        var header = new StackPanel();
        header.Children.Add(title);
        header.Children.Add(_statusText);
        Grid.SetRow(header, 0);

        _chatLog = new StackPanel { Margin = new Thickness(0, 0, 0, 10) };
        var scroll = new ScrollViewer
        {
            Content = _chatLog,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
        };
        Grid.SetRow(scroll, 1);

        var inputRow = new Grid();
        inputRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        inputRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        _input = new TextBox
        {
            FontSize = 14,
            Padding = new Thickness(10, 8, 10, 8),
            Background = new SolidColorBrush(Color.FromArgb(0x30, 0xFF, 0xFF, 0xFF)),
            Foreground = Brushes.White,
            BorderThickness = new Thickness(0),
            IsEnabled = false,
        };
        _input.KeyDown += async (_, e) =>
        {
            if (e.Key == Key.Enter)
            {
                e.Handled = true;
                await SendCurrentInputAsync();
            }
        };
        Grid.SetColumn(_input, 0);

        _sendButton = new Button
        {
            Content = "Envoyer",
            Margin = new Thickness(8, 0, 0, 0),
            Padding = new Thickness(14, 8, 14, 8),
            IsEnabled = false,
            Cursor = Cursors.Hand,
        };
        _sendButton.Click += async (_, _) => await SendCurrentInputAsync();
        Grid.SetColumn(_sendButton, 1);

        inputRow.Children.Add(_input);
        inputRow.Children.Add(_sendButton);
        Grid.SetRow(inputRow, 2);

        layout.Children.Add(header);
        layout.Children.Add(scroll);
        layout.Children.Add(inputRow);
        chrome.Child = layout;
        root.Children.Add(chrome);

        var window = new Window
        {
            Content = root,
            Width = 520,
            Height = 620,
            WindowStyle = WindowStyle.None,
            AllowsTransparency = true,
            Background = Brushes.Transparent,
            ResizeMode = ResizeMode.NoResize,
            Topmost = true,
            ShowInTaskbar = false,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            Visibility = Visibility.Hidden,
            Title = "Furax Cortana",
        };
        return window;
    }

    private static void SetupGlobalHotkey()
    {
        _window!.SourceInitialized += (_, _) =>
        {
            var helper = new WindowInteropHelper(_window);
            NativeMethods.RegisterHotKey(helper.Handle, HOTKEY_ID, MOD_CONTROL | MOD_SHIFT, VK_F);
            HwndSource.FromHwnd(helper.Handle)!.AddHook(WndProc);
        };
        _window.Closed += (_, _) =>
        {
            var helper = new WindowInteropHelper(_window);
            NativeMethods.UnregisterHotKey(helper.Handle, HOTKEY_ID);
        };
    }

    private static IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY && wParam.ToInt32() == HOTKEY_ID)
        {
            _window!.Visibility = _window.Visibility == Visibility.Visible ? Visibility.Hidden : Visibility.Visible;
            if (_window.Visibility == Visibility.Visible)
            {
                _window.Activate();
                _input!.Focus();
            }
            handled = true;
        }
        return IntPtr.Zero;
    }

    private static void LoadModelInBackground()
    {
        System.Threading.Tasks.Task.Run(() =>
        {
            var modelPath = LocalModel.FindModelFile();
            if (modelPath is null)
            {
                SetStatus("Aucun modèle trouvé dans %LOCALAPPDATA%\\FuraxCortana\\models\\*.gguf — " +
                          "dépose un modèle GGUF (ex. Qwen2.5-0.5B-Instruct, licence Apache-2.0) dans ce " +
                          "dossier puis relance l'appli. Aucun téléchargement automatique, jamais.");
                return;
            }

            var model = LocalModel.TryLoad(modelPath, out var error);
            if (model is null)
            {
                SetStatus($"Échec du chargement du modèle ({modelPath}) : {error}");
                return;
            }

            _model = model;
            SetStatus($"Modèle chargé : {System.IO.Path.GetFileName(modelPath)}");
            _window!.Dispatcher.Invoke(() =>
            {
                _input!.IsEnabled = true;
                _sendButton!.IsEnabled = true;
            });
        });
    }

    private static void SetStatus(string text)
    {
        _window!.Dispatcher.Invoke(() => _statusText!.Text = text);
    }

    private static void AddBubble(string author, string text)
    {
        var bubble = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(0x30, 0xFF, 0xFF, 0xFF)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10),
            Margin = new Thickness(0, 0, 0, 8),
        };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = author,
            FontWeight = FontWeights.SemiBold,
            FontSize = 11,
            Foreground = new SolidColorBrush(Color.FromArgb(0xA0, 0xFF, 0xFF, 0xFF)),
        });
        stack.Children.Add(new TextBlock
        {
            Text = text,
            Foreground = Brushes.White,
            TextWrapping = TextWrapping.Wrap,
            FontSize = 13,
        });
        bubble.Child = stack;
        _chatLog!.Children.Add(bubble);
    }

    private static void AddActionCard(ProposedAction action)
    {
        var card = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(0x40, 0xF4, 0x72, 0xB6)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10),
            Margin = new Thickness(0, 0, 0, 8),
        };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = "⚠ " + action.DescribeForConfirmation(),
            Foreground = Brushes.White,
            TextWrapping = TextWrapping.Wrap,
            FontSize = 13,
            Margin = new Thickness(0, 0, 0, 8),
        });

        var buttons = new StackPanel { Orientation = Orientation.Horizontal };
        var confirm = new Button { Content = "Confirmer", Padding = new Thickness(10, 4, 10, 4), Margin = new Thickness(0, 0, 8, 0), Cursor = Cursors.Hand };
        var cancel = new Button { Content = "Annuler", Padding = new Thickness(10, 4, 10, 4), Cursor = Cursors.Hand };

        confirm.Click += (_, _) =>
        {
            confirm.IsEnabled = false;
            cancel.IsEnabled = false;
            ExecuteAction(action);
            AddBubble("Système", "Action exécutée.");
        };
        cancel.Click += (_, _) =>
        {
            confirm.IsEnabled = false;
            cancel.IsEnabled = false;
            AddBubble("Système", "Action annulée.");
        };

        buttons.Children.Add(confirm);
        buttons.Children.Add(cancel);
        stack.Children.Add(buttons);
        card.Child = stack;
        _chatLog!.Children.Add(card);
    }

    /// <summary>Exécute une action — appelé UNIQUEMENT depuis le clic sur "Confirmer",
    /// jamais automatiquement. Chaque branche utilise exactement l'API publique Win32
    /// (NativeMethods) ou Process.Start, rien de cché.</summary>
    private static void ExecuteAction(ProposedAction action)
    {
        try
        {
            switch (action.Kind)
            {
                case ActionKind.RunCommand:
                    Process.Start(new ProcessStartInfo("cmd.exe", $"/c {action.Payload}") { UseShellExecute = true });
                    break;
                case ActionKind.OpenApp:
                    Process.Start(new ProcessStartInfo(action.Payload) { UseShellExecute = true });
                    break;
                case ActionKind.TypeText:
                    NativeMethods.TypeText(action.Payload);
                    break;
                case ActionKind.ClickAt:
                    if (TryParseCoords(action.Payload, out var cx, out var cy))
                        NativeMethods.ClickAt(cx, cy);
                    break;
                case ActionKind.MoveMouse:
                    if (TryParseCoords(action.Payload, out var mx, out var my))
                        NativeMethods.MoveMouse(mx, my);
                    break;
            }
        }
        catch (Exception ex)
        {
            // Une action qui échoue (ex. commande invalide) ne doit jamais planter le chat
            // — juste l'annoncer à l'utilisateur.
            AddBubble("Système", $"Échec de l'action : {ex.Message}");
        }
    }

    private static bool TryParseCoords(string payload, out int x, out int y)
    {
        x = y = 0;
        var parts = payload.Split(',');
        if (parts.Length != 2) return false;
        return int.TryParse(parts[0].Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out x)
            && int.TryParse(parts[1].Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out y);
    }

    private static async System.Threading.Tasks.Task SendCurrentInputAsync()
    {
        if (_model is null || string.IsNullOrWhiteSpace(_input!.Text))
        {
            return;
        }

        var userText = _input.Text.Trim();
        _input.Text = "";
        AddBubble("Toi", userText);

        var prompt = $"Tu es Furax Cortana, un assistant Windows local et francophone, " +
                     $"utile et concis.{ActionProtocol.SystemPromptSuffix}\n\nUtilisateur : {userText}\nAssistant :";

        var sb = new StringBuilder();
        await foreach (var token in _model.GenerateAsync(prompt))
        {
            sb.Append(token);
        }

        var (displayText, actions) = ActionProtocol.Parse(sb.ToString());
        if (!string.IsNullOrWhiteSpace(displayText))
        {
            AddBubble("Furax Cortana", displayText);
        }
        foreach (var action in actions)
        {
            AddActionCard(action);
        }
    }
}
