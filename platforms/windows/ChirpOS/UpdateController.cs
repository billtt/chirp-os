using System.Diagnostics;
using System.Net;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed class UpdateController:IDisposable {
    readonly Desktop desktop;
    readonly Action changed,exit;
    readonly Action<string,bool> notify;
    readonly HttpClient client;
    readonly System.Windows.Forms.Timer timer=new(){Interval=60000};
    readonly CancellationTokenSource lifetime=new();
    UpdateJournal journal=new();bool confirming;
    ReadyUpdate? verifiedPending,simulatedPending;
    internal ReadyUpdate? Pending => simulatedPending ?? verifiedPending;
    internal bool IsSimulating => simulatedPending!=null;
    internal bool Busy {get;private set;}
    internal bool Installing {get;private set;}
    internal string Status {get;private set;}="";
    internal UpdateController(Desktop desktop,Action changed,Action<string,bool> notify,Action exit) {
        this.desktop=desktop;this.changed=changed;this.notify=notify;this.exit=exit;
        client=new(new HttpClientHandler{AllowAutoRedirect=false}){Timeout=TimeSpan.FromMinutes(15)};
        client.DefaultRequestHeaders.UserAgent.ParseAdd("ChirpOS/"+UpdateInstaller.CurrentVersion);
        client.DefaultRequestHeaders.Add("X-GitHub-Api-Version","2022-11-28");
        timer.Tick+=async(_,_)=>await Check();
    }
    internal async void Start() {
        try {
            Directory.CreateDirectory(UpdateInstaller.Base);UpdateInstaller.PruneCache();
            var previousError=Path.Combine(UpdateInstaller.Base,"last-error.txt");
            if(File.Exists(previousError)){notify(desktop.T("上次更新未完成，可从菜单重试。","The last update did not finish; retry from the menu."),false);File.Delete(previousError);}
            var state=Path.Combine(UpdateInstaller.Base,"state.json");
            if(File.Exists(state)){try{journal=UpdateInstaller.Read<UpdateJournal>(state);}catch{journal=new();}}
            journal.Announced ??=[];journal.Failures=Math.Clamp(journal.Failures,0,3);
            if(journal.NextCheck>DateTimeOffset.UtcNow.AddHours(1))journal.NextCheck=DateTimeOffset.UtcNow;
            var path=Path.Combine(UpdateInstaller.Base,"ready.json");
            if(File.Exists(path)) {
                ReadyUpdate? ready=null;
                try {
                    ready=UpdateInstaller.Read<ReadyUpdate>(path);
                    if(Guid.TryParseExact(ready.Token,"D",out _) && UpdateVersion.Parse(ready.Release.Version) is {} version && version.CompareTo(UpdateVersion.Parse(UpdateInstaller.CurrentVersion))>0){
                        Busy=true;await Task.Run(()=>UpdateInstaller.Stage(ready.Release,ready.Token),lifetime.Token);verifiedPending=ready;Announce();
                    }
                }catch(Exception e){Program.Log(e);if(ready!=null)UpdateInstaller.ClearReady(ready.Token);}
                finally{Busy=false;changed();}
            }
            timer.Start();await Task.Delay(15000,lifetime.Token);await Check();
        } catch(OperationCanceledException){}catch(Exception e){Program.Log(e);Status=desktop.T("自动更新暂不可用","Automatic updates are unavailable");changed();}
    }
    void Save()=>UpdateInstaller.Write(journal,Path.Combine(UpdateInstaller.Base,"state.json"));
    async Task<HttpResponseMessage> Get(string url,CancellationToken cancellation) {
        for(var redirects=0;redirects<6;redirects++){
            var response=await client.GetAsync(url,HttpCompletionOption.ResponseHeadersRead,cancellation);
            if((int)response.StatusCode is >=300 and <400){
                var next=response.Headers.Location;response.Dispose();
                if(next is null || !next.IsAbsoluteUri || next.Scheme!="https" || !new[]{"github.com","release-assets.githubusercontent.com","objects.githubusercontent.com"}.Contains(next.Host))throw new InvalidDataException("Untrusted update redirect");
                url=next.AbsoluteUri;continue;
            }
            return response;
        }
        throw new IOException("Too many update redirects");
    }
    internal async Task Check(bool manual=false) {
        if(IsSimulating || Busy || Installing || confirming || (!manual && DateTimeOffset.UtcNow<journal.NextCheck))return;
        using var timeout=CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);timeout.CancelAfter(TimeSpan.FromMinutes(15));var cancellation=timeout.Token;
        Busy=true;Status=desktop.T("正在检查更新…","Checking for updates…");changed();string? temporary=null;
        try {
            using var response=await Get(UpdateRelease.Endpoint,cancellation);
            if(response.StatusCode!=HttpStatusCode.NotFound) {
                response.EnsureSuccessStatusCode();
                using var metadata=new MemoryStream();await CopyBounded(await response.Content.ReadAsStreamAsync(cancellation),metadata,2_000_000,cancellation);
                var release=UpdateRelease.Select(metadata.ToArray(),UpdateInstaller.CurrentVersion,UpdateInstaller.UpdatePlatform);
                if(release!=null) {
                    if(Pending?.Release!=release) {
                        Status=desktop.T("正在下载并校验更新…","Downloading and verifying update…");changed();
                        var token=Guid.NewGuid().ToString("D");temporary=token;var root=UpdateInstaller.Root(token);Directory.CreateDirectory(root);
                        if(new DriveInfo(Path.GetPathRoot(root)!).AvailableFreeSpace<release.Size*4+100_000_000)throw new IOException("Not enough free space for the update");
                        using(var download=await Get(release.DownloadURL,cancellation)){
                            download.EnsureSuccessStatusCode();if(download.Content.Headers.ContentLength>release.Size)throw new InvalidDataException("Update package exceeds declared size");
                            using var output=new FileStream(Path.Combine(root,"package.zip"),FileMode.CreateNew,FileAccess.Write,FileShare.None);
                            await CopyBounded(await download.Content.ReadAsStreamAsync(cancellation),output,release.Size,cancellation);
                        }
                        await Task.Run(()=>UpdateInstaller.Stage(release,token),cancellation);
                        var ready=new ReadyUpdate(token,release);UpdateInstaller.Write(ready,Path.Combine(UpdateInstaller.Base,"ready.json"));
                        var previous=Pending;verifiedPending=ready;temporary=null;
                        if(previous!=null){try{Directory.Delete(UpdateInstaller.Root(previous.Token),true);}catch(Exception e){Program.Log(e);}}
                        Announce();
                    }
                } else if(manual)notify(desktop.T("目前已是最新可用版本。","You have the latest available version."),false);
            } else if(manual)notify(desktop.T("暂无可用的新版本。","No new release is available."),false);
            journal.FinishCheck(DateTimeOffset.UtcNow,true);Status="";
        } catch(OperationCanceledException)when(lifetime.IsCancellationRequested){}
        catch(Exception e){Program.Log(e);journal.FinishCheck(DateTimeOffset.UtcNow,false);Status=desktop.T("更新检查失败，将自动重试","Update check failed; retry scheduled");if(manual)notify(e.Message,false);}
        finally {
            if(temporary!=null){try{Directory.Delete(UpdateInstaller.Root(temporary),true);}catch{}}
            try{Save();}catch(Exception e){Program.Log(e);}Busy=false;if(!lifetime.IsCancellationRequested)changed();
        }
    }
    static async Task CopyBounded(Stream input,Stream output,long limit,CancellationToken token) {
        using(input){var buffer=new byte[65536];long total=0;int n;while((n=await input.ReadAsync(buffer,token))>0){total+=n;if(total>limit)throw new InvalidDataException("Update download exceeds size limit");await output.WriteAsync(buffer.AsMemory(0,n),token);}}
    }
    internal bool SimulateUpdate() {
        if(Busy || Installing || confirming)return false;
        simulatedPending=new(Guid.NewGuid().ToString("D"),new UpdateRelease("99.0.0",desktop.T(
            "更新提示效果预览\r\n\r\n• 更自然的小鸟动作\r\n• 优化桌面停留体验\r\n• 保留现有设置\r\n\r\n这是模拟更新。确认安装后恢复原状态，不会下载、安装或重启。",
            "Update preview\r\n\r\n• More natural bird animations\r\n• Improved desktop perching\r\n• Keep existing settings\r\n\r\nThis is a simulated update. Confirming restores the previous state without downloading, installing or restarting."),"","","",0));
        changed();ShowReadyNotification();return true;
    }
    void ShowReadyNotification() {
        if(Pending is {} ready)notify(desktop.T($"啾啾 {ready.Release.Version} 已下载并校验，点击查看更新。",$"ChirpOS {ready.Release.Version} is ready. Click to review the update."),true);
    }
    void Announce() {
        if(Pending is not {} ready || !journal.Announce(ready.Release.Version))return;
        Save();changed();ShowReadyNotification();
    }
    internal async void ConfirmUpdate() {
        if(Pending is not {} ready || Installing || Busy || confirming)return;
        confirming=true;
        using var dialog=new Form{Text=desktop.T($"安装啾啾 {ready.Release.Version}？",$"Install ChirpOS {ready.Release.Version}?"),ClientSize=new(540,380),MinimumSize=new(480,340),StartPosition=FormStartPosition.CenterScreen,ShowInTaskbar=true,MinimizeBox=false,MaximizeBox=false};
        var footer=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=52,FlowDirection=FlowDirection.RightToLeft,Padding=new Padding(8)};
        var later=new Button{Text=desktop.T("晚点再说","Later"),DialogResult=DialogResult.Cancel,AutoSize=true};
        var install=new Button{Text=desktop.T("安装并重启","Install and restart"),DialogResult=DialogResult.OK,AutoSize=true};footer.Controls.Add(later);footer.Controls.Add(install);
        var label=new Label{Dock=DockStyle.Top,Height=55,Padding=new Padding(12),Text=desktop.T("更新已下载并校验。安装后自动重启，设置会保留。","The update is verified. ChirpOS will restart and keep your settings.")};
        var notes=new TextBox{Dock=DockStyle.Fill,Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,Text=string.IsNullOrEmpty(ready.Release.Notes)?desktop.T("此版本未提供更新说明。","No release notes were provided."):ready.Release.Notes};
        dialog.Controls.Add(notes);dialog.Controls.Add(label);dialog.Controls.Add(footer);dialog.AcceptButton=install;dialog.CancelButton=later;
        var result=dialog.ShowDialog();confirming=false;if(result!=DialogResult.OK)return;
        if(IsSimulating){simulatedPending=null;changed();return;}
        Installing=true;changed();
        try {
            using var current=Process.GetCurrentProcess();
            var ticket=new UpdateTicket(ready.Token,ready.Release,Environment.ProcessPath!,Environment.ProcessId,current.StartTime.ToUniversalTime().Ticks,DateTimeOffset.UtcNow);
            await Task.Run(()=>UpdateInstaller.Prepare(ticket),lifetime.Token);
            var started=false;
            for(var i=0;i<100;i++){if(File.Exists(Path.Combine(UpdateInstaller.Root(ready.Token),"helper-ready"))){started=true;break;}await Task.Delay(100,lifetime.Token);}
            if(!started){File.WriteAllText(Path.Combine(UpdateInstaller.Root(ready.Token),"cancel"),"");throw new IOException("Update helper could not start; the current version will keep running");}
            exit();
        } catch(Exception e){Program.Log(e);Installing=false;Status=desktop.T("更新安装失败，可从菜单重试","Installation failed; retry from the menu");notify(e.Message,false);changed();}
    }
    public void Dispose(){timer.Dispose();lifetime.Cancel();client.Dispose();}
}
