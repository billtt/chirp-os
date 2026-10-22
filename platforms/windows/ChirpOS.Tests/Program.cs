using ChirpOS.Core;
var count = 0;
void Check(bool condition, string name) { if (!condition) throw new Exception(name); count++; Console.WriteLine("PASS " + name); }
var s = new Species("redWhiskeredBulbul", "红耳鹎", 19, 1, 20, 1, 14, 28);
Check(s.Scale==1 && Math.Abs((s with{AdultLengthCM=94}).Scale-2.5)<1e-9,"compressed size anchors bulbul at 1 and heron at 2.5");
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

var owlIds = new[] { "collaredScopsOwl", "asianBarredOwlet", "littleOwl" };
var previousSpecies = catalog.Species.Where(b => !owlIds.Contains(b.Id)).ToArray();
var previousProbabilities = Probabilities.From(previousSpecies);
previousProbabilities.Locked[0] = true;
var oldPoints = previousProbabilities.Points.ToArray();
var owlPrefs = new Preferences { SpeciesIds = previousSpecies.Select(b => b.Id).ToArray(), Probability = previousProbabilities, PendingSpeciesIds = [] };
Check(previousSpecies.Length == 43 && catalog.Species.Length == 46, "three owls extend the existing 43 species");
Check(owlPrefs.Migrate(catalog.Species) && owlPrefs.PendingSpeciesIds!.ToHashSet().SetEquals(owlIds), "only new owls become pending");
Check(owlPrefs.Probability.Points.Take(43).SequenceEqual(oldPoints) && owlPrefs.Probability.Locked[0] && owlPrefs.Probability.Points.Skip(43).All(n => n == 0), "owl migration preserves old probabilities and locks");
owlPrefs.AllocateNewSpecies(catalog.Species);
Check(owlPrefs.Probability.Points.Skip(43).Sum() == 652 && owlPrefs.Probability.Valid(46), "three owls receive their proportional allocation");

foreach(var species in catalog.Species) {
    var flightBird=new Bird(species,new(200,420),rng);var target=new V(700,500);var flightHost=new Surface(701,new(100,500,900,300));var airspace=new Box(80,120,1000,650);
    flightBird.Fly(target,flightHost,airspace:airspace);
    var poses=new HashSet<string>();var extended=0;var powered=0;double circleSeconds=0;var flips=0;var right=flightBird.Right;var previous=flightBird.Position;
    for(var step=0;step<=(int)Math.Ceiling(flightBird.FlightDuration*60);step++) {
        flightBird.Tick(1d/60);poses.Add(flightBird.Frame);
        if(V.Distance(previous,flightBird.Position)>=12)throw new Exception(species.Id+" discontinuous flight");previous=flightBird.Position;
        if(flightBird.IsCircling){circleSeconds+=1d/60;if(flightBird.Frame.StartsWith("fly"))powered++;else extended++;if(right!=flightBird.Right){flips++;right=flightBird.Right;}
            if(!airspace.Contains(new(flightBird.Position.X,flightBird.Position.Y,0,0)) || flightBird.Depth!=null)throw new Exception("orbit left screen or adopted depth");}
    }
    Check(flightBird.State==BirdState.Landing && V.Distance(flightBird.Position,target)<.001,species.Id+" lands after full route");
    var motion=FlightBehavior.Profile(species.Id);
    if(motion.Orbit>0)Check(circleSeconds>15 && extended>powered && powered>0 && flips>=3,species.Id+" prolonged circling mixes glides and wingbeats");
    if(motion.Style=="bounding")Check(poses.Contains("bound"),species.Id+" folds wings between bursts");
    flightBird.Flee();Check(flightBird.FlightDuration<1.5 && !flightBird.IsCircling,species.Id+" escape bypasses circling");
}
var oldRates=new Preferences{SpeciesIds=catalog.Species.Select(x=>x.Id).ToArray(),Probability=Probabilities.From(catalog.Species)};
oldRates.Behaviors["redWhiskeredBulbul"]=Behavior.From(catalog.Species[0]) with {FlapFPS=20};
oldRates.Behaviors["treeSparrow"]=Behavior.From(catalog.Species[1]) with {FlapFPS=37};
Check(oldRates.Migrate(catalog.Species) && oldRates.Resolve(catalog.Species[0]).FlapFPS==32 && oldRates.Resolve(catalog.Species[1]).FlapFPS==37,"default wingbeats upgrade and custom rates survive");

Console.WriteLine($"{count} core checks passed.");
