using System.Runtime.InteropServices;
using System.Text;
using ChirpOS.Core;
namespace ChirpOS;

internal static class Native
{
    [StructLayout(LayoutKind.Sequential)] internal struct Rect { public int Left, Top, Right, Bottom; public readonly Box Box => new(Left, Top, Right - Left, Bottom - Top); }
    [StructLayout(LayoutKind.Sequential)] internal struct Point { public int X, Y; public Point(int x, int y) { X = x; Y = y; } }
    [StructLayout(LayoutKind.Sequential)] internal struct Size { public int W, H; public Size(int w, int h) { W = w; H = h; } }
    [StructLayout(LayoutKind.Sequential, Pack = 1)] internal struct Blend { public byte Operation, Flags, Alpha, Format; }
    internal delegate bool EnumProc(nint hwnd, nint param);
    [DllImport("user32.dll")] internal static extern bool EnumWindows(EnumProc proc, nint param);
    [DllImport("user32.dll")] internal static extern bool IsWindowVisible(nint h);
    [DllImport("user32.dll")] internal static extern bool IsIconic(nint h);
    [DllImport("user32.dll")] internal static extern bool GetWindowRect(nint h, out Rect r);
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(nint h, out uint pid);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] internal static extern nint GetWindowLongPtr(nint h, int index);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern int GetClassName(nint h, StringBuilder name, int max);
    [DllImport("dwmapi.dll")] internal static extern int DwmGetWindowAttribute(nint h, int attribute, out Rect rect, int size);
    [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")] internal static extern int DwmGetWindowInt(nint h, int attribute, out int result, int size);
    [DllImport("user32.dll")] internal static extern bool SetWindowPos(nint h, nint after, int x, int y, int w, int height, uint flags);
    [DllImport("user32.dll")] internal static extern nint GetDC(nint h);
    [DllImport("user32.dll")] internal static extern int ReleaseDC(nint h, nint dc);
    [DllImport("gdi32.dll")] internal static extern nint CreateCompatibleDC(nint dc);
    [DllImport("gdi32.dll")] internal static extern nint SelectObject(nint dc, nint obj);
    [DllImport("gdi32.dll")] internal static extern bool DeleteObject(nint obj);
    [DllImport("gdi32.dll")] internal static extern bool DeleteDC(nint dc);
    [DllImport("user32.dll", SetLastError = true)] internal static extern bool UpdateLayeredWindow(nint h, nint dc, ref Point location, ref Size size, nint source, ref Point offset, uint color, ref Blend blend, uint flags);
    [DllImport("user32.dll")] internal static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] internal static extern uint GetDpiForWindow(nint h);
    [DllImport("shcore.dll")] internal static extern int GetDpiForMonitor(nint monitor, int type, out uint x, out uint y);
    [DllImport("user32.dll")] internal static extern nint MonitorFromPoint(Point point, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern nint OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] internal static extern bool CloseDesktop(nint desktop);
    [DllImport("user32.dll")] static extern bool GetLayeredWindowAttributes(nint h,out uint key,out byte alpha,out uint flags);
    internal static readonly List<object> WindowDiagnostics = new();
    internal static List<Surface> Windows()
    {
        WindowDiagnostics.Clear();
        var list = new List<Surface>();
        EnumWindows((h, _) =>
        {
            if (!IsWindowVisible(h) || IsIconic(h)) return true;
            // WindowPolicy excludes transparent bird/camera overlays by style.
            // Ordinary settings and gallery windows must participate in Z order.
            if (DwmGetWindowInt(h, 14, out var cloaked, 4) == 0 && cloaked != 0) return true;
            var cls = new StringBuilder(256); GetClassName(h, cls, 256); var name = cls.ToString();
            var ex = (long)GetWindowLongPtr(h,-20); var style=(long)GetWindowLongPtr(h,-16);
            byte? opacity=null;
            if((ex&0x80000)!=0 && GetLayeredWindowAttributes(h,out var colorKey,out var alpha,out var flags) && (flags&2)!=0)opacity=alpha;
            bool accepted=WindowPolicy.Occludes(name,style,ex,opacity);
            if (DwmGetWindowAttribute(h, 9, out var r, Marshal.SizeOf<Rect>()) != 0 && !GetWindowRect(h, out r)) return true;
            if (r.Right <= r.Left || r.Bottom <= r.Top) return true;
            WindowDiagnostics.Add(new {id=(long)h, className=name,style,exStyle=ex,opacity,accepted,bounds=r.Box});
            if(!accepted)return true;
            bool top = (ex & 8) != 0;
            list.Add(new((long)h, r.Box, top, !top && (ex & 0x80) == 0 && r.Box.W >= 180 && r.Box.H >= 100,IsTaskbar:name is "Shell_TrayWnd" or "Shell_SecondaryTrayWnd")); return true;
        }, 0); return list;
    }
    internal static double DpiScale(Screen screen) { var p = new Point(screen.Bounds.Left + 10, screen.Bounds.Top + 10); var m = MonitorFromPoint(p, 2); return GetDpiForMonitor(m, 0, out var x, out _) == 0 ? x / 96.0 : 1; }
    internal static bool DesktopAvailable() { var h = OpenInputDesktop(0, false, 0x0100); if (h == 0) return false; CloseDesktop(h); return true; }
}
