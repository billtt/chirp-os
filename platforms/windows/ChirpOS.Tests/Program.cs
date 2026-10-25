using ChirpOS.Core;
var count = 0;
void Check(bool condition, string name) { if (!condition) throw new Exception(name); count++; Console.WriteLine("PASS " + name); }
LifeListChecks.Run(Check);
// Regression: the same four columns must fit the viewport at every Windows DPI,
// including odd pixel widths, a vertical scrollbar, and the 1.5× bird setting.
foreach(var dpi in new[]{1d,1.25,1.5,2,2.5})
foreach(var logicalWidth in new[]{880,900,1100})
foreach(var globalScale in new[]{1d,1.5}) {
    var viewport=(int)(logicalWidth*dpi)-17;
    var layout=GalleryLayout.Calculate(viewport,100,dpi,2.5*globalScale);
    var cells=Enumerable.Range(0,100).Select(layout.Cell).ToArray();
    Check(cells.Take(4).All(c=>c.Y==0) && cells[4].Y==layout.CellHeight,
        $"gallery keeps four columns at {dpi} DPI, {logicalWidth}px, {globalScale}x");
    Check(cells.Take(4).Sum(c=>c.Width)==viewport && cells.All(c=>c.X+c.Width<=viewport && c.Y+c.Height<=layout.Height),
        "gallery fills viewport without horizontal overflow or clipped rows");
    Check(48*layout.MaxScale+32*dpi<=cells.Min(c=>c.Width)+1,
        "largest bird fits the cell at both global sizes");
}
var s = new Species("redWhiskeredBulbul", "红耳鹎", 19, 1, 20, 1, 14, 28);
Check(s.Scale==1 && Math.Abs((s with{AdultLengthCM=94}).Scale-2.5)<1e-9,"compressed size anchors bulbul at 1 and heron at 2.5");
var generalPrefs=new Preferences {Minimum=3,Maximum=12,Scale=1.37,Probability=Probabilities.From([s])};
generalPrefs.NormalizeGeneralSettings();
Check(generalPrefs.Minimum==12 && generalPrefs.Maximum==12 && generalPrefs.Valid(1),"legacy range migrates to its upper target and fractional size is valid");
generalPrefs.Maximum=50;generalPrefs.Scale=2;generalPrefs.NormalizeGeneralSettings();
Check(generalPrefs.Minimum==20 && generalPrefs.Maximum==20 && generalPrefs.Valid(1),"population clamps to 20 and 2x size is valid");
generalPrefs.Maximum=1;generalPrefs.NormalizeGeneralSettings();
Check(generalPrefs.Minimum==5 && generalPrefs.Maximum==5,"population lower limit is 5");
generalPrefs.Scale=double.NaN;Check(!generalPrefs.Valid(1),"non-finite size is rejected");
var rng = new Random(42); var profiles = Enumerable.Range(0, 7).Select(i => s with { Weight = i + 1 }).ToArray(); var p = Probabilities.From(profiles);
for (var step = 0; step < 10000; step++)
{
    var i = rng.Next(7); if (step % 3 == 0) p.Locked[i] = !p.Locked[i]; var before = (int[])p.Points.Clone(); p.Adjust(i, rng.Next(-10000, 20000));
    if (!p.Valid(7)) throw new Exception("Invalid total"); for (var j = 0; j < 7; j++) if (p.Locked[j] && before[j] != p.Points[j]) throw new Exception("Lock changed");
}
Check(true, "10,000 probability edits preserve 100% and locks");
p = new() { Points = [10000, 0, 0], Locked = [false, false, false] }; p.Adjust(0, 0); Check(p.Points.SequenceEqual(new[] { 0, 5000, 5000 }), "zero peers split equally");
p.Locked = [true, true, false]; var old = (int[])p.Points.Clone(); p.Adjust(2, 4000); Check(p.Points.SequenceEqual(old), "single unlocked item cannot change");
var a = new Surface(1, new(100, 400, 500, 300)); var b = new Surface(2, new(200, 250, 500, 300)); var c = new Surface(3, new(300, 100, 500, 300)); var surfaces = new[] { a, b, c };
var bird = new Bird(s, new(350, 400), rng); bird.Perch(a); bird.Fly(new(450, 100), c, 3);
Check(bird.Depth == null && !bird.Blockers(surfaces).Any(), "A to C flight stays above B");
bird.Tick(.75); Check(bird.State == BirdState.Flying && bird.Depth == null, "flight depth remains clear"); bird.Tick(bird.FlightDuration-.75); Check(bird.State == BirdState.Landing && bird.Depth == 3, "depth switches only on arrival");
Check(!Geometry.Visible(3, new(350, 400), surfaces, 1), "occluded landing rejected");
Check(Geometry.Visible(3, new(450, 100), surfaces, 1), "exposed landing accepted");
bird.Perch(a); bird.UpdateHost(new[] { a with { Rect = new(102, 400, 500, 300) } }, .033, 1); Check(bird.State == BirdState.Perched && bird.Followed == 2, "slow drag follows"); bird.UpdateHost(new[] { a with { Rect = new(282, 400, 500, 300) } }, .033, 1); Check(bird.State == BirdState.Flying && bird.Startles == 1, "fast drag startles");
bird.Perch(a); bird.UpdateHost([], .033, 1); Check(bird.State == BirdState.Flying && bird.Host == null, "closed host releases bird");
bird.Perch(a); bird.Fly(new(450, 100), c); var pos = bird.Position; bird.UpdateHost(new[] { new Surface(4, new(300, 50, 400, 100)), c }, .033, 1); bird.Tick(1); Check(bird.NeedsDestination && bird.Position == pos, "covered destination reroutes without teleport");
bird.Fly(new(-500, 100), null, 1, 30, true); bird.Tick(2); Check(bird.DepartureFinished && !bird.NeedsDestination, "departing bird does not seek a perch");
Check(Geometry.Foot(new(8, new(-1920, -1080, 500, 300)), .5) == new V(-1670, -1080), "negative monitor coordinates");
// Regression: a transparent drag surface must never become a full-screen occluder.
Check(!WindowPolicy.Occludes("DragHelper",0,0x80020),"transparent drag overlay excluded");
Check(!WindowPolicy.Occludes("DragHelper",0,0x8080080),"per-pixel nonactivating helper excluded");
Check(!WindowPolicy.Occludes("DragHelper",0,0x8200080),"composition drag helper excluded");
Check(!WindowPolicy.Occludes("Application",0xC00000,0x80000,0),"zero-opacity window excluded");
Check(WindowPolicy.Occludes("Application",0xC00000,0x80000,255),"opaque layered application still occludes");
Check(WindowPolicy.Occludes("Application",0,0),"borderless application still occludes");
Check(WindowPolicy.Occludes("#32768",0,0x88),"visible topmost menu still occludes");
var drag=new Surface(90,new(0,0,1920,1080));
var sampled=new[]{drag,a,b,c}.Where(w=>w.Id!=90 || WindowPolicy.Occludes("DragHelper",0,0x80020)).ToArray();
bird.Perch(a);var other=new Bird(s,new(400,250),rng);other.Perch(b);
Check(!bird.Blockers(sampled).Any() && other.Blockers(sampled).SequenceEqual(new[]{a.Rect}),"drag helper does not hide birds on either host");
Check(!Geometry.Visible(b.Id,new(350,450),sampled,1),"real foreground windows retain occlusion after filtering");
var pref=new Preferences{Probability=Probabilities.From(profiles)};
var json=System.Text.Json.JsonSerializer.Serialize(pref);
var legacy=System.Text.Json.JsonSerializer.Deserialize<Preferences>(json.Replace(",\"Behaviors\":{}",""))!;
Check(legacy.Valid(7) && legacy.Resolve(s)==s,"legacy settings load default behavior");
var behavior=new Behavior(28,32,1.5,6,9);pref.Behaviors[s.Id]=behavior;
var restored=System.Text.Json.JsonSerializer.Deserialize<Preferences>(System.Text.Json.JsonSerializer.Serialize(pref))!;
Check(restored.Valid(7) && restored.Resolve(s).AdultLengthCM==28 && restored.Resolve(s).FlapFPS==32 && restored.Resolve(s).Speed==1.5 && restored.Resolve(s).PerchMin==6 && restored.Resolve(s).PerchMax==9,"behavior values survive save and reload");
var configured=new Bird(restored.Resolve(s),new(0,0),new Random(1));configured.Fly(new(100,0),a,3);configured.Tick(configured.FlightDuration);
Check(configured.State==BirdState.Landing && Math.Abs(configured.Species.Scale-Math.Pow(28.0/19,Math.Log(2.5)/Math.Log(94d/19)))<1e-9 && configured.PerchDuration>=6 && configured.PerchDuration<=9,"new arrivals use configured size speed and duration");
Check(!(behavior with{PerchMin=20,PerchMax=10}).Valid && !(behavior with{FlapFPS=61}).Valid && !(behavior with{AdultLengthCM=double.NaN}).Valid,"invalid behavior rejected");
var draft=System.Text.Json.JsonSerializer.Deserialize<Preferences>(System.Text.Json.JsonSerializer.Serialize(pref))!;draft.Behaviors[s.Id]=behavior with{Speed=.5};
Check(pref.Resolve(s).Speed==1.5,"unsaved behavior edits do not mutate active settings");
var edge=new Surface(100,new(0,300,1000,400));var desktop=new Box(0,0,1200,900);
foreach(var cover in new[]{new Box(0,100,620,300),new Box(380,100,620,300)}){
    var scene=new[]{new Surface(101,cover),edge};var ranges=Geometry.LandingRanges(edge,scene,desktop,1,[]);
    Check(ranges.Count==1 && ranges[0].Hi-ranges[0].Lo>250,"partly covered edge offers continuous space");
    Check(Enumerable.Range(1,99).All(i=>Geometry.Visible(edge.Id,new(ranges[0].Lo+(ranges[0].Hi-ranges[0].Lo)*i/100,300),scene,1)),"continuous samples remain unoccluded");
}
var reserved=Geometry.Landing(new(500,300),1.6);reserved=new(reserved.X-8,reserved.Y-8,reserved.W+16,reserved.H+16);
var free=Geometry.LandingRanges(edge,new[]{edge},desktop,1,new[]{reserved});
Check(free.Count==2 && free.All(r=>r.Hi<500 || r.Lo>500) && free.All(r=>!Geometry.Landing(new((r.Lo+r.Hi)/2,300),1).Intersects(reserved)),"standing and inbound reservations avoid overlap");
Check(Geometry.LandingRanges(edge,new[]{edge},desktop,1,new[]{new Box(0,200,1000,500)}).Count==0,"full edge has no remaining destination");
var clipped=new Surface(102,new(-1000,300,1500,400));var clippedRanges=Geometry.LandingRanges(clipped,new[]{clipped},desktop,1,[]);
Check(clippedRanges.Count==1 && clippedRanges[0].Lo==29 && clippedRanges[0].Hi==458,"offscreen host retains exposed landing edge");

