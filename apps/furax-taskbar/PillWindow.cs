using System;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using FuraxTaskbar.Native;

namespace FuraxTaskbar;

/// <summary>
/// Fenêtre de base pour chaque pilule flottante : sans bordure, toujours au-dessus,
/// jamais dans la barre des tâches réelle (qu'on masque de toute façon), fond
/// semi-transparent avec matériau flou natif Windows 11 appliqué une fois le handle créé.
/// </summary>
public abstract class PillWindow : Window
{
    protected PillWindow()
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        SizeToContent = SizeToContent.WidthAndHeight;

        SourceInitialized += OnSourceInitialized;
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        NativeMethods.ApplyAcrylicBackdrop(hwnd);
    }
}
