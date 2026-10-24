using ChirpOS.Core;
internal static class LifeListChecks {
    internal static void Run(Action<bool,string> check) {
        var fresh=new LifeList();
        check(fresh.PrepareIntroduction() && fresh.Enabled,"new installs start in birdwatching mode");
        var list=new LifeList();var first=DateTimeOffset.FromUnixTimeSeconds(1000);
        check(list.Record("treeSparrow",first),"first observation adds species");
        check(!list.Record("treeSparrow",first.AddHours(1)) && list.Records["treeSparrow"]==new LifeRecord(2,first),"repeat visit increments without changing first date");
        var next=list.Copy();next.Enabled=true;next.Record("nightHeron");
        check(!list.Enabled && list.Records.Count==1,"save candidate cannot mutate committed observations");
        var visits=new ObservationVisits<int>();visits.Arrive(1);visits.Commit(1);visits.Retain([1,2]);
        check(visits.WasRecorded(1) && !visits.Contains(2),"moving birds remain one visit; unknown birds ineligible");
        visits.Reset();visits.Commit(1);visits.Arrive(2);
        check(!visits.Contains(1) && !visits.WasRecorded(1) && !visits.WasRecorded(2),"mode transition excludes old birds");
        var dir=Path.Combine(Path.GetTempPath(),Guid.NewGuid().ToString());var path=Path.Combine(dir,"life-list.json");
        try {
            next.Save(path);var restored=LifeList.Load(path);
            check(restored.Enabled && restored.Records["treeSparrow"]==new LifeRecord(2,first),"Life List persistence round trip");
            // Simulate an old installation with observations but no introduction marker.
            restored.Enabled=false;restored.Save(path);
            var upgraded=LifeList.Load(path);
            check(upgraded.PrepareIntroduction() && upgraded.Enabled && upgraded.Records["treeSparrow"].Count==2,"upgrade enables mode without losing records");
            var optedOut=upgraded.Copy();optedOut.Enabled=false;optedOut.Save(path);
            var restarted=LifeList.Load(path);
            check(!restarted.PrepareIntroduction() && !restarted.Enabled,"subsequent launches preserve opt-out and do not repeat intro");
            File.WriteAllText(path,"broken");var rejected=false;try{LifeList.Load(path);}catch{rejected=true;}
            check(rejected && File.ReadAllText(path)=="broken","damaged Life List preserved");
        } finally {Directory.Delete(dir,true);}
    }
}