var hover=new HoverTracker<object>();var one=new object();var two=new object();
Check(hover.Update(one,10)==null && hover.Update(one,10.99)==null && hover.Update(one,11)==one,"hover waits 1 second");
Check(hover.Update(two,13.1)==null && hover.Update(null,14)==null && hover.Update(two,17)==null && hover.Update(two,20)==two,"hover resets on identity change and exit");
Check(SpeciesBehavior.Frame("nightHeron",12)=="stand" && SpeciesBehavior.Frame("nightHeron",21)=="stretch" && SpeciesBehavior.Frame("nightHeron",31.4)!.StartsWith("poop") && SpeciesBehavior.Frame("nightHeron",33)=="stand","night heron quiet watch and spaced actions");
var sideHost=new Surface(201,new(300,100,500,600));
var woodpecker=new Bird(s with {Id="greatSpottedWoodpecker"},new(0,0),rng){Edge=PerchEdge.Right,Fraction=.5};woodpecker.Perch(sideHost);
Check(woodpecker.Position==new V(800,400) && !woodpecker.Right,"side perch faces window");
woodpecker.UpdateHost(new[]{sideHost with{Rect=new(300,100,530,600)}},.033,1);woodpecker.Tick(4.2);
Check(woodpecker.Position.X==830 && woodpecker.Frame.StartsWith("peck"),"side perch tracks resize and pecks");
var sideCover=new Surface(202,new(250,200,100,180));
var sideRanges=Geometry.SideRanges(sideHost,PerchEdge.Left,new[]{sideCover,sideHost},new(0,0,1200,900),1,[]);
Check(sideRanges.Count>0 && sideRanges.All(q=>!Geometry.Landing(new(300,(q.Lo+q.Hi)/2),1).Intersects(sideCover.Rect)),"side landing avoids occlusion");
var oldIds=new[]{"redWhiskeredBulbul","treeSparrow","lightVentedBulbul","spottedDove","chineseBlackbird","magpieRobin","longTailedShrike"};
var migrationSpecies=oldIds.Append("nightHeron").Select(id=>s with{Id=id}).ToArray();
var oldPrefs=new Preferences{Probability=new(){Points=[10000,0,0,0,0,0,0],Locked=[true,false,false,false,false,false,false]}};
Check(oldPrefs.Migrate(migrationSpecies) && oldPrefs.Probability.Points[0]==10000 && oldPrefs.Probability.Locked[0] && oldPrefs.Probability.Points[7]==0,"old preferences preserve exact probabilities and locks");
Check(oldPrefs.Migrate(migrationSpecies.Reverse().ToArray()) && oldPrefs.Probability.Points[7]==10000,"saved species IDs survive catalog reorder");
oldPrefs.AllocateNewSpecies(migrationSpecies.Reverse().ToArray());
Check(oldPrefs.Probability.Points[0]==1250 && oldPrefs.Probability.Points[7]==8750 && oldPrefs.Probability.Locked[7],"new species share by count scales locked values but keeps locks");
var roundtrip=System.Text.Json.JsonSerializer.Deserialize<Preferences>(System.Text.Json.JsonSerializer.Serialize(oldPrefs))!;
Check(roundtrip.Migrate(migrationSpecies.Reverse().ToArray()) && roundtrip.PendingSpeciesIds!.SequenceEqual(new[]{"nightHeron"}),"unresolved new species remain pending across restarts");
var galleryFrames=Enumerable.Range(0,300).Select(i=>GalleryPose.Frame("nightHeron",i/30d,20,GalleryAction.Other)).ToHashSet();
Check(new[]{"stretch","shake","poop0","poop1"}.All(galleryFrames.Contains) && !galleryFrames.Any(f=>f.StartsWith("fly")),"gallery stays on selected special actions");
Check(Enumerable.Range(0,300).All(i=>GalleryPose.Frame("blackKite",i/30d,20,GalleryAction.Other)==GalleryPose.Frame("blackKite",i/30d,20,GalleryAction.Resting)),"other rests birds without special actions");

