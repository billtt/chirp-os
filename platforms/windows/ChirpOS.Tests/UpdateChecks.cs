using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChirpOS.Core;

internal static class UpdateChecks {
    internal static int Run() {
        var count=0;
        void Check(bool ok,string name){if(!ok)throw new Exception(name);count++;Console.WriteLine("PASS update: "+name);}
        void Reject(Action action,string name){try{action();}catch(Exception e) when(e is InvalidDataException or IOException or UnauthorizedAccessException){Check(true,name);return;}throw new Exception("Did not reject "+name);}
        byte[] Feed(string tag="v1.10.0",string platform="win-arm64",string? digest="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",string? url=null,bool draft=false,bool prerelease=false) {
            var name=$"ChirpOS-{tag.TrimStart('v')}-{platform}.zip";
            return JsonSerializer.SerializeToUtf8Bytes(new{tag_name=tag,body="## Changes\nA fix",draft,prerelease,assets=new[]{new{name,state="uploaded",size=100,digest,browser_download_url=url??$"https://github.com/billtt/chirp-os/releases/download/{tag}/{name}"}}});
        }
        Check(UpdateVersion.Parse("1.10.0")!.CompareTo(UpdateVersion.Parse("1.9.99"))>0,"numeric comparison");
        foreach(var v in new[]{"1.2","1.2.3-beta","1.2.3+debug","-1.2.3","1.2.３","1.2.3/evil","1.2.999999999999"})Check(UpdateVersion.Parse(v)==null,"reject version "+v);
        Check(UpdateRelease.Select(Feed(),"1.9.0","win-arm64")?.Version=="1.10.0","select matching stable release");
        Check(UpdateRelease.Select(Feed(),"1.10.0","win-arm64")==null && UpdateRelease.Select(Feed(),"2.0.0","win-arm64")==null,"no equal-version update or downgrade");
        Check(UpdateRelease.Select(Feed(),"1.0.0","win-x64")==null && UpdateRelease.Select(Feed(draft:true),"1.0.0","win-arm64")==null && UpdateRelease.Select(Feed(prerelease:true),"1.0.0","win-arm64")==null,"exclude wrong architecture, draft and prerelease");
        foreach(var digest in new[]{null,"sha256:abc","md5:"+new string('a',64),"sha256:"+new string('g',64)})Reject(()=>UpdateRelease.Select(Feed(digest:digest),"1.0.0","win-arm64"),"missing or invalid hash");
        foreach(var url in new[]{"http://github.com/file.zip","https://example.com/file.zip","https://github.com/other/repo/releases/download/v1.10.0/file.zip"})Reject(()=>UpdateRelease.Select(Feed(url:url),"1.0.0","win-arm64"),"untrusted URL");
        var now=DateTimeOffset.FromUnixTimeSeconds(1000);var journal=new UpdateJournal();journal.FinishCheck(now,true);Check(journal.NextCheck==now.AddHours(1),"one hour cadence");
        foreach(var seconds in new[]{300,900,3600,3600}){journal.FinishCheck(now,false);Check(journal.NextCheck==now.AddSeconds(seconds),"failure backoff");}
        Check(journal.Announce("1.0.0"),"first notification");journal=JsonSerializer.Deserialize<UpdateJournal>(JsonSerializer.Serialize(journal))!;
        Check(!journal.Announce("1.0.0") && journal.Announce("1.0.1"),"ignore/later survives restart and allows next version");
        var root=Path.Combine(Path.GetTempPath(),"ChirpOS-update-tests-"+Guid.NewGuid());Directory.CreateDirectory(root);
        try {
            var file=Path.Combine(root,"archive.zip");var bytes=Encoding.UTF8.GetBytes("hello");File.WriteAllBytes(file,bytes);
            var release=new UpdateRelease("1.0.0","","","",Convert.ToHexString(SHA256.HashData(bytes)),5);release.Verify(file);Check(true,"valid hash");
            File.WriteAllText(file,"jello");Reject(()=>release.Verify(file),"same-size corruption");File.WriteAllText(file,"hi");Reject(()=>release.Verify(file),"truncated download");
            void Zip(string name,int attributes=0){using var zip=ZipFile.Open(file,ZipArchiveMode.Create);var entry=zip.CreateEntry(name);entry.ExternalAttributes=attributes;using var output=entry.Open();output.WriteByte(1);}
            var extracted=Path.Combine(root,"extracted.exe");
            foreach(var name in new[]{"../evil","/ChirpOS.exe","folder/../ChirpOS.exe","folder\\evil","C:/ChirpOS.exe"}){File.Delete(file);Zip(name);Reject(()=>UpdateArchive.ExtractExecutable(file,extracted),"ZIP traversal "+name);}
            File.Delete(file);Zip("ChirpOS.exe",unchecked((int)(0xa1ffu<<16)));Reject(()=>UpdateArchive.ExtractExecutable(file,extracted),"ZIP symbolic link");
            File.Delete(file);Zip("ChirpOS.exe");UpdateArchive.ExtractExecutable(file,extracted);Check(File.ReadAllBytes(extracted).SequenceEqual(new byte[]{1}),"extract only expected executable");
            var pe=Path.Combine(root,"fixture-pe.exe");var header=new byte[128];header[0]=0x4d;header[1]=0x5a;header[0x3c]=64;header[64]=0x50;header[65]=0x45;header[68]=0x64;header[69]=0xaa;File.WriteAllBytes(pe,header);
            UpdateArchive.ValidatePE(pe,"win-arm64");Check(true,"matching PE architecture");Reject(()=>UpdateArchive.ValidatePE(pe,"win-x64"),"wrong PE architecture");
            var target=Path.Combine(root,"ChirpOS.exe");var source=Path.Combine(root,"new.exe");File.WriteAllText(target,"old");File.WriteAllText(source,"new");
            var replacement=new UpdateReplacement(target,Guid.NewGuid().ToString("D"));
            Reject(()=>replacement.Prepare(Path.Combine(root,"missing")),"prepare failure preserves current version");Check(File.ReadAllText(target)=="old","current still intact");
            replacement.Prepare(source);replacement.Replace();Check(File.ReadAllText(target)=="new" && File.ReadAllText(replacement.Backup)=="old","old executable retained until healthy");
            replacement.Rollback();Check(File.ReadAllText(target)=="old","failed startup rolls back");
            replacement.Prepare(source);replacement.Replace();replacement.Complete();Check(File.ReadAllText(target)=="new" && !File.Exists(replacement.Backup) && !File.Exists(replacement.Candidate),"healthy startup cleanup");
            Reject(()=>new UpdateReplacement(target,"../evil"),"untrusted transaction identifier");
        } finally {Directory.Delete(root,true);}
        return count;
    }
}
