using System.Diagnostics;
using System.Text.Json;
using Microsoft.Win32;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed class Desktop : ApplicationContext
{
    internal readonly Species[] Species;
    internal Preferences Settings;
    internal string T(string zh, string en) => Settings.English ? en : zh;
    readonly NotifyIcon tray; readonly ContextMenuStrip menu = new();
    readonly System.Windows.Forms.Timer timer = new() { Interval = 16 }; readonly Stopwatch clock = Stopwatch.StartNew();
    readonly Random rng = new(); readonly Dictionary<string, Bitmap> atlases = []; readonly Dictionary<string, int> frames;
    readonly List<(Bird Bird, Overlay View)> flock = []; List<Surface> surfaces = [];
    double last, metadataAge, populationAge = .8; bool paused; int arrivals, departures; double diagnosticAge;
    readonly HoverTracker<Bird> hover=new();
    readonly Overlay nameLabel=new();
    UpdateController? updater;
    Icon? normalIcon,badgedIcon;
    bool updateBalloon;
    SpeciesGallery? gallery;
    SettingsWindow? settingsWindow;
    internal static string SettingsPath => Path.Combine(Program.DataFolder, "settings.json");
    public Desktop()
    {
        using (var stream = Program.Resource("species.json")) Species = JsonSerializer.Deserialize<Catalog>(stream, Program.Json)!.Species;
        using (var stream = Program.Resource("art/manifest.json")) { using var doc = JsonDocument.Parse(stream); frames = doc.RootElement.GetProperty("frames").EnumerateArray().Select((e, i) => (e.GetString()!, i)).ToDictionary(x => x.Item1, x => x.i); }
        foreach (var s in Species) { using var stream = Program.Resource("art/" + s.Id + ".png"); using var image = Image.FromStream(stream); atlases[s.Id] = new Bitmap(image); }
        Settings = new() { Probability = Probabilities.From(Species), PerchDefaultsVersion=1 };
        if (File.Exists(SettingsPath)) { try { var saved = JsonSerializer.Deserialize<Preferences>(File.ReadAllText(SettingsPath), Program.Json)!; if (!saved.Migrate(Species) || !saved.Valid(Species.Length)) throw new InvalidDataException("Invalid saved settings"); Settings = saved; } catch (Exception e) { Program.Log(e); } }
        using (var stream = Program.Resource("AppIcon.ico")) tray = new() { Icon = new Icon(stream), Text = "啾啾 ChirpOS", Visible = true, ContextMenuStrip = menu };
        var initialIcon=tray.Icon!;normalIcon=(Icon)initialIcon.Clone();tray.Icon=normalIcon;initialIcon.Dispose();
        using(var bitmap=normalIcon.ToBitmap()) {
            using(var graphics=Graphics.FromImage(bitmap)){var size=Math.Max(5,bitmap.Width/3);graphics.FillEllipse(Brushes.White,bitmap.Width-size-1,0,size+1,size+1);graphics.FillEllipse(Brushes.Red,bitmap.Width-size,1,size-1,size-1);}
            var handle=bitmap.GetHicon();badgedIcon=(Icon)Icon.FromHandle(handle).Clone();DestroyIcon(handle);
        }
        updater=new UpdateController(this,UpdateChanged,ShowUpdateBalloon,()=>ExitThread());
        tray.BalloonTipClicked+=(_,_)=>{if(updateBalloon)updater?.ConfirmUpdate();};
        tray.DoubleClick += (_, _) => ShowSettings(); menu.Opening += (_, _) => BuildMenu(); BuildMenu();
        EventHandler? startup=null;
        startup=(_,_)=>{Application.Idle-=startup;updater?.Start();PromptNewSpecies();};Application.Idle+=startup;
        timer.Tick += (_, _) => Tick(); last = clock.Elapsed.TotalSeconds; timer.Start();
    }
    void BuildMenu()
    {
        while (menu.Items.Count > 0) { var item = menu.Items[0]; menu.Items.RemoveAt(0); item.Dispose(); }
        var count = flock.Count(x => !x.Bird.Departing);
        menu.Items.Add(T($"啾啾 · {count} 只小鸟", $"ChirpOS · {count} birds")).Enabled = false;
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(paused ? T("继续动画", "Resume animation") : T("暂停动画", "Pause animation"), null, (_, _) => paused = !paused);
        menu.Items.Add(T("让小鸟飞一会儿", "Let the birds fly"), null, (_, _) => { foreach (var b in flock.Where(x => !x.Bird.Departing)) Destination(b.Bird); });
        var pop = new ToolStripMenuItem(T("鸟群范围", "Population"));
        foreach (var range in new[] { (3, 5), (8, 12), (15, 20) }) { var item = new ToolStripMenuItem($"{range.Item1}–{range.Item2}") { Checked = Settings.Minimum == range.Item1 && Settings.Maximum == range.Item2 }; item.Click += (_, _) => { var copy = Clone(); copy.Minimum = range.Item1; copy.Maximum = range.Item2; Apply(copy); }; pop.DropDownItems.Add(item); }
        menu.Items.Add(pop);
        menu.Items.Add(T("图鉴…","Field guide…"),null,(_,_)=>{if(gallery is null || gallery.IsDisposed)gallery=new(this);gallery.Show();gallery.Activate();});
        menu.Items.Add(T("鸟种与数量设置…", "Bird and population settings…"), null, (_, _) => ShowSettings());
        var login = new ToolStripMenuItem(T("随系统启动", "Launch at Login")) { Checked = LoginEnabled() }; login.Click += (_, _) => { try { using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"); if (LoginEnabled()) key.DeleteValue("ChirpOS", false); else key.SetValue("ChirpOS", "\"" + Environment.ProcessPath + "\""); } catch (Exception e) { Error(e); } }; menu.Items.Add(login);
        menu.Items.Add(Settings.English ? "中文" : "English", null, (_, _) => { var copy = Clone(); copy.English = !copy.English; Apply(copy); });
        menu.Items.Add(T("打开项目主页", "Project website"), null, (_, _) => Process.Start(new ProcessStartInfo("https://github.com/billtt/chirp-os") { UseShellExecute = true }));
        if(updater is {} updates) {
            if(updates.Pending is {} ready){var item=menu.Items.Add(updates.Installing?T("正在安装更新…","Installing update…"):T($"安装更新 {ready.Release.Version}…",$"Install update {ready.Release.Version}…"),null,(_,_)=>updates.ConfirmUpdate());item.Enabled=!updates.Installing && !updates.Busy;}
            if(updates.Status.Length>0)menu.Items.Add(updates.Status).Enabled=false;
            var check=menu.Items.Add(T("检查更新…","Check for updates…"),null,async(_,_)=>await updates.Check(true));check.Enabled=!updates.Busy && !updates.Installing;
        }
        menu.Items.Add(new ToolStripSeparator()); menu.Items.Add(T("退出啾啾", "Quit ChirpOS"), null, (_, _) => ExitThread());
    }
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool DestroyIcon(nint icon);
    void UpdateChanged(){tray.Icon=updater?.Pending!=null?badgedIcon:normalIcon;tray.Text=updater?.Pending is {} ready?$"ChirpOS · {ready.Release.Version} ready":"啾啾 ChirpOS";if(!menu.Visible)BuildMenu();}
    void ShowUpdateBalloon(string text,bool actionable){updateBalloon=actionable;tray.ShowBalloonTip(12000,T("啾啾更新","ChirpOS update"),text,ToolTipIcon.Info);}
    static bool LoginEnabled() { using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"); return key?.GetValue("ChirpOS") as string == "\"" + Environment.ProcessPath + "\""; }
    internal Preferences Clone() => JsonSerializer.Deserialize<Preferences>(JsonSerializer.Serialize(Settings, Program.Json), Program.Json)!;
    internal bool Apply(Preferences p) { try { p.SpeciesIds=Species.Select(s=>s.Id).ToArray(); if (!p.Valid(Species.Length)) throw new InvalidDataException(T("设置无效", "Invalid settings")); Directory.CreateDirectory(Program.DataFolder); var temp = SettingsPath + ".tmp"; File.WriteAllText(temp, JsonSerializer.Serialize(p, Program.Json)); File.Move(temp, SettingsPath, true); Settings = p; populationAge = Math.Min(populationAge, 1); return true; } catch (Exception e) { Error(e); return false; } }
    void Error(Exception e) { Program.Log(e); MessageBox.Show(e.Message, T("啾啾", "ChirpOS"), MessageBoxButtons.OK, MessageBoxIcon.Error); }
    void PromptNewSpecies() {
        var ids=Settings.PendingSpeciesIds ?? [];if(ids.Length==0)return;
        using var prompt=new NewSpeciesPrompt(this,ids.Length);prompt.ShowDialog();
        if(prompt.Choice<0)return;
        if(prompt.Choice==2){ShowSettings();settingsWindow?.ScrollToSpecies(ids[0]);return;}
        var draft=Clone();
        if(prompt.Choice==0)draft.Probability=Probabilities.From(Species);else draft.AllocateNewSpecies(Species);
        draft.PendingSpeciesIds=[];Apply(draft);
    }
    void ShowSettings() { if (settingsWindow is { IsDisposed: false }) { settingsWindow.Activate(); return; } settingsWindow = new(this); settingsWindow.Show(); }
    internal string Name(Species s) => Settings.English ? s.EnglishName ?? (s.Id switch { "redWhiskeredBulbul" => "Red-whiskered Bulbul", "treeSparrow" => "Eurasian Tree Sparrow", "lightVentedBulbul" => "Light-vented Bulbul", "spottedDove" => "Spotted Dove", "chineseBlackbird" => "Chinese Blackbird", "magpieRobin" => "Oriental Magpie-Robin", "longTailedShrike" => "Long-tailed Shrike", _ => s.Name }) : s.Name;
    static Box Bounds(Screen s) => new(s.Bounds.X, s.Bounds.Y, s.Bounds.Width, s.Bounds.Height);
    double Scale(Bird b) => Settings.Scale * b.Species.Scale * Native.DpiScale(Screen.FromPoint(new((int)b.Position.X, (int)b.Position.Y)));
    V Outside() { var screens = Screen.AllScreens; var left = screens.Min(s => s.Bounds.Left); var right = screens.Max(s => s.Bounds.Right); var side = rng.Next(2) == 0; var edge = screens.First(s => side ? s.Bounds.Left == left : s.Bounds.Right == right); return new(side ? left - 500 : right + 500, edge.Bounds.Top + edge.Bounds.Height * (.2 + rng.NextDouble() * .55)); }
    double Travel(Bird b, V target) => Math.Max(2.8, V.Distance(b.Position, target) / 400 * 2);
    void Destination(Bird b, bool entering = false)
    {
        var occupied=flock.Where(x=>x.Bird!=b && !x.Bird.Departing && x.Bird.Host!=null).Select(x=>{
            var host=surfaces.FirstOrDefault(s=>s.Id==x.Bird.Host);
            if(host==null)return (Box?)null;
            var foot=Geometry.Foot(host,x.Bird.Fraction,x.Bird.Edge);
            var scale=Settings.Scale*x.Bird.Species.Scale*Native.DpiScale(Screen.FromPoint(new((int)foot.X,(int)foot.Y)));
            var rect=Geometry.Landing(foot,scale);
            return (Box?)new Box(rect.X-8,rect.Y-8,rect.W+16,rect.H+16);
        }).Where(x=>x.HasValue).Select(x=>x!.Value).ToArray();
        if(b.Species.Id=="greatSpottedWoodpecker") {
            var sides=new List<(Surface Host,PerchEdge Edge,double Lo,double Hi)>();
            foreach(var host in surfaces.Where(s=>s.CanPerch && s.Rect.H>=180))foreach(var edge in new[]{PerchEdge.Left,PerchEdge.Right})foreach(var screen in Screen.AllScreens)
                foreach(var q in Geometry.SideRanges(host,edge,surfaces,Bounds(screen),Settings.Scale*b.Species.Scale*Native.DpiScale(screen),occupied))sides.Add((host,edge,q.Lo,q.Hi));
            var pick=rng.NextDouble()*sides.Sum(q=>q.Hi-q.Lo);
            foreach(var q in sides){if(pick<q.Hi-q.Lo){b.Edge=q.Edge;b.Fraction=(q.Lo+pick-q.Host.Rect.Y-42)/(q.Host.Rect.H-84);var foot=Geometry.Foot(q.Host,b.Fraction,q.Edge);b.Fly(foot,q.Host,entering?Travel(b,foot):3,airspace:Airspace(b,foot));return;}pick-=q.Hi-q.Lo;}
        }
        b.Edge=PerchEdge.Top;
        var choices=new List<(Surface Host,Screen Screen,double Lo,double Hi)>();
        foreach(var host in surfaces.Where(s=>s.CanPerch))foreach(var screen in Screen.AllScreens){
            var scale=Settings.Scale*b.Species.Scale*Native.DpiScale(screen);
            foreach(var range in Geometry.LandingRanges(host,surfaces,Bounds(screen),scale,occupied))choices.Add((host,screen,range.Lo,range.Hi));
        }
        var total=choices.Sum(c=>c.Hi-c.Lo);var ticket=rng.NextDouble()*total;
        foreach(var choice in choices){
            var length=choice.Hi-choice.Lo;
            if(ticket<length){
                var foot=new V(choice.Lo+ticket,choice.Host.Rect.Y);
                b.Fraction=(foot.X-Geometry.Foot(choice.Host,0).X)/(Geometry.Foot(choice.Host,1).X-Geometry.Foot(choice.Host,0).X);
                b.Fly(foot,choice.Host,entering?Travel(b,foot):2.6+rng.NextDouble()*2.2,90*Native.DpiScale(choice.Screen),airspace:Airspace(b,foot));return;
            }
            ticket-=length;
        }
        var screenFallback = Screen.AllScreens[rng.Next(Screen.AllScreens.Length)].WorkingArea;
        var p = new V(screenFallback.Left + 70 + rng.NextDouble() * Math.Max(1, screenFallback.Width - 140), screenFallback.Top + 110 + rng.NextDouble() * Math.Max(1, screenFallback.Height - 190)); b.Fly(p, null, entering ? Travel(b, p) : 4.5, 40,airspace:Airspace(b,p));
    }
    void Arrive() { var b = new Bird(Settings.Resolve(Species[Settings.Probability.Choose(rng)]), Outside(), rng); var overlay = new Overlay(); flock.Add((b, overlay)); arrivals++; Destination(b, true); }
    Box Airspace(Bird b,V point) {
        var screen=Screen.FromPoint(new Point((int)point.X,(int)point.Y));var r=screen.WorkingArea;
        var scale=Settings.Scale*b.Species.Scale*Native.DpiScale(screen);
        return new(r.Left+29*scale,r.Top+39*scale,Math.Max(0,r.Width-58*scale),Math.Max(0,r.Height-48*scale));
    }
    void Depart(Bird b) { var p = Outside(); b.Fly(p, null, Travel(b, p), 30, true); }
    void Tick()
    {
        var now = clock.Elapsed.TotalSeconds; var elapsed = now - last; last = now; var dt = Math.Clamp(elapsed, 0, .05);
        if (!Native.DesktopAvailable()) { foreach (var x in flock) x.View.Hide(); nameLabel.Hide(); hover.Update(null,now); return; }
        metadataAge += elapsed;
        if (metadataAge >= 1.0 / 30) { surfaces = Native.Windows(); foreach (var (b, _) in flock) b.UpdateHost(surfaces, metadataAge, Scale(b)); metadataAge = 0; }
        if (!paused)
        {
            populationAge -= dt;
            if (populationAge <= 0)
            {
                var residents = flock.Where(x => !x.Bird.Departing).ToArray(); var n = residents.Length;
                if (n < Settings.Minimum || (n < Settings.Maximum && rng.NextDouble() < .58)) { if (flock.Count < Settings.Maximum + 4) Arrive(); }
                else if (n > Settings.Maximum || (n > Settings.Minimum && rng.NextDouble() < .55)) Depart(residents[rng.Next(n)].Bird);
                populationAge = (n < Settings.Minimum || n > Settings.Maximum) ? 2.5 + rng.NextDouble() * 3.5 : 24 + rng.NextDouble() * 24;
            }
            foreach (var (b, _) in flock) { b.Tick(dt); if (b.NeedsDestination) Destination(b); }
            for (var i = flock.Count - 1; i >= 0; i--) { var b = flock[i].Bird; var size = 48 * Scale(b); if (b.DepartureFinished && !Screen.AllScreens.Any(s => Bounds(s).Intersects(new(b.Position.X - size, b.Position.Y - size, size * 2, size * 2)))) { flock[i].View.Dispose(); flock.RemoveAt(i); departures++; } }
        }
        foreach (var (b, view) in flock) view.Render(b, atlases[b.Species.Id], frames[b.Frame], Scale(b), surfaces);
        var mouse=Cursor.Position;
        var hit=flock.AsEnumerable().Reverse().Select(x=>x.Bird).FirstOrDefault(b=>{
            var s=Scale(b);var px=(mouse.X-b.Position.X)/s+(b.Right?29:19);var py=(mouse.Y-b.Position.Y)/s-b.Hop+39;
            if(px<0 || px>=48 || py<0 || py>=48 || b.Blockers(surfaces).Any(r=>mouse.X>=r.X && mouse.X<r.Right && mouse.Y>=r.Y && mouse.Y<r.Bottom))return false;
            var atlas=atlases[b.Species.Id];var n=atlas.Height;
            return atlas.GetPixel(frames[b.Frame]*n+(b.Right?(int)(px*n/48):n-1-(int)(px*n/48)),(int)(py*n/48)).A>0;
        });
        var named=hover.Update(hit,now);
        if(named!=null) {
            var image=atlases[named.Species.Id];var frame=frames[named.Frame];var top=0;
            for(var y=0;y<48;y++){if(Enumerable.Range(0,48).Any(x=>image.GetPixel(frame*image.Height+x*image.Height/48,y*image.Height/48).A>0)){top=y;break;}}
            nameLabel.RenderName(Name(named.Species),new(named.Position.X,named.Position.Y+named.Hop*Scale(named)),Scale(named),top);
        }else nameLabel.Hide();
        diagnosticAge += dt; if (diagnosticAge > 2) { diagnosticAge = 0; Directory.CreateDirectory(Program.DataFolder); File.WriteAllText(Path.Combine(Program.DataFolder, "diagnostics.json"), JsonSerializer.Serialize(new { version = "0.3.2", windowDetails = Native.WindowDiagnostics.ToArray(), windows = surfaces.Count, residents = flock.Count(x => !x.Bird.Departing), arrivals, departures, monitors = Screen.AllScreens.Length, birds = flock.Select(x => new { x.Bird.Species.Id, state = x.Bird.State.ToString(), x.Bird.Position, x.Bird.Landings, x.Bird.Followed, x.Bird.Startles }) }, Program.Json)); }
    }
    protected override void ExitThreadCore() { updater?.Dispose(); timer.Stop(); timer.Dispose(); nameLabel.Dispose(); tray.Visible = false; tray.Dispose(); normalIcon?.Dispose();badgedIcon?.Dispose(); settingsWindow?.Dispose(); gallery?.Dispose(); foreach (var b in flock) b.View.Dispose(); foreach (var image in atlases.Values) image.Dispose(); menu.Dispose(); base.ExitThreadCore(); }
}