var catalog = System.Text.Json.JsonSerializer.Deserialize<Catalog>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "species.json")), new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
foreach (var species in catalog.Species) {
    var motion = SpeciesBehavior.Profile(species.Id);
    Check(motion.Start > 0 && motion.Start + motion.Duration < motion.Cycle - 1.6, species.Id + " has a separated activity window");
    var poses = Enumerable.Range(0, (int)(motion.Cycle * 60)).Select(i => SpeciesBehavior.Frame(species.Id, i / 60d)).ToHashSet();
    Check(poses.Contains("stand"), species.Id + " returns to rest");
    if (species.Id != "nightHeron") Check(new[] { "idle0", "idle1", "idle2", "blink", "preen0", "preen1" }.All(poses.Contains), species.Id + " reaches every action keyframe");
    Check(Math.Abs(SpeciesBehavior.Hop(species.Id, motion.Start)) < 1e-6 && Math.Abs(SpeciesBehavior.Hop(species.Id, motion.Start + motion.Duration)) < 1e-6, species.Id + " hop meets perch at both ends");
}

var newIds = catalog.Species.Skip(46).Select(b => b.Id).ToArray();
var previousSpecies = catalog.Species.Take(46).ToArray();
var previousProbabilities = Probabilities.From(previousSpecies);
previousProbabilities.Locked[0] = true;
var oldPoints = previousProbabilities.Points.ToArray();
var expandedPrefs = new Preferences { SpeciesIds = previousSpecies.Select(b => b.Id).ToArray(), Probability = previousProbabilities, PendingSpeciesIds = [] };
Check(previousSpecies.Length == 46 && catalog.Species.Length == 100, "54 birds extend the existing 46 species");
Check(expandedPrefs.Migrate(catalog.Species) && expandedPrefs.PendingSpeciesIds!.ToHashSet().SetEquals(newIds), "only new species become pending");
Check(expandedPrefs.Probability.Points.Take(46).SequenceEqual(oldPoints) && expandedPrefs.Probability.Locked[0] && expandedPrefs.Probability.Points.Skip(46).All(n => n == 0), "migration preserves old probabilities and locks");
expandedPrefs.AllocateNewSpecies(catalog.Species);
Check(expandedPrefs.Probability.Points.Skip(46).Sum() == 5400 && expandedPrefs.Probability.Valid(100), "54 birds receive their proportional allocation");

