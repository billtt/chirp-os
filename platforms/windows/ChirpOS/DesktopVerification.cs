using System.Diagnostics;
using System.Text.Json;
using ChirpOS.Core;
namespace ChirpOS;

internal static class DesktopVerification
{
    internal static void Fixture() { var host = new Form { Text = "ChirpOS verification habitat", StartPosition = FormStartPosition.Manual, Bounds = new Rectangle(220, 330, 680, 370), BackColor = Color.LightSlateGray }; var timer = new System.Windows.Forms.Timer { Interval = 100 }; int step = 0; timer.Tick += (_, _) => { step++; if (step >= 15 && step < 25) host.Left += 2; if (step == 30) host.Left += 180; if (step > 80) host.Close(); }; host.Shown += (_, _) => timer.Start(); Application.Run(host); timer.Dispose(); }
    internal static void Run(string[] args)
    {
        var checks = new Dictionary<string, bool>(); Directory.CreateDirectory(Program.DataFolder);
        using var stream = Program.Resource("species.json"); var species = JsonSerializer.Deserialize<Catalog>(stream, Program.Json)!.Species;
        using var manifestStream=Program.Resource("art/manifest.json");using var manifest=JsonDocument.Parse(manifestStream);var frameCount=manifest.RootElement.GetProperty("frames").GetArrayLength();
        foreach (var s in species) { using var png = Program.Resource("art/" + s.Id + ".png"); using var img = Image.FromStream(png); checks["atlas_" + s.Id] = img.Width == img.Height*frameCount && img.Height >= 48 && img.Height <= 120; }
        using var imageStream = Program.Resource("art/redWhiskeredBulbul.png"); using var source = Image.FromStream(imageStream); using var atlas = new Bitmap(source);
        using(var ownWindow=new Form { Text="ChirpOS own-window verification",Size=new(400,300) }) {
            ownWindow.Show();Application.DoEvents();
            checks["ownWindowOccludes"]=Native.Windows().Any(s=>s.Id==(long)ownWindow.Handle);
            ownWindow.Hide();
            checks["hiddenOwnWindowDoesNotOcclude"]=!Native.Windows().Any(s=>s.Id==(long)ownWindow.Handle);
        }
        using var fixture = Process.Start(new ProcessStartInfo(Environment.ProcessPath!, "--fixture") { UseShellExecute = false })!;
        using var overlay = new Overlay(); var bird = new Bird(species[0], new(200, 200), new Random(1));
        var context = new ApplicationContext(); using var timer = new System.Windows.Forms.Timer { Interval = 33 }; var watch = Stopwatch.StartNew(); double last = 0; bool perched = false; long hostId = 0;
        timer.Tick += (_, _) =>
        {
            try
            {
                var now = watch.Elapsed.TotalSeconds; var dt = now - last; last = now; var windows = Native.Windows();
                var host = windows.FirstOrDefault(s => { Native.GetWindowThreadProcessId((nint)s.Id, out var pid); return pid == fixture.Id; });
                if (host != null && !perched) { hostId = host.Id; checks["crossProcessWindowEnumeration"] = true; bird.Perch(host); perched = true; var foreground = Native.GetForegroundWindow(); overlay.Render(bird, atlas, 0, 1, windows); checks["noFocusSteal"] = Native.GetForegroundWindow() == foreground; checks["ownOverlayDoesNotOcclude"]=!Native.Windows().Any(s=>s.Id==(long)overlay.Handle); var styles = (long)Native.GetWindowLongPtr(overlay.Handle, -20); checks["layeredClickThroughNonactivating"] = (styles & 0x8080020) == 0x8080020; }
                if (perched) { bird.UpdateHost(windows, dt, 1); bird.Tick(dt); overlay.Render(bird, atlas, 0, 1, windows); }
                if (now > 4.5)
                {
                    timer.Stop(); checks["slowWindowFollow"] = bird.Followed > 10; checks["fastWindowStartle"] = bird.Startles > 0; checks["flightHasNoHostDepth"] = bird.State == BirdState.Flying && bird.Depth == null;
                    var passed = checks.Values.All(x => x) && hostId != 0;
                    File.WriteAllText(Path.Combine(Program.DataFolder, "self-test.json"), JsonSerializer.Serialize(new { passed, checks }, Program.Json)); Environment.ExitCode = passed ? 0 : 1; context.ExitThread();
                }
            }
            catch (Exception e) { timer.Stop(); Program.Log(e); File.WriteAllText(Path.Combine(Program.DataFolder, "self-test.json"), JsonSerializer.Serialize(new { passed = false, error = e.ToString(), checks }, Program.Json)); Environment.ExitCode = 1; context.ExitThread(); }
        };
        timer.Start(); Application.Run(context); if (!fixture.HasExited) fixture.Kill();
    }
}
