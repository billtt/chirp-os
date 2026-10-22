using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
namespace ChirpOS.Core;

public sealed record UpdateVersion(int Major,int Minor,int Patch):IComparable<UpdateVersion> {
    public static UpdateVersion? Parse(string text) {
        var match=Regex.Match(text,@"^v?([0-9]{1,6})\.([0-9]{1,6})\.([0-9]{1,6})\z",RegexOptions.CultureInvariant);
        return match.Success?new(int.Parse(match.Groups[1].Value),int.Parse(match.Groups[2].Value),int.Parse(match.Groups[3].Value)):null;
    }
    public int CompareTo(UpdateVersion? other) {if(other is null)return 1;var a=Major.CompareTo(other.Major);if(a!=0)return a;a=Minor.CompareTo(other.Minor);return a!=0?a:Patch.CompareTo(other.Patch);}
    public override string ToString()=>$"{Major}.{Minor}.{Patch}";
}
public sealed record UpdateRelease(string Version,string Notes,string AssetName,string DownloadURL,string SHA256,long Size) {
    public const string Endpoint="https://api.github.com/repos/billtt/chirp-os/releases/latest";
    public const long MaxDownload=512*1024*1024;
    public static UpdateRelease? Select(byte[] data,string current,string platform) {
        if(data.Length>2_000_000 || UpdateVersion.Parse(current) is not {} installed)throw new InvalidDataException("Invalid update metadata");
        using var doc=JsonDocument.Parse(data);var r=doc.RootElement;var tag=r.GetProperty("tag_name").GetString()!;
        if(r.GetProperty("draft").GetBoolean() || r.GetProperty("prerelease").GetBoolean() || UpdateVersion.Parse(tag) is not {} version || version.CompareTo(installed)<=0)return null;
        var name=$"ChirpOS-{version}-{platform}.zip";
        var matches=r.GetProperty("assets").EnumerateArray().Where(a=>a.GetProperty("name").GetString()==name && a.GetProperty("state").GetString()=="uploaded").ToArray();
        if(matches.Length!=1)return null;
        var asset=matches[0];var url=$"https://github.com/billtt/chirp-os/releases/download/{tag}/{name}";var size=asset.GetProperty("size").GetInt64();
        var digest=asset.TryGetProperty("digest",out var d)?d.GetString():null;
        if(asset.GetProperty("browser_download_url").GetString()!=url || size<=0 || size>MaxDownload || digest is null || !Regex.IsMatch(digest,@"^sha256:[a-fA-F0-9]{64}\z"))throw new InvalidDataException("Update package has no valid SHA-256 digest or download URL");
        var notes=r.TryGetProperty("body",out var body)?body.GetString()??"":"";
        return new(version.ToString(),notes[..Math.Min(notes.Length,20000)],name,url,digest[7..].ToLowerInvariant(),size);
    }
    public void Verify(string path) {
        if(new FileInfo(path).Length!=Size)throw new InvalidDataException("Update package size mismatch");
        using var stream=File.OpenRead(path);
        if(!Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(stream)).Equals(SHA256,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Update package checksum mismatch");
    }
}
public sealed class UpdateJournal {
    public DateTimeOffset NextCheck {get;set;}=DateTimeOffset.MinValue;
    public HashSet<string> Announced {get;set;}=[];
    public int Failures {get;set;}
    public void FinishCheck(DateTimeOffset now,bool success){Failures=success?0:Math.Min(3,Failures+1);NextCheck=now.AddSeconds(success?3600:new[]{300,900,3600}[Failures-1]);}
    public bool Announce(string version)=>Announced.Add(version);
}
public static class UpdateArchive {
    public static void ExtractExecutable(string zip,string destination) {
        using var archive=ZipFile.OpenRead(zip);long total=0;var names=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if(archive.Entries.Count==0 || archive.Entries.Count>10000)throw new InvalidDataException("Invalid update archive");
        foreach(var e in archive.Entries) {
            var name=e.FullName;
            if(name.Contains('\\') || name.Contains(':') || name.Contains('\0') || name.StartsWith('/') || name.Split('/').Any(s=>s is "." or "..") || !names.Add(name) || ((e.ExternalAttributes>>16)&0xf000)==0xa000)throw new InvalidDataException("Unsafe update archive path");
            total=checked(total+e.Length);if(total>1024L*1024*1024)throw new InvalidDataException("Update archive exceeds size limit");
        }
        var exe=archive.GetEntry("ChirpOS.exe") ?? throw new InvalidDataException("Update archive has no ChirpOS.exe");
        if(exe.Length<=0 || exe.Length>UpdateRelease.MaxDownload)throw new InvalidDataException("Invalid update executable size");
        if(new DriveInfo(Path.GetPathRoot(Path.GetFullPath(destination))!).AvailableFreeSpace<exe.Length*2+50_000_000)throw new IOException("Not enough free space to unpack this update");
        using var input=exe.Open();using var output=new FileStream(destination,FileMode.CreateNew,FileAccess.Write,FileShare.None);
        var buffer=new byte[1024*1024];long written=0;int n;
        while((n=input.Read(buffer))>0){written+=n;if(written>exe.Length)throw new InvalidDataException("Update executable exceeds declared size");output.Write(buffer,0,n);}
        if(written!=exe.Length)throw new InvalidDataException("Incomplete update executable");
    }
    public static void ValidatePE(string file,string architecture) {
        using var reader=new BinaryReader(File.OpenRead(file));
        if(reader.ReadUInt16()!=0x5a4d)throw new InvalidDataException("Not a Windows executable");
        reader.BaseStream.Position=0x3c;var offset=reader.ReadUInt32();
        if(offset>reader.BaseStream.Length-6)throw new InvalidDataException("Invalid PE header");
        reader.BaseStream.Position=offset;
        if(reader.ReadUInt32()!=0x00004550 || reader.ReadUInt16()!=(architecture=="win-arm64"?0xaa64:0x8664))throw new InvalidDataException("Update CPU architecture mismatch");
    }
}
public sealed class UpdateReplacement {
    public string Target {get;} public string Candidate {get;} public string Backup {get;}
    public UpdateReplacement(string target,string token) {
        if(!Guid.TryParseExact(token,"D",out _) || !Path.IsPathFullyQualified(target) || Path.GetFileName(target)!="ChirpOS.exe" || Path.GetFullPath(target)!=target)throw new InvalidDataException("Invalid update destination");
        if(File.Exists(target) && File.GetAttributes(target).HasFlag(FileAttributes.ReparsePoint))throw new InvalidDataException("Update destination is a link");
        Target=target;var folder=Path.GetDirectoryName(target)!;Candidate=Path.Combine(folder,$".ChirpOS-{token}.new.exe");Backup=Path.Combine(folder,$".ChirpOS-{token}.old.exe");
    }
    public void Prepare(string source) {if(File.Exists(Candidate) || File.Exists(Backup))throw new IOException("An update transaction already exists");try{File.Copy(source,Candidate,false);}catch{File.Delete(Candidate);throw;}}
    public void Replace() {File.Replace(Candidate,Target,Backup);}
    public void Rollback() {if(File.Exists(Backup)){if(File.Exists(Target))File.Replace(Backup,Target,null);else File.Move(Backup,Target);}}
    public void Complete() {File.Delete(Backup);File.Delete(Candidate);}
}