foreach(var species in catalog.Species) {
    var flightBird=new Bird(species,new(200,420),rng);var target=new V(700,500);var flightHost=new Surface(701,new(100,500,900,300));var airspace=new Box(80,120,1000,650);
    flightBird.Fly(target,flightHost,airspace:airspace);
    var poses=new HashSet<string>();var extended=0;var powered=0;double circleSeconds=0;var flips=0;var right=flightBird.Right;var previous=flightBird.Position;var speeds=new List<double>();var wasCircling=false;
    for(var step=0;step<=(int)Math.Ceiling(flightBird.FlightDuration*60);step++) {
        flightBird.Tick(1d/60);poses.Add(flightBird.Frame);
        if(wasCircling && flightBird.IsCircling)speeds.Add(V.Distance(previous,flightBird.Position)*60);wasCircling=flightBird.IsCircling;
        if(V.Distance(previous,flightBird.Position)>=12)throw new Exception(species.Id+" discontinuous flight");previous=flightBird.Position;
        if(flightBird.IsCircling){circleSeconds+=1d/60;if(flightBird.Frame.StartsWith("fly"))powered++;else extended++;if(right!=flightBird.Right){flips++;right=flightBird.Right;}
            if(!airspace.Contains(new(flightBird.Position.X,flightBird.Position.Y,0,0)) || flightBird.Depth!=null)throw new Exception("orbit left screen or adopted depth");}
    }
    Check(flightBird.State==BirdState.Landing && V.Distance(flightBird.Position,target)<.001,species.Id+" lands after full route");
    var motion=FlightBehavior.Profile(species.Id);
    if(motion.Orbit>0){Check(speeds.Min()>100 && speeds.Max()/speeds.Min()<1.05 && Math.Abs(speeds.Min()/FlightBehavior.CruiseSpeed(species.Id,species.Speed)-1)<.01 && Math.Abs(speeds.Max()/FlightBehavior.CruiseSpeed(species.Id,species.Speed)-1)<.01,species.Id+" circles without slowing at turns");}
    if(motion.Orbit>0)Check(circleSeconds>15 && extended>powered && powered>0 && flips>=3,species.Id+" prolonged circling mixes glides and wingbeats");
    if(!FlightBehavior.CanGlide(species.Id))Check(!poses.Any(x=>x.StartsWith("glide") || x.StartsWith("bank") || x=="bound"),species.Id+" flies with wingbeats only");
    if(motion.Orbit==0){
        var shortBird=new Bird(species,new(200,420),rng);var longBird=new Bird(species,new(200,420),rng);
        shortBird.Fly(new(320,420),null,height:20);longBird.Fly(new(1000,420),null,height:20);
        shortBird.Tick(shortBird.FlightDuration*.4);var shortPrevious=shortBird.Position;shortBird.Tick(.05);
        Check(shortBird.FlightDuration<2.1 && longBird.FlightDuration>shortBird.FlightDuration*2 && V.Distance(shortPrevious,shortBird.Position)/.05>80,species.Id+" short flight keeps cruise speed");
    }
    flightBird.Flee();Check(flightBird.FlightDuration<1.5 && !flightBird.IsCircling,species.Id+" escape bypasses circling");
}
var oldRates=new Preferences{SpeciesIds=catalog.Species.Select(x=>x.Id).ToArray(),Probability=Probabilities.From(catalog.Species)};
oldRates.Behaviors["redWhiskeredBulbul"]=Behavior.From(catalog.Species[0]) with {FlapFPS=20};
oldRates.Behaviors["treeSparrow"]=Behavior.From(catalog.Species[1]) with {FlapFPS=37};
Check(oldRates.Migrate(catalog.Species) && oldRates.Resolve(catalog.Species[0]).FlapFPS==32 && oldRates.Resolve(catalog.Species[1]).FlapFPS==37,"default wingbeats upgrade and custom rates survive");

