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
public record Surface(long Id,Box Rect,bool Topmost=false,bool CanPerch=true);
public static class Geometry {
    public static List<(double Lo,double Hi)> LandingRanges(Surface host,IReadOnlyList<Surface> surfaces,Box screen,double scale,IReadOnlyList<Box> occupied) {
        var depth=surfaces.ToList().FindIndex(s=>s.Id==host.Id);
        var y=host.Rect.Y;var half=29*scale;
        if(depth<0 || y-39*scale<screen.Y || y+9*scale>screen.Bottom)return [];
        var lo=Math.Max(Foot(host,0).X,screen.X+half);var hi=Math.Min(Foot(host,1).X,screen.Right-half);
        if(hi<=lo)return [];
        var ranges=new List<(double Lo,double Hi)>{(lo,hi)};
        foreach(var rect in surfaces.Take(depth).Select(s=>s.Rect).Concat(occupied)){
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
        if(depth<0 || x-29*scale<screen.X || x+29*scale>screen.Right)return [];
        var lo=Math.Max(host.Rect.Y+42,screen.Y+39*scale);var hi=Math.Min(host.Rect.Bottom-42,screen.Bottom-9*scale);
        if(hi<=lo)return [];var ranges=new List<(double Lo,double Hi)>{(lo,hi)};
        foreach(var r in surfaces.Take(depth).Select(s=>s.Rect).Concat(occupied)) {
            if(r.Right<=x-29*scale || r.X>=x+29*scale)continue;var a=r.Y-9*scale;var b=r.Bottom+39*scale;
            var next=new List<(double Lo,double Hi)>();foreach(var q in ranges){if(b<=q.Lo || a>=q.Hi){next.Add(q);continue;}if(a>q.Lo)next.Add((q.Lo,a));if(b<q.Hi)next.Add((b,q.Hi));}ranges=next;
        }return ranges.Where(q=>q.Hi-q.Lo>.01).ToList();
    }
    public static V Foot(Surface s,double fraction,PerchEdge edge=PerchEdge.Top) {if(edge!=PerchEdge.Top)return new(edge==PerchEdge.Left?s.Rect.X:s.Rect.Right,s.Rect.Y+42+Math.Max(0,s.Rect.H-84)*Math.Clamp(fraction,0,1));var m=Math.Min(42,s.Rect.W/3);return new(s.Rect.X+m+(s.Rect.W-2*m)*Math.Clamp(fraction,0,1),s.Rect.Y);}
    public static Box Landing(V p,double scale)=>new(p.X-29*scale,p.Y-39*scale,58*scale,48*scale);
    public static bool Visible(long id,V p,IReadOnlyList<Surface> surfaces,double scale) {
        foreach(var s in surfaces) {if(s.Id==id)return true;if(s.Rect.Intersects(Landing(p,scale)))return false;}return false;
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
    public bool NeedsDestination=>!Departing && (invalid || (State==BirdState.Flying && flightAge>=duration && Host==null) || (State==BirdState.Perched && Age>=PerchDuration));
    public bool DepartureFinished=>Departing && flightAge>=duration;
    public void Fly(V point,Surface? host,double seconds=3,double height=90,bool departing=false) {
        origin=Position;target=point;Host=host?.Id;Depth=null;previous=null;
        duration=Math.Max(.3,seconds)/(2*Species.Speed);arc=height;flightAge=0;Age=0;State=BirdState.Flying;invalid=false;Departing=departing;
    }
    public void Flee(){Startles++;Fly(new(Position.X+(Right?210:-210),Position.Y-100),null,1.25,45);}
    public void Perch(Surface s){Host=Depth=s.Id;previous=s.Rect;Position=Geometry.Foot(s,Fraction,Edge);State=BirdState.Perched;Age=0;invalid=false;if(Edge!=PerchEdge.Top)Right=Edge==PerchEdge.Left;}
    public void UpdateHost(IReadOnlyList<Surface> surfaces,double dt,double scale) {
        if(Host==null)return;var host=surfaces.FirstOrDefault(s=>s.Id==Host);
        if(host==null){Flee();return;}var point=Geometry.Foot(host,Fraction,Edge);
        if(State==BirdState.Flying && !Geometry.Visible(host.Id,point,surfaces,scale)) {Host=Depth=null;previous=null;invalid=true;return;}
        if(State!=BirdState.Flying){if(previous is Box old){var delta=V.Distance(new(old.X,old.Y),new(host.Rect.X,host.Rect.Y));if(dt<.2 && delta>8 && delta/Math.Max(.016,dt)>950){Flee();return;}Followed+=V.Distance(Position,point);}Position=point;}else target=point;
        previous=host.Rect;
    }
    public void Tick(double dt) {
        if(invalid)return;Age+=dt;
        if(State==BirdState.Flying){flightAge+=dt;var t=Math.Min(1,flightAge/duration);var u=t*t*(3-2*t);var next=new V(origin.X+(target.X-origin.X)*u,origin.Y+(target.Y-origin.Y)*u-Math.Sin(t*Math.PI)*arc);if(Math.Abs(next.X-Position.X)>.05)Right=next.X>Position.X;Position=next;if(t>=1 && Host!=null){Depth=Host;State=BirdState.Landing;Age=0;Landings++;if(Edge!=PerchEdge.Top)Right=Edge==PerchEdge.Left;}}
        else if(State==BirdState.Landing && Age>.42){State=BirdState.Perched;Age=0;}
    }
    public IEnumerable<Box> Blockers(IReadOnlyList<Surface> surfaces) {
        if(Depth is long id){foreach(var s in surfaces){if(s.Id==id)yield break;yield return s.Rect;}}
        else foreach(var s in surfaces.Where(s=>s.Topmost))yield return s.Rect;
    }
    public double Hop => State == BirdState.Perched && Edge == PerchEdge.Top ? SpeciesBehavior.Hop(Species.Id, Age) : 0;
    public string Frame {get {
        if(State==BirdState.Flying)return "fly"+((int)(Age*Species.FlapFPS)%8);
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
    public int Minimum {get;set;}=3; public int Maximum {get;set;}=5;
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
        PendingSpeciesIds=species.Where(s=>!ids.Contains(s.Id) || (PendingSpeciesIds ?? []).Contains(s.Id)).Select(s=>s.Id).ToArray();
        var points=new int[species.Length]; var locks=new bool[species.Length];
        for(var i=0;i<ids.Length;i++){var j=Array.FindIndex(species,s=>s.Id==ids[i]);points[j]=Probability.Points[i];locks[j]=Probability.Locked[i];}
        Probability=new(){Points=points,Locked=locks}; SpeciesIds=species.Select(s=>s.Id).ToArray(); return true;
    }
    public Species Resolve(Species s)=>Behaviors.TryGetValue(s.Id,out var behavior)?behavior.Apply(s):s;
    public bool Valid(int count)=>Minimum>=1 && Maximum>=Minimum && Maximum<=50 && (Scale==1 || Scale==1.5) && Probability != null && Probability.Valid(count) && Behaviors != null && Behaviors.Values.All(b=>b != null && b.Valid);
}
