using System.Text.Json;
namespace ChirpOS.Core;

public record Species(string Id, string Name, double AdultLengthCM, double Weight, double FlapFPS,
                      double Speed, double PerchMin, double PerchMax, string? EnglishName=null) {
    public double Scale => Math.Pow(AdultLengthCM / 19, Math.Log(2.5) / Math.Log(94d / 19));
}
public record Catalog(Species[] Species);
public readonly record struct V(double X, double Y) {
    public static double Distance(V a,V b) => Math.Sqrt(Math.Pow(a.X-b.X,2)+Math.Pow(a.Y-b.Y,2));
}
public readonly record struct Box(double X,double Y,double W,double H) {
    public double Right=>X+W; public double Bottom=>Y+H;
    public bool Intersects(Box b)=>X<b.Right && Right>b.X && Y<b.Bottom && Bottom>b.Y;
    public bool Contains(Box b)=>b.X>=X && b.Y>=Y && b.Right<=Right && b.Bottom<=Bottom;
}
public record Surface(long Id,Box Rect,bool Topmost=false,bool CanPerch=true,bool IsGround=false,bool IsTaskbar=false);
public static class Geometry {
    // The work-area bottom is a virtual ledge. Its lower bound reserves tail space.
    public static Surface Ground(long id,Box display,Box workArea) {
        var left=Math.Max(display.X,workArea.X);var right=Math.Min(display.Right,workArea.Right);var y=Math.Clamp(workArea.Bottom,display.Y,display.Bottom);
        return new(id,new(left,y,Math.Max(0,right-left),display.Bottom-y),IsGround:true);
    }
    public static IEnumerable<Surface> Blockers(Surface host,IReadOnlyList<Surface> surfaces) => host.IsGround
        ?surfaces.Where(s=>!s.IsGround && s.Topmost && !s.IsTaskbar)
        :surfaces.TakeWhile(s=>s.Id!=host.Id).Where(s=>!s.IsGround);
    public static List<(double Lo,double Hi)> LandingRanges(Surface host,IReadOnlyList<Surface> surfaces,Box screen,double scale,IReadOnlyList<Box> occupied) {
        var depth=surfaces.ToList().FindIndex(s=>s.Id==host.Id);
        var y=Foot(host,.5,scale:scale).Y;var half=29*scale;
        if(depth<0 || y-39*scale<screen.Y || y+9*scale>screen.Bottom)return [];
        var lo=Math.Max(Foot(host,0).X,screen.X+half);var hi=Math.Min(Foot(host,1).X,screen.Right-half);
        if(hi<=lo)return [];
        var ranges=new List<(double Lo,double Hi)>{(lo,hi)};
        foreach(var rect in Blockers(host,surfaces).Select(s=>s.Rect).Concat(occupied)){
            if(rect.Bottom<=y-39*scale || rect.Y>=y+9*scale)continue;
            var left=rect.X-half;var right=rect.Right+half;
            var next=new List<(double Lo,double Hi)>();
            foreach(var range in ranges){
                if(right<=range.Lo || left>=range.Hi){next.Add(range);continue;}
                if(left>range.Lo)next.Add((range.Lo,left));
                if(right<range.Hi)next.Add((right,range.Hi));
            }
            ranges=next;
        }
        return ranges.Where(r=>r.Hi-r.Lo>.01).ToList();
    }
    public static List<(double Lo,double Hi)> SideRanges(Surface host,PerchEdge edge,IReadOnlyList<Surface> surfaces,Box screen,double scale,IReadOnlyList<Box> occupied) {
        var depth=surfaces.ToList().FindIndex(s=>s.Id==host.Id);var x=edge==PerchEdge.Left?host.Rect.X:host.Rect.Right;
        if(host.IsGround || depth<0 || x-29*scale<screen.X || x+29*scale>screen.Right)return [];
        var lo=Math.Max(host.Rect.Y+42,screen.Y+39*scale);var hi=Math.Min(host.Rect.Bottom-42,screen.Bottom-9*scale);
        if(hi<=lo)return [];var ranges=new List<(double Lo,double Hi)>{(lo,hi)};
        foreach(var r in Blockers(host,surfaces).Select(s=>s.Rect).Concat(occupied)) {
            if(r.Right<=x-29*scale || r.X>=x+29*scale)continue;var a=r.Y-9*scale;var b=r.Bottom+39*scale;
            var next=new List<(double Lo,double Hi)>();foreach(var q in ranges){if(b<=q.Lo || a>=q.Hi){next.Add(q);continue;}if(a>q.Lo)next.Add((q.Lo,a));if(b<q.Hi)next.Add((b,q.Hi));}ranges=next;
        }return ranges.Where(q=>q.Hi-q.Lo>.01).ToList();
    }
    public static V Foot(Surface s,double fraction,PerchEdge edge=PerchEdge.Top,double scale=1) {if(s.IsGround){var margin=Math.Min(42,s.Rect.W/3);return new(s.Rect.X+margin+(s.Rect.W-2*margin)*Math.Clamp(fraction,0,1),Math.Min(s.Rect.Y,s.Rect.Bottom-9*scale));}if(edge!=PerchEdge.Top)return new(edge==PerchEdge.Left?s.Rect.X:s.Rect.Right,s.Rect.Y+42+Math.Max(0,s.Rect.H-84)*Math.Clamp(fraction,0,1));var m=Math.Min(42,s.Rect.W/3);return new(s.Rect.X+m+(s.Rect.W-2*m)*Math.Clamp(fraction,0,1),s.Rect.Y);}
    public static Box Landing(V p,double scale)=>new(p.X-29*scale,p.Y-39*scale,58*scale,48*scale);
    public static bool Visible(long id,V p,IReadOnlyList<Surface> surfaces,double scale) {
        var host=surfaces.FirstOrDefault(s=>s.Id==id);
        return host!=null && !Blockers(host,surfaces).Any(s=>s.Rect.Intersects(Landing(p,scale)));
    }
}
public enum PerchEdge { Top, Left, Right }
public enum BirdState { Flying, Landing, Perched }
public sealed class Bird(Species species,V position,Random rng) {
    public PerchEdge Edge {get;set;}
    public Species Species {get;}=species;
    public V Position {get;private set;}=position;
    public BirdState State {get;private set;}=BirdState.Flying;
    public long? Host {get;private set;} public long? Depth {get;private set;}
    public bool Departing {get;private set;} public bool Right {get;private set;}=true;
    public double Fraction {get;set;}=.5;
    public double Age {get;private set;}
    public double PerchDuration {get;}=species.PerchMin+rng.NextDouble()*(species.PerchMax-species.PerchMin);
    public int Landings {get;private set;} public int Startles {get;private set;}
    public double Followed {get;private set;}
    V origin=position,target=position; Box? previous; double flightAge,duration=1,arc=90; bool invalid;
    double transitDuration=1,orbitDuration,orbitRadius=100,orbitHeight=100;FlightPath? orbitPath; V orbitCenter; bool urgentFlight;
    double entryDuration,exitDuration,orbitTurns=1;FlightPath? approach,exitPath,transitPath;V plannedTarget=position;
    FlightTiming? approachTiming,exitTiming,transitTiming;double cruiseSpeed;
    public double FlightSpeed {get;private set;}
    public bool IsGliding {get;private set;}
    public bool IsBraking=>orbitDuration>0?flightAge>=entryDuration+orbitDuration && flightAge-entryDuration-orbitDuration>=(exitTiming?.BrakeStart??double.PositiveInfinity)-.12:flightAge>=(transitTiming?.BrakeStart??double.PositiveInfinity)-.12;
    public double FlightDuration=>duration;
    public bool IsCircling=>orbitDuration>0 && flightAge>=entryDuration && flightAge<entryDuration+orbitDuration;
    V OrbitPoint=>orbitPath!.Point((Math.Max(0,(flightAge-entryDuration)/Math.Max(.001,orbitDuration))*orbitTurns)%1);
    public bool NeedsDestination=>!Departing && (invalid || (State==BirdState.Flying && flightAge>=duration && Host==null) || (State==BirdState.Perched && Age>=PerchDuration));
    public bool DepartureFinished=>Departing && flightAge>=duration;
    public void Fly(V point,Surface? host,double seconds=3,double height=90,bool departing=false,Box? airspace=null,bool urgent=false,Func<double>? random=null) {
        if(host?.IsGround==true)Edge=PerchEdge.Top;
        origin=Position;target=point;Host=host?.Id;Depth=null;previous=null;
        var m=FlightBehavior.Profile(Species.Id);urgentFlight=urgent || departing;
        transitDuration=Math.Max(.3,seconds)/(2*Species.Speed);
        orbitDuration=urgentFlight?0:m.Orbit;duration=transitDuration+orbitDuration;arc=height;
        var cruise=FlightBehavior.CruiseSpeed(Species.Id,Species.Speed);
        if(orbitDuration>0){
            var draw=random ?? rng.NextDouble;
            var radii=FlightBehavior.OrbitRadii(airspace?.W??Math.Max(800,V.Distance(origin,point)*1.5),airspace?.H??800,draw(),draw());
            orbitRadius=radii.X;orbitHeight=radii.Y;orbitPath=FlightBehavior.OrbitPath(orbitRadius,orbitHeight);
            // Leave on a tangent after a fractional lap, retaining width, speed and duration.
            orbitTurns=orbitDuration*cruise/Math.Max(1,orbitPath.Length);
        }
        orbitCenter=new((origin.X+point.X)/2,Math.Min(origin.Y,point.Y)-40);
        if(airspace is Box area) {
            orbitCenter=new(Math.Min(area.Right-orbitRadius,Math.Max(area.X+orbitRadius,orbitCenter.X)),Math.Min(area.Bottom-orbitHeight,Math.Max(area.Y+orbitHeight,orbitCenter.Y)));
            arc=Math.Min(height,Math.Max(0,Math.Min(origin.Y,point.Y)-area.Y));
        }
        if(orbitRadius<24 || orbitHeight<12)orbitDuration=0;
        plannedTarget=point;cruiseSpeed=cruise;IsGliding=false;FlightSpeed=0;transitTiming=null;
        V Inside(V p)=>airspace is Box a?new(Math.Clamp(p.X,a.X,a.Right),Math.Clamp(p.Y,a.Y,a.Bottom)):p;
        if(orbitDuration>0){
            var entry=new V(orbitCenter.X-orbitRadius,orbitCenter.Y);
            var arriveBend=Math.Min(orbitHeight*.8,V.Distance(origin,entry)*.4);var last=orbitPath!.Point(orbitTurns%1);var exit=new V(orbitCenter.X+last.X,orbitCenter.Y+last.Y);var tangent=orbitPath.LoopTangent(orbitTurns);
            var leaveBend=Math.Min(orbitHeight*.8,V.Distance(exit,point)*.4);
            // Preserve the tangent direction when its control point reaches an edge.
            if(airspace is Box bounds){
                if(tangent.X>.000001)leaveBend=Math.Min(leaveBend,(bounds.Right-exit.X)/tangent.X);
                if(tangent.X<-.000001)leaveBend=Math.Min(leaveBend,(bounds.X-exit.X)/tangent.X);
                if(tangent.Y>.000001)leaveBend=Math.Min(leaveBend,(bounds.Bottom-exit.Y)/tangent.Y);
                if(tangent.Y<-.000001)leaveBend=Math.Min(leaveBend,(bounds.Y-exit.Y)/tangent.Y);
            }
            approach=new(origin,Inside(new(origin.X+(entry.X-origin.X)*.35,origin.Y+(entry.Y-origin.Y)*.35)),Inside(new(entry.X,entry.Y-arriveBend)),entry);
            exitPath=new(exit,Inside(new(exit.X+tangent.X*leaveBend,exit.Y+tangent.Y*leaveBend)),Inside(new(point.X,point.Y-Math.Min(arc,leaveBend))),point);
            approachTiming=new(approach.Length,cruiseSpeed,Math.Min(.65,1.8*approach.Length/cruiseSpeed),0);
            exitTiming=new(exitPath.Length,cruiseSpeed,0,Math.Min(.85,1.8*exitPath.Length/cruiseSpeed));
            entryDuration=approachTiming.Duration;exitDuration=exitTiming.Duration;transitDuration=entryDuration+exitDuration;
        }else{
            transitPath=new(origin,new(origin.X+(point.X-origin.X)/3,origin.Y+(point.Y-origin.Y)/3-arc*4/3),new(origin.X+(point.X-origin.X)*2/3,origin.Y+(point.Y-origin.Y)*2/3-arc*4/3),point);
            if(!urgentFlight){transitTiming=new(transitPath.Length,cruise);transitDuration=transitTiming.Duration;cruiseSpeed=transitTiming.PeakSpeed;}
        }
        duration=transitDuration+orbitDuration;
        flightAge=0;Age=0;State=BirdState.Flying;invalid=false;Departing=departing;
    }
    public void Flee(){Startles++;Fly(new(Position.X+(Right?210:-210),Position.Y-100),null,1.25,45,urgent:true);}
    public void Perch(Surface s,double scale=1){if(s.IsGround)Edge=PerchEdge.Top;Host=Depth=s.Id;previous=s.Rect;Position=Geometry.Foot(s,Fraction,Edge,scale);State=BirdState.Perched;Age=0;invalid=false;IsGliding=false;FlightSpeed=0;if(Edge!=PerchEdge.Top)Right=Edge==PerchEdge.Left;}
    public void UpdateHost(IReadOnlyList<Surface> surfaces,double dt,double scale) {
        if(Host==null)return;var host=surfaces.FirstOrDefault(s=>s.Id==Host);
        if(host==null){Flee();return;}var point=Geometry.Foot(host,Fraction,Edge,scale);
        if(State==BirdState.Flying && !Geometry.Visible(host.Id,point,surfaces,scale)) {Host=Depth=null;previous=null;invalid=true;return;}
        if(State!=BirdState.Flying){if(previous is Box old){var delta=V.Distance(new(old.X,old.Y),new(host.Rect.X,host.Rect.Y));if(!host.IsGround && dt<.2 && delta>8 && delta/Math.Max(.016,dt)>950){Flee();return;}Followed+=V.Distance(Position,point);}Position=point;}else target=point;
        previous=host.Rect;
    }
    public void Tick(double dt) {
        if(invalid)return;Age+=dt;
        if(State==BirdState.Flying){
            flightAge+=dt;var t=Math.Min(1,flightAge/duration);var m=FlightBehavior.Profile(Species.Id);V next;
            if(orbitDuration>0){
                if(flightAge<entryDuration)next=approach!.Point(approachTiming!.Progress(flightAge));
                else if(IsCircling){var p=OrbitPoint;next=new(orbitCenter.X+p.X,orbitCenter.Y+p.Y);}
                else {var u=exitTiming!.Progress(flightAge-entryDuration-orbitDuration);var p=exitPath!.Point(u);next=new(p.X+(target.X-plannedTarget.X)*u,p.Y+(target.Y-plannedTarget.Y)*u);}
            }else{
                var u=transitTiming?.Progress(flightAge)??FlightBehavior.TravelProgress(t,transitDuration);var p=transitPath?.Point(u)??origin;
                var wave=urgentFlight?0:m.Wave*Math.Sin(2*Math.PI*flightAge/m.Cycle)*Math.Pow(Math.Sin(t*Math.PI),2);
                next=new(p.X+(target.X-plannedTarget.X)*u,p.Y+(target.Y-plannedTarget.Y)*u+wave);
            }
            if(Math.Abs(next.X-Position.X)>.05)Right=next.X>Position.X;var destination=t>=1?target:next;
            FlightSpeed=V.Distance(Position,destination)/Math.Max(.000001,dt);Position=destination;
            IsGliding=!urgentFlight && t<1 && FlightBehavior.ShouldGlide(Species.Id,flightAge,Species.FlapFPS,FlightSpeed,cruiseSpeed,IsBraking,IsGliding);
            if(t>=1 && Host!=null){Depth=Host;State=BirdState.Landing;Age=0;Landings++;if(Edge!=PerchEdge.Top)Right=Edge==PerchEdge.Left;}
        }
        else if(State==BirdState.Landing && Age>.42){State=BirdState.Perched;Age=0;}
    }
    public IEnumerable<Box> Blockers(IReadOnlyList<Surface> surfaces) {
        if(Depth is long id && surfaces.FirstOrDefault(s=>s.Id==id) is Surface host){
            // A taskbar supports the feet, so it is not a landing obstruction;
            // still mask any tail pixels that extend behind the actual bar.
            var blockers=host.IsGround?surfaces.Where(s=>!s.IsGround && s.Topmost):Geometry.Blockers(host,surfaces);
            foreach(var s in blockers)yield return s.Rect;
        }
        else foreach(var s in surfaces.Where(s=>!s.IsGround && s.Topmost))yield return s.Rect;
    }
    public double Hop => State == BirdState.Perched && Edge == PerchEdge.Top ? SpeciesBehavior.Hop(Species.Id, Age) : 0;
    public string Frame {get {
        if(State==BirdState.Flying){
            return FlightBehavior.Frame(Species.Id,flightAge,Species.FlapFPS,IsGliding,IsCircling?-OrbitPoint.X/orbitRadius:0);
        }
        if(State==BirdState.Landing && Edge!=PerchEdge.Top)return "cling0";
        if(State==BirdState.Landing)return "land"+Math.Min(2,(int)(Age/.14));
        return SpeciesBehavior.Frame(Species.Id, Age, Edge != PerchEdge.Top) ?? "stand";
    }}
}
public sealed class Probabilities {
    public int[] Points {get;set;}=[]; public bool[] Locked {get;set;}=[];
    public static int[] Apportion(int total,IReadOnlyList<double> amounts) {
        if(amounts.Count==0)return [];var sum=amounts.Sum();var exact=amounts.Select(x=>sum>0?total*x/sum:(double)total/amounts.Count).ToArray();var result=exact.Select(x=>(int)Math.Floor(x)).ToArray();
        foreach(var i in Enumerable.Range(0,result.Length).OrderByDescending(i=>exact[i]-result[i]).ThenBy(i=>i).Take(total-result.Sum()))result[i]++;return result;
    }
    public static Probabilities From(Species[] species)=>new(){Points=Apportion(10000,species.Select(x=>x.Weight).ToArray()),Locked=new bool[species.Length]};
    public bool Valid(int count)=>Points.Length==count && Locked.Length==count && Points.All(x=>x>=0 && x<=10000) && Points.Sum()==10000;
    public bool CanAdjust(int i)=>!Locked[i] && Enumerable.Range(0,Points.Length).Any(j=>j!=i && !Locked[j]);
    public void Adjust(int i,int request) {
        if(!CanAdjust(i))return;var maximum=10000-Enumerable.Range(0,Points.Length).Where(j=>j!=i && Locked[j]).Sum(j=>Points[j]);var value=Math.Clamp(request,0,maximum);var peers=Enumerable.Range(0,Points.Length).Where(j=>j!=i && !Locked[j]).ToArray();var split=Apportion(maximum-value,peers.Select(j=>(double)Points[j]).ToArray());Points[i]=value;for(var n=0;n<peers.Length;n++)Points[peers[n]]=split[n];
    }
    public int Choose(Random rng){var ticket=rng.Next(10000);for(var i=0;i<Points.Length;i++){ticket-=Points[i];if(ticket<0)return i;}throw new InvalidOperationException("Invalid probabilities");}
}
public sealed record Behavior(double AdultLengthCM, double FlapFPS, double Speed, double PerchMin, double PerchMax, string? EnglishName=null) {
    public static Behavior From(Species s) => new(s.AdultLengthCM,s.FlapFPS,s.Speed,s.PerchMin,s.PerchMax);
    public bool Valid => double.IsFinite(AdultLengthCM) && AdultLengthCM is >=8 and <=110 &&
        double.IsFinite(FlapFPS) && FlapFPS is >=4 and <=60 && double.IsFinite(Speed) && Speed is >=.5 and <=2 &&
        double.IsFinite(PerchMin) && PerchMin is >=2 and <=300 && double.IsFinite(PerchMax) && PerchMax>=PerchMin && PerchMax<=600;
    public Species Apply(Species s) => s with { AdultLengthCM=AdultLengthCM, FlapFPS=FlapFPS, Speed=Speed, PerchMin=PerchMin, PerchMax=PerchMax };
}
// A window's bounding rectangle is not proof that it contains opaque pixels.
public static class WindowPolicy {
    public static bool Occludes(string className,long style,long exStyle,byte? alpha=null) {
        if(className is "Progman" or "WorkerW" or "SysShadow" or "tooltips_class32" or "msctls_dragimagelist")return false;
        const long layered=0x80000,transparent=0x20,tool=0x80,noActivate=0x8000000,caption=0xC00000,app=0x40000;
        if(alpha==0)return false;
        if((exStyle&layered)!=0 && (exStyle&transparent)!=0)return false;
        // Per-pixel helper surfaces (shadows/drag adorners) cannot be represented as solid rectangles.
        // Keep normal framed applications, including layered ones and visible floating palettes.
        if((style&caption)==0 && (exStyle&app)==0 && (exStyle&(tool|noActivate))==(tool|noActivate) && (exStyle&(layered|0x200000))!=0)return false;
        return true;
    }
}
public sealed class Preferences {
    public int PerchDefaultsVersion {get;set;}
    public int Minimum {get;set;}=5; public int Maximum {get;set;}=5;
    public bool English {get;set;} public double Scale {get;set;}=1;
    public Probabilities Probability {get;set;}=new();
    public Dictionary<string,Behavior> Behaviors {get;set;}=new();
    public string[]? SpeciesIds {get;set;}
    public string[]? PendingSpeciesIds {get;set;}
    public void AllocateNewSpecies(Species[] species) {
        var fresh=(PendingSpeciesIds ?? []).ToHashSet();
        var added=Enumerable.Range(0,species.Length).Where(i=>fresh.Contains(species[i].Id)).ToArray();
        var old=Enumerable.Range(0,species.Length).Where(i=>!fresh.Contains(species[i].Id)).ToArray();
        if(added.Length==0)return;
        var budget=(int)Math.Round(10000d*added.Length/species.Length,MidpointRounding.AwayFromZero);
        var a=Probabilities.Apportion(budget,added.Select(i=>species[i].Weight).ToArray());
        var b=Probabilities.Apportion(10000-budget,old.Select(i=>(double)Probability.Points[i]).ToArray());
        for(var j=0;j<added.Length;j++)Probability.Points[added[j]]=a[j];
        for(var j=0;j<old.Length;j++)Probability.Points[old[j]]=b[j];
    }
    public bool Migrate(Species[] species) {
        var ids=SpeciesIds ?? new[]{"redWhiskeredBulbul","treeSparrow","lightVentedBulbul","spottedDove","chineseBlackbird","magpieRobin","longTailedShrike"};
        if (!Probability.Valid(ids.Length) || ids.Distinct().Count()!=ids.Length || ids.Any(id=>!species.Any(s=>s.Id==id))) return false;
        foreach(var current in species) {
            if(!Behaviors.TryGetValue(current.Id,out var custom))continue;
            if(Math.Abs(custom.FlapFPS-current.FlapFPS/FlightBehavior.Profile(current.Id).Rate)<.0001)
                custom=custom with {FlapFPS=current.FlapFPS};
            if(PerchDefaultsVersion<1 && custom.PerchMin==current.PerchMin/2 && custom.PerchMax==current.PerchMax/2)
                custom=custom with {PerchMin=current.PerchMin,PerchMax=current.PerchMax};
            Behaviors[current.Id]=custom;
        }
        PerchDefaultsVersion=1;
        PendingSpeciesIds=species.Where(s=>!ids.Contains(s.Id) || (PendingSpeciesIds ?? []).Contains(s.Id)).Select(s=>s.Id).ToArray();
        var points=new int[species.Length]; var locks=new bool[species.Length];
        for(var i=0;i<ids.Length;i++){var j=Array.FindIndex(species,s=>s.Id==ids[i]);points[j]=Probability.Points[i];locks[j]=Probability.Locked[i];}
        Probability=new(){Points=points,Locked=locks}; SpeciesIds=species.Select(s=>s.Id).ToArray(); return true;
    }
    public void NormalizeGeneralSettings() {
        Minimum=Maximum=Math.Clamp(Maximum,5,20);
        Scale=double.IsFinite(Scale)?Math.Clamp(Scale,1,2):1;
    }
    public Species Resolve(Species s)=>Behaviors.TryGetValue(s.Id,out var behavior)?behavior.Apply(s):s;
    public bool Valid(int count)=>Minimum>=1 && Maximum>=Minimum && Maximum<=50 && (double.IsFinite(Scale) && Scale>=1 && Scale<=2) && Probability != null && Probability.Valid(count) && Behaviors != null && Behaviors.Values.All(b=>b != null && b.Valid);
}