foreach(var species in catalog.Species.Where(p=>!FlightBehavior.CanGlide(p.Id))) {
    Check(Enumerable.Range(0,250).All(i=>GalleryPose.Frame(species.Id,i*.1,species.FlapFPS,GalleryAction.Gliding).StartsWith("fly") && GalleryPose.Frame(species.Id,i*.1,species.FlapFPS,GalleryAction.Flying).StartsWith("fly")),species.Id+" gallery does not invent gliding");
}
Check(!FlightBehavior.ShouldGlide("blackKite",4,20,80,80,false) && FlightBehavior.ShouldGlide("blackKite",4,20,160,160,false) && !FlightBehavior.ShouldGlide("blackKite",4,20,160,160,true,true),"gliding requires speed and stops before braking");
foreach(var distance in new[]{1d,80,300,1500}) {
    var timing=new FlightTiming(distance,180);var integral=Enumerable.Range(0,10000).Sum(i=>timing.Speed((i+.5)*timing.Duration/10000)*timing.Duration/10000);
    Check(timing.Speed(0)==0 && Math.Abs(timing.Speed(timing.Duration))<1e-9 && timing.PeakSpeed<=180 && Math.Abs(integral-distance)<.001,"smooth acceleration/braking covers planned distance");
}
foreach(var id in new[]{"blackKite","commonBuzzard","largeBilledCrow"}) {
    var flightProfile=catalog.Species.Single(x=>x.Id==id);var flightSample=new Bird(flightProfile,new(200,420),rng);flightSample.Fly(new(1600,500),a,airspace:new Box(80,120,1800,650));
    var hadGlide=false;var hadBraking=false;var previousGlide=false;var previousSpeed=0d;var smooth=true;var brakingSpeeds=new List<double>();
    for(var i=0;i<(int)(flightSample.FlightDuration*120);i++){
        flightSample.Tick(1d/120);hadGlide|=flightSample.IsGliding;hadBraking|=flightSample.IsBraking;
        if(flightSample.IsGliding && (flightSample.FlightSpeed<100 || flightSample.IsBraking))smooth=false;
        if(previousGlide!=flightSample.IsGliding && Math.Abs(flightSample.FlightSpeed-previousSpeed)>=8)smooth=false;
        if(flightSample.IsBraking){if(!flightSample.Frame.StartsWith("fly"))smooth=false;brakingSpeeds.Add(flightSample.FlightSpeed);}
        previousGlide=flightSample.IsGliding;previousSpeed=flightSample.FlightSpeed;
    }
    Check(hadGlide && hadBraking && smooth && brakingSpeeds[^1]<brakingSpeeds[0]*.1,id+" reaches cruise before gliding and flaps while slowing to land");
}
foreach(var species in catalog.Species) {
    var faster=new Bird(species,new(200,420),rng);faster.Fly(new(1000,500),a,airspace:new Box(80,120,1000,650));
    var meanPerch=(species.PerchMin+species.PerchMax)/2;
    Check(meanPerch/(meanPerch+faster.FlightDuration)>.6,species.Id+" spends most of a default cycle perched");
    var oldCruise=Math.Max(130,720/FlightBehavior.Profile(species.Id).Transit)*species.Speed;var peak=0d;
    for(var i=0;i<(int)(faster.FlightDuration*120);i++){faster.Tick(1d/120);peak=Math.Max(peak,faster.FlightSpeed);}
    Check(peak>oldCruise*(FlightBehavior.CanGlide(species.Id)?1.4:1.2),species.Id+" travels faster while retaining smooth takeoff");
}
var perchPrefs=new Preferences{SpeciesIds=catalog.Species.Select(x=>x.Id).ToArray(),Probability=Probabilities.From(catalog.Species)};
foreach(var species in catalog.Species)perchPrefs.Behaviors[species.Id]=Behavior.From(species) with {PerchMin=species.PerchMin/2,PerchMax=species.PerchMax/2};
Check(perchPrefs.Migrate(catalog.Species) && catalog.Species.All(x=>perchPrefs.Resolve(x)==x),"old default perch durations migrate for every species");
var firstSpecies=catalog.Species[0];perchPrefs.Behaviors[firstSpecies.Id]=Behavior.From(firstSpecies) with {PerchMin=firstSpecies.PerchMin/2,PerchMax=firstSpecies.PerchMax/2};
Check(perchPrefs.Migrate(catalog.Species) && perchPrefs.Resolve(firstSpecies).PerchMin==firstSpecies.PerchMin/2,"deliberately restored old range survives subsequent migration");
perchPrefs.PerchDefaultsVersion=0;perchPrefs.Behaviors[firstSpecies.Id]=Behavior.From(firstSpecies) with {PerchMin=firstSpecies.PerchMin/2+1,PerchMax=firstSpecies.PerchMax/2};
Check(perchPrefs.Migrate(catalog.Species) && perchPrefs.Resolve(firstSpecies).PerchMax==firstSpecies.PerchMax/2,"custom perch range is preserved as a pair");
foreach(var area in new[]{new Box(80,120,1000,650),new Box(-1600,-600,1600,900),new Box(-600,0,600,900)}) {
    foreach(var id in new[]{"blackKite","commonBuzzard","commonKestrel","peregrineFalcon","blackHeadedGull"}) {
        var start=new V(area.X+area.W/2,area.Y+area.H/2);var end=new V(start.X+40,start.Y);
        var wide=new Bird(catalog.Species.Single(x=>x.Id==id),start,rng);wide.Fly(end,null,airspace:area,random:()=>.5);
        var positions=new List<V>();var inside=true;
        for(var i=0;i<(int)(wide.FlightDuration*120);i++) {
            wide.Tick(1d/120);
            if(wide.IsCircling){positions.Add(wide.Position);inside&=area.Contains(new(wide.Position.X,wide.Position.Y,0,0));}
        }
        var width=positions.Max(p=>p.X)-positions.Min(p=>p.X);var height=positions.Max(p=>p.Y)-positions.Min(p=>p.Y);
        Check(inside && width/height>2.2 && width>Math.Min(600,area.W*.6),id+" nearby perches produce wide horizontal sweeps within screen");
        wide.Tick(1);Check(V.Distance(wide.Position,end)<.001,id+" widened orbit still exits at intended perch");
    }
}
var randomWidths=new List<double>();var randomHeights=new List<double>();
foreach(var samples in new[]{new[]{0d,0d},new[]{1d,0d},new[]{1d,1d}}){
    var area=new Box(-1800,-600,1800,900);var index=0;var randomBird=new Bird(catalog.Species.Single(x=>x.Id=="commonBuzzard"),new(-900,-100),rng);
    randomBird.Fly(new(-860,-100),a,airspace:area,random:()=>samples[index++]);
    var positions=new List<V>();var previous=randomBird.Position;var previousSpeed=0d;var wasCircling=false;var checkedExit=false;var smooth=true;
    for(var i=0;i<(int)(randomBird.FlightDuration*120);i++){
        randomBird.Tick(1d/120);smooth&=V.Distance(previous,randomBird.Position)<3;
        if(randomBird.IsCircling)positions.Add(randomBird.Position);
        if(wasCircling && !randomBird.IsCircling){smooth&=Math.Abs(randomBird.FlightSpeed-previousSpeed)<2;checkedExit=true;}
        previous=randomBird.Position;previousSpeed=randomBird.FlightSpeed;wasCircling=randomBird.IsCircling;
    }
    randomWidths.Add(positions.Max(p=>p.X)-positions.Min(p=>p.X));randomHeights.Add(positions.Max(p=>p.Y)-positions.Min(p=>p.Y));
    Check(index==2 && checkedExit && smooth && positions.All(p=>area.Contains(new(p.X,p.Y,0,0))),"random orbit stays inside screen and exits smoothly without resampling");
    randomBird.Tick(1);Check(V.Distance(randomBird.Position,new(-860,-100))<.001,"fractional lap lands on target");
}
Check(randomWidths[1]>1800*.99 && randomWidths[1]/randomWidths[0]>1.5,"random widths can span the full usable screen");
Check(Math.Abs(randomWidths[1]-randomWidths[2])<1 && randomHeights[2]-randomHeights[1]>50,"height varies independently of width");
Check(FlightBehavior.OrbitRadii(8,8,1,1)==new V(0,0),"tiny airspace has no invalid orbit dimensions");
count += GroundChecks.Run(catalog.Species);
count += UpdateChecks.Run();
Console.WriteLine($"{count} core checks passed.");
