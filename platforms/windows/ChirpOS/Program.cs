using System.Reflection;
using System.Text.Json;
using ChirpOS.Core;
namespace ChirpOS;

internal static class Program
{
    internal static readonly string DataFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ChirpOS");
    internal static Stream Resource(string name) => Assembly.GetExecutingAssembly().GetManifestResourceStream(name) ?? throw new FileNotFoundException(name);
    internal static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };
    internal static void Log(Exception e) { try { Directory.CreateDirectory(DataFolder); File.AppendAllText(Path.Combine(DataFolder, "errors.log"), DateTimeOffset.Now + " " + e + Environment.NewLine); } catch { } }
    [STAThread]
    static void Main(string[] args)
    {
        var update=Array.IndexOf(args,"--apply-update");
        if(update>=0){Environment.Exit(update+1<args.Length?UpdateInstaller.RunHelper(args[update+1]):1);return;}
        using var mutex = new Mutex(true, "Local\\ChirpOS.Desktop", out var first); if (!first && !args.Contains("--self-test") && !args.Contains("--fixture")) return;
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2); Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
        Application.ThreadException += (_, e) => { Log(e.Exception); MessageBox.Show(e.Exception.Message, "ChirpOS"); Application.Exit(); };
        try { if (args.Contains("--fixture")) { DesktopVerification.Fixture(); return; } if (args.Contains("--self-test")) { DesktopVerification.Run(args); return; } var desktop=new Desktop();UpdateInstaller.ConfirmHealthy(args);Application.Run(desktop); }
        catch (Exception e) { Log(e); MessageBox.Show(e.Message, "ChirpOS — 启动失败 / Startup failed"); }
    }
}
