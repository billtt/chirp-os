using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed record ReadyUpdate(string Token,UpdateRelease Release);
internal sealed record UpdateTicket(string Token,UpdateRelease Release,string Target,int ParentPID,long ParentStartTicks,DateTimeOffset Created);
internal sealed record UpdateHealth(string Token,string Version,int PID);
internal static class UpdateInstaller {
    internal static readonly string Base=Path.Combine(Program.DataFolder,"Updates");
    internal static string Root(string token)=>Path.Combine(Base,token);
    internal static string CurrentVersion=>typeof(Program).Assembly.GetName().Version is {} v?$"{v.Major}.{v.Minor}.{v.Build}":"0.0.0";
    internal static string Platform=>RuntimeInformation.ProcessArchitecture==Architecture.Arm64?"win-arm64":"win-x64";
    internal static string UpdatePlatform => Platform
#if CHIRPOS_FRAMEWORK_DEPENDENT
        + "-framework-dependent"
#endif
        ;
    internal static void Write<T>(T value,string path){var temp=path+".tmp";File.WriteAllText(temp,JsonSerializer.Serialize(value,Program.Json));File.Move(temp,path,true);}
    internal static T Read<T>(string path)=>JsonSerializer.Deserialize<T>(File.ReadAllText(path),Program.Json) ?? throw new InvalidDataException("Invalid update state");
    internal static UpdateTicket Load(string token,bool allowExpired=false) {
        if(!Guid.TryParseExact(token,"D",out _) || new DirectoryInfo(Root(token)).Attributes.HasFlag(FileAttributes.ReparsePoint))throw new InvalidDataException("Invalid update ticket");
        var t=Read<UpdateTicket>(Path.Combine(Root(token),"transaction.json"));
        if(t.Token!=token || (!allowExpired && DateTimeOffset.UtcNow-t.Created>TimeSpan.FromDays(7)))throw new InvalidDataException("Expired update ticket");
        _=new UpdateReplacement(t.Target,token);return t;
    }
    internal static void ValidateExecutable(string path,UpdateRelease release) {
        UpdateArchive.ValidatePE(path,Platform);
        var version=FileVersionInfo.GetVersionInfo(path);
        if($"{version.FileMajorPart}.{version.FileMinorPart}.{version.FileBuildPart}"!=release.Version || version.ProductName!="ChirpOS")throw new InvalidDataException("Update executable identity/version mismatch");
    }
    internal static void Stage(UpdateRelease release,string token) {
        var zip=Path.Combine(Root(token),"package.zip");var exe=Path.Combine(Root(token),"ChirpOS.exe");release.Verify(zip);
        File.Delete(exe);UpdateArchive.ExtractExecutable(zip,exe);ValidateExecutable(exe,release);
    }
    internal static void Prepare(UpdateTicket t) {
        Stage(t.Release,t.Token);var replacement=new UpdateReplacement(t.Target,t.Token);
        replacement.Prepare(Path.Combine(Root(t.Token),"ChirpOS.exe"));
        try {
            ValidateExecutable(replacement.Candidate,t.Release);
            Write(t,Path.Combine(Root(t.Token),"transaction.json"));
            File.Delete(Path.Combine(Root(t.Token),"cancel"));
            File.Delete(Path.Combine(Root(t.Token),"helper-ready"));File.Delete(Path.Combine(Root(t.Token),"healthy.json"));
            var helper=Path.Combine(Root(t.Token),"installer.exe");File.Copy(Environment.ProcessPath!,helper,true);
            var p=new ProcessStartInfo(helper){UseShellExecute=false,CreateNoWindow=true};p.ArgumentList.Add("--apply-update");p.ArgumentList.Add(t.Token);
            _ = Process.Start(p) ?? throw new IOException("Update helper did not start");
        } catch {File.Delete(replacement.Candidate);throw;}
    }
    static bool ParentAlive(UpdateTicket t) {
        try {using var p=Process.GetProcessById(t.ParentPID);return !p.HasExited && p.StartTime.ToUniversalTime().Ticks==t.ParentStartTicks;}
        catch(ArgumentException){return false;}
    }
    static Process Launch(string target,params string[] args) {var info=new ProcessStartInfo(target){UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(target)!};foreach(var arg in args)info.ArgumentList.Add(arg);return Process.Start(info) ?? throw new IOException("New version did not start");}
    internal static int RunHelper(string token) {
        UpdateTicket? ticket=null;UpdateReplacement? replacement=null;Process? launched=null;var replaced=false;
        try {
            var t=Load(token);ticket=t;var r=new UpdateReplacement(t.Target,token);replacement=r;
            Stage(t.Release,token);ValidateExecutable(r.Candidate,t.Release);
            using(var original=File.OpenRead(Path.Combine(Root(token),"ChirpOS.exe")))using(var candidate=File.OpenRead(r.Candidate))
                if(!System.Security.Cryptography.SHA256.HashData(original).SequenceEqual(System.Security.Cryptography.SHA256.HashData(candidate)))throw new InvalidDataException("Staged executable changed after verification");
            File.WriteAllText(Path.Combine(Root(token),"helper-pid"),Environment.ProcessId.ToString());
            File.WriteAllText(Path.Combine(Root(token),"helper-ready"),"");
            var deadline=DateTimeOffset.UtcNow.AddSeconds(60);
            while(ParentAlive(t) && DateTimeOffset.UtcNow<deadline && !File.Exists(Path.Combine(Root(token),"cancel")))Thread.Sleep(100);
            if(File.Exists(Path.Combine(Root(token),"cancel")))throw new IOException("Installation was cancelled before replacement");
            if(ParentAlive(t))throw new IOException("Previous version did not exit");
            // Antivirus may retain a handle briefly after process exit.
            for(var i=0;;i++){try{r.Replace();break;}catch(IOException)when(i<30){Thread.Sleep(200);}}
            replaced=true;launched=Launch(t.Target,"--update-launch",token);
            deadline=DateTimeOffset.UtcNow.AddSeconds(90);
            while(DateTimeOffset.UtcNow<deadline) {
                if(launched.HasExited)throw new IOException("New version exited during startup");
                var path=Path.Combine(Root(token),"healthy.json");
                if(File.Exists(path)){var h=Read<UpdateHealth>(path);if(h.Token==token && h.Version==t.Release.Version && h.PID==launched.Id){try{File.WriteAllText(Path.Combine(Root(token),"complete"),"");r.Complete();ClearReady(token);}catch(Exception cleanup){Program.Log(cleanup);}return 0;}}
                Thread.Sleep(200);
            }
            throw new IOException("New version did not confirm successful startup");
        } catch(Exception error) {
            Program.Log(error);
            if(ticket is {} t){try {File.WriteAllText(Path.Combine(Base,"last-error.txt"),error.Message);}catch{} }
            var recovered=!replaced;
            if(replaced && replacement is {} r){try{if(launched is {HasExited:false}){launched.Kill();launched.WaitForExit(5000);}r.Rollback();recovered=true;Launch(r.Target);}catch(Exception e){Program.Log(e);}}
            else if(replacement is {} prepared){try{File.Delete(prepared.Candidate);}catch{}}
            if(ticket is {} failed){try{File.Delete(Path.Combine(Root(failed.Token),"helper-ready"));if(recovered)File.Delete(Path.Combine(Root(failed.Token),"transaction.json"));}catch{}}
            return 1;
        } finally {launched?.Dispose();}
    }
    internal static void ClearReady(string token) {
        try {var path=Path.Combine(Base,"ready.json");if(File.Exists(path) && Read<ReadyUpdate>(path).Token==token)File.Delete(path);}catch(Exception e){Program.Log(e);}
    }
    internal static void PruneCache() {
        if(!Directory.Exists(Base))return;
        try {
            var stale=Read<ReadyUpdate>(Path.Combine(Base,"ready.json"));
            if(Guid.TryParseExact(stale.Token,"D",out _) && UpdateVersion.Parse(stale.Release.Version) is {} version && version.CompareTo(UpdateVersion.Parse(CurrentVersion))<=0 && !new DirectoryInfo(Root(stale.Token)).Attributes.HasFlag(FileAttributes.ReparsePoint) && !File.Exists(Path.Combine(Root(stale.Token),"transaction.json"))){ClearReady(stale.Token);Directory.Delete(Root(stale.Token),true);}
        }catch{}
        string? ready=null;try{ready=Read<ReadyUpdate>(Path.Combine(Base,"ready.json")).Token;}catch{}
        foreach(var root in Directory.GetDirectories(Base))try{
            var token=Path.GetFileName(root);var info=new DirectoryInfo(root);
            if(Guid.TryParseExact(token,"D",out _) && token!=ready && !info.Attributes.HasFlag(FileAttributes.ReparsePoint) && !File.Exists(Path.Combine(root,"transaction.json")) && DateTime.UtcNow-info.LastWriteTimeUtc>TimeSpan.FromDays(7))Directory.Delete(root,true);
        }catch(Exception e){Program.Log(e);}
    }
    internal static void CleanupConfirmed() {
        if(!Directory.Exists(Base))return;
        foreach(var root in Directory.GetDirectories(Base))try{
            var token=Path.GetFileName(root);
            if(!Guid.TryParseExact(token,"D",out _) || new DirectoryInfo(root).Attributes.HasFlag(FileAttributes.ReparsePoint) || !File.Exists(Path.Combine(root,"complete")))continue;
            var t=Read<UpdateTicket>(Path.Combine(root,"transaction.json"));
            if(t.Token!=token || t.Target!=Environment.ProcessPath || UpdateVersion.Parse(t.Release.Version) is not {} version || version.CompareTo(UpdateVersion.Parse(CurrentVersion))>0)continue;
            new UpdateReplacement(t.Target,token).Complete();ClearReady(token);Directory.Delete(root,true);
        }catch(Exception e){Program.Log(e);}
    }
    internal static void ConfirmHealthy(string[] args) {
        CleanupConfirmed();
        // Recover a candidate left by a power loss before the atomic replacement.
        foreach(var root in Directory.Exists(Base)?Directory.GetDirectories(Base):[])try{
            var t=Load(Path.GetFileName(root),true);
            if(t.Target!=Environment.ProcessPath || UpdateVersion.Parse(t.Release.Version) is not {} version || version.CompareTo(UpdateVersion.Parse(CurrentVersion))<=0)continue;
            var replacement=new UpdateReplacement(t.Target,t.Token);if(File.Exists(replacement.Backup))continue;
            var alive=false;try{using var helper=Process.GetProcessById(int.Parse(File.ReadAllText(Path.Combine(root,"helper-pid"))));alive=!helper.HasExited;}catch{}
            if(alive)continue;
            File.Delete(replacement.Candidate);File.Delete(Path.Combine(root,"transaction.json"));
        }catch(Exception e){Program.Log(e);}
        var i=Array.IndexOf(args,"--update-launch");
        try {
            var candidates=i>=0 && i+1<args.Length?new[]{args[i+1]}:(Directory.Exists(Base)?Directory.GetDirectories(Base).Select(Path.GetFileName).OfType<string>().ToArray():[]);
            UpdateTicket? found=null;
            foreach(var candidate in candidates){try{var value=Load(candidate,true);if(value.Target==Environment.ProcessPath && value.Release.Version==CurrentVersion){found=value;break;}}catch{}}
            if(found is not {} t)return;var token=t.Token;
            // This timer fires only after the UI message loop has run successfully.
            var timer=new System.Windows.Forms.Timer{Interval=10000};
            timer.Tick+=(_,_)=>{
                timer.Stop();timer.Dispose();
                try {Write(new UpdateHealth(token,CurrentVersion,Environment.ProcessId),Path.Combine(Root(token),"healthy.json"));}catch(Exception e){Program.Log(e);return;}
                _=Task.Run(async()=>{
                    for(var attempt=0;attempt<120;attempt++) {
                        await Task.Delay(1000);
                        if(!Directory.Exists(Root(token)))return;
                        if(!File.Exists(Path.Combine(Root(token),"complete"))) {
                            var alive=false;
                            try{var pid=int.Parse(File.ReadAllText(Path.Combine(Root(token),"helper-pid")));using var helper=Process.GetProcessById(pid);alive=!helper.HasExited;}catch{}
                            if(alive)continue;
                            try{File.WriteAllText(Path.Combine(Root(token),"complete"),"");}catch{continue;}
                        }
                        try {new UpdateReplacement(t.Target,token).Complete();ClearReady(token);Directory.Delete(Root(token),true);return;}catch(IOException){}catch(UnauthorizedAccessException){}
                    }
                });
            };timer.Start();
        } catch(Exception e){Program.Log(e);}
    }
}
