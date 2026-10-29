using System;
using System.Runtime.InteropServices;

namespace FuraxCortana.Native;

/// <summary>P/Invoke pour le contrôle clavier/souris (SendInput) et le raccourci clavier
/// global (RegisterHotKey) — toutes des API Win32 publiques et documentées, aucune astuce.
/// Chaque méthode ici est appelée UNIQUEMENT après confirmation explicite de l'utilisateur
/// dans l'UI (voir Program.cs) — ce fichier ne décide jamais lui-même de rien, il exécute
/// ce qu'on lui demande, point.</summary>
internal static class NativeMethods
{
    private const int INPUT_MOUSE = 0;
    private const int INPUT_KEYBOARD = 1;
    private const uint MOUSEEVENTF_MOVE = 0x0001;
    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP = 0x0004;
    private const uint MOUSEEVENTF_ABSOLUTE = 0x8000;
    private const uint KEYEVENTF_UNICODE = 0x0004;
    private const uint KEYEVENTF_KEYUP = 0x0002;

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public int type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx, dy;
        public uint mouseData, dwFlags, time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk, wScan;
        public uint dwFlags, time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    internal static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    internal static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private const int SM_CXSCREEN = 0;
    private const int SM_CYSCREEN = 1;

    /// <summary>Déplace le curseur à des coordonnées écran absolues (0,0 = coin haut-gauche)
    /// puis clique gauche. Utilise des coordonnées "normalisées" 0-65535 comme l'exige
    /// MOUSEEVENTF_ABSOLUTE (documenté ainsi par Microsoft, pas une bizarrerie de notre
    /// cru).</summary>
    internal static void ClickAt(int x, int y)
    {
        int screenW = GetSystemMetrics(SM_CXSCREEN);
        int screenH = GetSystemMetrics(SM_CYSCREEN);
        int normX = (int)(x * 65535.0 / Math.Max(1, screenW - 1));
        int normY = (int)(y * 65535.0 / Math.Max(1, screenH - 1));

        var move = new INPUT
        {
            type = INPUT_MOUSE,
            U = new InputUnion { mi = new MOUSEINPUT { dx = normX, dy = normY, dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE } },
        };
        var down = new INPUT { type = INPUT_MOUSE, U = new InputUnion { mi = new MOUSEINPUT { dwFlags = MOUSEEVENTF_LEFTDOWN } } };
        var up = new INPUT { type = INPUT_MOUSE, U = new InputUnion { mi = new MOUSEINPUT { dwFlags = MOUSEEVENTF_LEFTUP } } };

        SendInput(1, new[] { move }, Marshal.SizeOf<INPUT>());
        SendInput(1, new[] { down }, Marshal.SizeOf<INPUT>());
        SendInput(1, new[] { up }, Marshal.SizeOf<INPUT>());
    }

    internal static void MoveMouse(int x, int y)
    {
        int screenW = GetSystemMetrics(SM_CXSCREEN);
        int screenH = GetSystemMetrics(SM_CYSCREEN);
        int normX = (int)(x * 65535.0 / Math.Max(1, screenW - 1));
        int normY = (int)(y * 65535.0 / Math.Max(1, screenH - 1));
        var move = new INPUT
        {
            type = INPUT_MOUSE,
            U = new InputUnion { mi = new MOUSEINPUT { dx = normX, dy = normY, dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE } },
        };
        SendInput(1, new[] { move }, Marshal.SizeOf<INPUT>());
    }

    /// <summary>Tape du texte dans la fenêtre qui a le focus, caractère par caractère via
    /// KEYEVENTF_UNICODE (fonctionne pour n'importe quel caractère Unicode, pas seulement
    /// l'ASCII des touches physiques — technique standard pour "taper du texte"
    /// programmatiquement sous Windows).</summary>
    internal static void TypeText(string text)
    {
        foreach (char c in text)
        {
            var down = new INPUT
            {
                type = INPUT_KEYBOARD,
                U = new InputUnion { ki = new KEYBDINPUT { wScan = c, dwFlags = KEYEVENTF_UNICODE } },
            };
            var up = new INPUT
            {
                type = INPUT_KEYBOARD,
                U = new InputUnion { ki = new KEYBDINPUT { wScan = c, dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP } },
            };
            SendInput(1, new[] { down }, Marshal.SizeOf<INPUT>());
            SendInput(1, new[] { up }, Marshal.SizeOf<INPUT>());
        }
    }
}
