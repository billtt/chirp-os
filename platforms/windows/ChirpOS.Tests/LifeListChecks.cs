using ChirpOS.Core;
internal static class LifeListChecks {
    internal static void Run(Action<bool,string> check) {
        foreach(var scale in new[]{.5,1,2,4,6})foreach(var top in new[]{-900d,0,300}) {
            var bird=new Box(400,top,100,100);var screen=new Box(0,0,1000,700);
            var normal=BirdFeedbackLayout.Label(bird,screen,220,27);
            var raised=BirdFeedbackLayout.Label(bird,screen,220,27,ObservationHearts.LabelClearance(scale));
            check(raised.X==normal.X && raised.Bottom<normal.Y,"heart label jumps vertically above its original position");
            var clear=true;
            for(var tick=0;tick<=38;tick++)for(var i=0;i<ObservationHearts.Count;i++) {
                var p=ObservationHearts.Particle(i,tick/100d);
                var gap=top-ObservationHearts.Clearance(scale)-p.Y-p.Size-raised.Bottom;
                clear &= gap>=8;
                if(i==1 && tick==24)clear &= gap<=12;
            }
            check(clear,"raised label sits just above the initial heart pop, including screen edges");
        }
        foreach(var origin in new[]{new V(0,0),new V(-1200,-900)}) {
            var screen=new Box(origin.X,origin.Y,1000,700);
            foreach(var r in new[]{new Box(400,300,100,100),new Box(400,5,100,100),new Box(5,5,100,100),new Box(895,5,100,100),new Box(10,0,980,100)}) {
                var bird=new Box(r.X+origin.X,r.Y+origin.Y,r.W,r.H);
                var placement=BirdFeedbackLayout.Label(bird,screen,220,25);
                check(!placement.Intersects(bird) && placement.X>=screen.X && placement.Right<=screen.Right,"labels stay horizontally within the screen without covering birds");
                check(placement.Bottom==bird.Y-8,"labels always stay above edge birds");
                var lower=BirdFeedbackLayout.Label(bird with{Y=bird.Y+300},screen,220,25);
                check(placement.X==lower.X,"labels do not jump sideways near screen top");
            }
        }
        var crowdedBird=new Box(0,0,100,100);
        check(!BirdFeedbackLayout.Label(crowdedBird,crowdedBird,100,25).Intersects(crowdedBird),"crowded screen clips label instead of covering bird");
        check(ObservationHearts.Count==3,"exactly three hearts");
        for(var i=0;i<ObservationHearts.Count;i++) {
            var pop=ObservationHearts.Particle(i,.15);var hold=ObservationHearts.Particle(i,.35);var floating=ObservationHearts.Particle(i,.9);
            check(pop.X==hold.X && pop.Y==hold.Y && pop.Size>0 && hold.Opacity==1,"hearts pop and settle in place");
            check(floating.Y>hold.Y && floating.Opacity<hold.Opacity,"hearts then float and fade");
            check(ObservationHearts.Particle(i,ObservationHearts.Duration).Opacity==0,"hearts disappear at end");
        }
        check(ObservationHearts.Clearance(4)>ObservationHearts.Clearance(1),"large birds receive more head clearance");
        var sortRecords=new Dictionary<string,LifeRecord>{
            ["a"]=new(3,DateTimeOffset.FromUnixTimeSeconds(10)),
            ["b"]=new(1,DateTimeOffset.FromUnixTimeSeconds(30)),
            ["c"]=new(3,DateTimeOffset.FromUnixTimeSeconds(20)),
            ["d"]=new(2,DateTimeOffset.FromUnixTimeSeconds(20))};
        string[] ids=["z","c","b","y","a","d"];
        string Ordered(LifeListSort sort,bool ascending)=>string.Join(",",ids.OrderBy(id=>id,Comparer<string>.Create((a,b)=>LifeListOrdering.Compare(a,b,sortRecords,sort,ascending))));
        check(Ordered(LifeListSort.FirstRecordedAt,true)=="a,c,d,b,y,z","oldest first keeps unrecorded last and breaks ties by ID");
        check(Ordered(LifeListSort.FirstRecordedAt,false)=="b,c,d,a,y,z","newest first keeps unrecorded last");
        check(Ordered(LifeListSort.Count,true)=="b,d,a,c,y,z","fewest first keeps unrecorded last");
        check(Ordered(LifeListSort.Count,false)=="a,c,d,b,y,z","most first keeps unrecorded last and breaks ties by ID");
        foreach(var sort in Enum.GetValues<LifeListSort>())foreach(var ascending in new[]{true,false}) {
            check(LifeListOrdering.Compare("a","a",sortRecords,sort,ascending)==0,"same species compares equal");
            check(ids.OrderBy(id=>id,Comparer<string>.Create((a,b)=>LifeListOrdering.Compare(a,b,new Dictionary<string,LifeRecord>(),sort,ascending))).SequenceEqual(ids.Order(StringComparer.Ordinal)),"empty Life List has stable order");
        }
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
        var interaction=new ObservationInteraction<int>();
        check(interaction.Click(1,0)==(true,false),"first click shows label without hearts");
        check(interaction.Click(1,.2)==(false,true),"second rapid click triggers hearts and preserves existing label");
        check(interaction.Click(1,.4)==(false,false),"third click does not restart hearts");
        foreach(var time in new[]{.5,.6,.7,.8})check(interaction.Click(1,time)==(false,false),"rapid clicks do not restart either animation");
        check(interaction.Click(1,1.21).Label,"label can reappear after expiry");
        interaction.Reset();interaction.Click(1,0);
        check(interaction.Click(2,.1).Label && !interaction.Click(1,.2).Label,"feedback is independent per bird");
        check(!interaction.Click(1,1.5).Hearts && !interaction.Click(1,3).Hearts,"slow clicks do not trigger hearts");
        interaction.Retain([2]);check(interaction.Click(1,3.1)==(true,false),"departed birds release click history");
        interaction.Reset();check(interaction.Click(1,3.2)==(true,false),"mode switch clears click history");
        foreach(var scale in new[]{.5,1,2,4}) {
            bool Hit(double x,double y)=>SpriteHitTest.Contains(x,y,5/scale,(px,py)=>px==0 && py==10);
            check(Hit(-4.9/scale,10.5) && !Hit(-5.1/scale,10.5),"padding stays five screen pixels across sizes");
            check(!Hit(-4/scale,10-4/scale),"diagonal padding uses circular distance");
        }
        check(SpriteHitTest.Contains(.5,10.5,0,(x,y)=>x==0 && y==10) && !SpriteHitTest.Contains(-.1,10.5,0,(x,y)=>x==0 && y==10),"zero padding preserves silhouette");
        check(!SpriteHitTest.Contains(0,10,5,(x,y)=>false),"transparent or blocked pixels do not hit");
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
