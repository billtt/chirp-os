using System.Text.Json;
namespace ChirpOS.Core;

public sealed record LifeRecord(int Count, DateTimeOffset FirstRecordedAt);
public sealed class LifeList {
    public bool Enabled { get; set; }
    public int? IntroductionVersion { get; set; }
    public bool PrepareIntroduction() {
        if((IntroductionVersion??0)>=1)return false;
        Enabled=true;IntroductionVersion=1;return true;
    }
    public Dictionary<string, LifeRecord> Records { get; set; } = [];
    static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy=JsonNamingPolicy.CamelCase, WriteIndented=true };
    public LifeList Copy() => new() { Enabled=Enabled, IntroductionVersion=IntroductionVersion, Records=new(Records) };
    public bool Record(string species, DateTimeOffset? at=null) {
        if(Records.TryGetValue(species,out var previous)) { Records[species]=previous with { Count=checked(previous.Count+1) };return false; }
        Records[species]=new(1,at??DateTimeOffset.UtcNow);return true;
    }
    public static LifeList Load(string path) {
        if(!File.Exists(path))return new();
        var value=JsonSerializer.Deserialize<LifeList>(File.ReadAllText(path),Json) ?? throw new InvalidDataException("Invalid Life List");
        if(value.Records is null || value.Records.Values.Any(r=>r is null || r.Count<=0))throw new InvalidDataException("Invalid observation counts");
        return value;
    }
    public void Save(string path) {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary=path+".tmp";
        File.WriteAllText(temporary,JsonSerializer.Serialize(this,Json));File.Move(temporary,path,true);
    }
}
public sealed class ObservationVisits<T> where T:notnull {
    readonly HashSet<T> eligible=[], recorded=[];
    public void Reset(){eligible.Clear();recorded.Clear();}
    public void Arrive(T visit)=>eligible.Add(visit);
    public bool Contains(T visit)=>eligible.Contains(visit);
    public bool WasRecorded(T visit)=>recorded.Contains(visit);
    public void Commit(T visit){if(eligible.Contains(visit))recorded.Add(visit);}
    public void Retain(IEnumerable<T> visits){var live=visits.ToHashSet();eligible.IntersectWith(live);recorded.IntersectWith(live);}
}
