using System;
using System.Runtime.InteropServices;

namespace FuraxTaskbar.Native;

// P/Invoke vers des API Win32 STANDARD et publiquement documentées (aucune API interne/non
// documentée, aucun hook mémoire dans explorer.exe — contrairement à un patch de shell tiers
// type Windhawk). Chaque appel a un usage précis et limité :
//   - FindWindow/ShowWindow "Shell_TrayWnd" : masque/réaffiche la VRAIE barre des tâches
//     Windows (elle continue d'exister, juste cachée — rien n'est désinstallé ni patché).
//   - keybd_event (VK_LWIN) : simule un appui sur la touche Windows, exactement comme si
//     l'utilisateur l'avait pressée, pour ouvrir le vrai Menu Démarrer/la vraie Recherche.
//   - DwmSetWindowAttribute / DwmExtendFrameIntoClientArea : effets de flou/matériau natifs
//     Windows 11 (Mica/Acrylic), mêmes API que n'importe quelle app native utiliserait.
internal static class NativeMethods
{
    private const string TaskbarClassName = "Shell_TrayWnd";
    private const int SW_HIDE = 0;
    private const int SW_SHOW = 5;

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindWindow(string lpClassName, string? lpWindowName);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    private const byte VK_LWIN = 0x5B;
    private const byte VK_S = 0x53;
    private const byte VK_A = 0x41;
    private const uint KEYEVENTF_KEYUP = 0x0002;

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    [DllImport("dwmapi.dll")]
    private static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref Margins margins);

    [StructLayout(LayoutKind.Sequential)]
    private struct Margins
    {
        public int Left, Right, Top, Bottom;
    }

    // DWMWA_SYSTEMBACKDROP_TYPE (Windows 11 22H2+) : 2 = Mica.
    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    private const int DWMSBT_TRANSIENTWINDOW = 3; // matériau "Acrylic" flou, adapté aux petites fenêtres flottantes
    private const int DWMWCP_ROUND = 2;

    /// <summary>
    /// Trouve le handle de la vraie barre des tâches Windows. Peut renvoir IntPtr.Zero si
    /// introuvable (ex. explorer.exe pas encore démarré) — appelant doit vérifier.
    /// </summary>
    internal static IntPtr FindTaskbarWindow() => FindWindow(TaskbarClassName, null);

    internal static void HideRealTaskbar()
    {
        var hwnd = FindTaskbarWindow();
        if (hwnd != IntPtr.Zero)
        {
            ShowWindow(hwnd, SW_HIDE);
        }
    }

    internal static void ShowRealTaskbar()
    {
        var hwnd = FindTaskbarWindow();
        if (hwnd != IntPtr.Zero)
        {
            ShowWindow(hwnd, SW_SHOW);
        }
    }

    /// <summary>Simule l'appui + relâchement de la touche Windows (ouvre le vrai Menu Démarrer).</summary>
    internal static void PressWindowsKey()
    {
        keybd_event(VK_LWIN, 0, 0, UIntPtr.Zero);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    /// <summary>Simule Win+S (raccourci natif Windows 11 qui ouvre directement le panneau
    /// de Recherche plutôt que le Menu Démarrer) — Win maintenu enfoncé pendant que S est
    /// pressé puis relâché, puis Win relâché, pour respecter l'ordre attendu par Windows.</summary>
    internal static void PressWindowsS()
    {
        keybd_event(VK_LWIN, 0, 0, UIntPtr.Zero);
        keybd_event(VK_S, 0, 0, UIntPtr.Zero);
        keybd_event(VK_S, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    /// <summary>Simule Win+A (raccourci natif Windows 11 qui ouvre directement les
    /// Paramètres rapides — wifi/volume/luminosité/etc.), même principe que Win+S.</summary>
    internal static void PressWindowsA()
    {
        keybd_event(VK_LWIN, 0, 0, UIntPtr.Zero);
        keybd_event(VK_A, 0, 0, UIntPtr.Zero);
        keybd_event(VK_A, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    /// <summary>Applique le matériau flou natif Windows 11 (Acrylic transitoire) à une fenêtre.</summary>
    internal static void ApplyAcrylicBackdrop(IntPtr hwnd)
    {
        try
        {
            int backdrop = DWMSBT_TRANSIENTWINDOW;
            DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref backdrop, sizeof(int));

            int cornerPref = DWMWCP_ROUND;
            DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, ref cornerPref, sizeof(int));

            var margins = new Margins { Left = -1, Right = -1, Top = -1, Bottom = -1 };
            DwmExtendFrameIntoClientArea(hwnd, ref margins);
        }
        catch
        {
            // Non-fatal : sur une version de Windows/build qui ne supporte pas cet attribut
            // DWM (ex. Windows 10, ou Windows 11 antérieur à 22H2), la fenêtre reste visible
            // avec le fond semi-transparent défini côté XAML/code, juste sans le flou natif.
        }
    }
}
