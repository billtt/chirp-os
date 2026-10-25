namespace ChirpOS.Core;

public static class FlightBehavior {
    public record Motion(string Style, double Transit, double Cycle, double Powered, double Rate, double Wave, double Orbit, double Period);
    public static Motion Profile(string id) => id switch {
        "silkyStarling" => new("direct", 3.46, 3, 0.94, 1.8, 0, 0, 0),
        "crestedMyna" => new("direct", 3.53, 3, 0.94, 1.8, 0, 0, 0),
        "greatCrestedGrebe" => new("steady", 6.39, 5, 0.9, 1.5, 0, 0, 0),
        "daurianRedstart" => new("bounding", 2.29, 1.3, 0.78, 1.7, 10, 0, 0),
        "taiwanBarbet" => new("direct", 3.39, 3, 0.94, 1.8, 0, 0, 0),
        "groundTit" => new("bounding", 2.43, 1.3, 0.78, 1.7, 10, 0, 0),
        "greatEgret" => new("steady", 7, 5, 0.9, 1.5, 0, 0, 0),
        "uplandBuzzard" => new("raptor", 7, 12, 0.15, 1.5, 0, 40, 14),
        "littleGrebe" => new("direct", 3.57, 3, 0.94, 1.8, 0, 0, 0),
        "carrionCrow" => new("direct", 4.12, 3, 0.94, 1.8, 0, 0, 0),
        "plainLaughingthrush" => new("bounding", 2.63, 1.3, 0.78, 1.7, 10, 0, 0),
        "orientalTurtleDove" => new("direct", 3.75, 3, 0.94, 1.8, 0, 0, 0),
        "easternSpotBilledDuck" => new("direct", 4.36, 3, 0.94, 1.8, 0, 0, 0),
        "eurasianNuthatch" => new("bounding", 2.25, 1.3, 0.78, 1.7, 10, 0, 0),
        "rufousBreastedAccentor" => new("bounding", 2.36, 1.3, 0.78, 1.7, 10, 0, 0),
        "eurasianMagpie" => new("bounding", 3.03, 1.3, 0.78, 1.7, 10, 0, 0),
        "eurasianGreatTit" => new("bounding", 2.25, 1.3, 0.78, 1.7, 10, 0, 0),
        "marshTit" => new("bounding", 2.16, 1.3, 0.78, 1.7, 10, 0, 0),
        "ashyDrongo" => new("aerial", 4.67, 2.2, 0.58, 1.6, 18, 0, 0),
        "eurasianCollaredDove" => new("direct", 3.72, 3, 0.94, 1.8, 0, 0, 0),
        "greyTreepie" => new("bounding", 2.89, 1.3, 0.78, 1.7, 10, 0, 0),
        "whiteCheekedStarling" => new("direct", 3.46, 3, 0.94, 1.8, 0, 0, 0),
        "henricsLaughingthrush" => new("bounding", 2.57, 1.3, 0.78, 1.7, 10, 0, 0),
        "indianWhiteEye" => new("bounding", 2.07, 1.3, 0.78, 1.7, 10, 0, 0),
        "easternCattleEgret" => new("steady", 6.42, 5, 0.9, 1.5, 0, 0, 0),
        "commonPheasant" => new("direct", 3.2, 3, 1, 2, 0, 0, 0),
        "sootyHeadedBulbul" => new("bounding", 2.46, 1.3, 0.78, 1.7, 10, 0, 0),
        "whiteBrowedLaughingthrush" => new("bounding", 2.72, 1.3, 0.78, 1.7, 10, 0, 0),
        "whiteWagtail" => new("bounding", 2.43, 1.3, 0.78, 1.7, 10, 0, 0),
        "blueWhistlingThrush" => new("bounding", 2.79, 1.3, 0.78, 1.7, 10, 0, 0),
        "redBilledChough" => new("soaring", 6.15, 7, 0.32, 1.5, 0, 20, 10),
        "redBilledBlueMagpie" => new("bounding", 3.3, 1.3, 0.78, 1.7, 10, 0, 0),
        "blackThroatedBushtit" => new("bounding", 2.07, 1.3, 0.78, 1.7, 10, 0, 0),
        "greenBackedTit" => new("bounding", 2.21, 1.3, 0.78, 1.7, 10, 0, 0),
        "blueThroatedBarbet" => new("direct", 3.43, 3, 0.94, 1.8, 0, 0, 0),
        "blueFrontedRedstart" => new("bounding", 2.29, 1.3, 0.78, 1.7, 10, 0, 0),
        "greaterCoucal" => new("direct", 4.12, 3, 0.94, 1.8, 0, 0, 0),
        "hornedLark" => new("bounding", 2.36, 1.3, 0.78, 1.7, 10, 0, 0),
        "redThroatedThrush" => new("bounding", 2.57, 1.3, 0.78, 1.7, 10, 0, 0),
        "ruddyShelduck" => new("direct", 4.43, 3, 0.94, 1.8, 0, 0, 0),
        "blackRedstart" => new("bounding", 2.4, 1.3, 0.78, 1.7, 10, 0, 0),
        "daurianJackdaw" => new("direct", 3.78, 3, 0.94, 1.8, 0, 0, 0),
        "greyCappedGreenfinch" => new("bounding", 2.25, 1.3, 0.78, 1.7, 10, 0, 0),
        "silverThroatedBushtit" => new("bounding", 2.21, 1.3, 0.78, 1.7, 10, 0, 0),
        "commonTailorbird" => new("bounding", 2.16, 1.3, 0.78, 1.7, 10, 0, 0),
        "collaredFinchbill" => new("bounding", 2.52, 1.3, 0.78, 1.7, 10, 0, 0),
        "himalayanVulture" => new("raptor", 8, 16, 0.08, 1.3, 0, 52, 18),
        "twite" => new("bounding", 2.25, 1.3, 0.78, 1.7, 10, 0, 0),
        "yellowBilledBlueMagpie" => new("bounding", 3.24, 1.3, 0.78, 1.7, 10, 0, 0),
        "ornateSunbird" => new("direct", 2.85, 3, 0.94, 1.8, 0, 0, 0),
        "brownBreastedBulbul" => new("bounding", 2.49, 1.3, 0.78, 1.7, 10, 0, 0),
        "whiskeredYuhina" => new("bounding", 2.21, 1.3, 0.78, 1.7, 10, 0, 0),
        "blackTailedGull" => new("soaring", 6.47, 7, 0.32, 1.5, 0, 20, 10),
        "blackBulbul" => new("bounding", 2.6, 1.3, 0.78, 1.7, 10, 0, 0),
        "redWhiskeredBulbul" => new("bounding", 2.4, 1.2, 0.72, 1.6, 10, 0, 0),
        "treeSparrow" => new("bounding", 1.8, 0.8, 0.80, 1.6, 7, 0, 0),
        "lightVentedBulbul" => new("bounding", 2.6, 1.3, 0.74, 1.7, 11, 0, 0),
        "spottedDove" => new("direct", 3.0, 3.0, 0.86, 2.0, 0, 0, 0),
        "chineseBlackbird" => new("bounding", 2.5, 1.5, 0.80, 1.7, 8, 0, 0),
        "magpieRobin" => new("bounding", 2.2, 1.0, 0.78, 1.6, 9, 0, 0),
        "longTailedShrike" => new("bounding", 2.8, 1.8, 0.72, 1.6, 12, 0, 0),
        "nightHeron" => new("steady", 5.8, 5.0, 0.88, 1.5, 0, 0, 0),
        "plumbeousWaterRedstart" => new("bounding", 2.1, 0.9, 0.82, 1.6, 8, 0, 0),
        "littleEgret" => new("steady", 5.4, 4.5, 0.90, 1.6, 0, 0, 0),
        "greyHeron" => new("steady", 7.0, 6.0, 0.90, 1.4, 0, 0, 0),
        "commonKestrel" => new("raptor", 4.0, 5.0, 0.40, 1.7, 0, 18, 9),
        "peregrineFalcon" => new("raptor", 3.6, 6.0, 0.30, 1.6, 0, 20, 10),
        "blackKite" => new("raptor", 5.0, 10.0, 0.16, 1.6, 0, 36, 12),
        "commonBuzzard" => new("raptor", 5.8, 12.0, 0.14, 1.5, 0, 42, 14),
        "orientalMagpie" => new("bounding", 3.6, 2.0, 0.82, 1.5, 14, 0, 0),
        "azureWingedMagpie" => new("bounding", 3.1, 1.6, 0.78, 1.6, 12, 0, 0),
        "largeBilledCrow" => new("direct", 4.3, 4.5, 0.70, 1.5, 0, 0, 0),
        "hoopoe" => new("bounding", 3.0, 1.8, 0.65, 1.5, 20, 0, 0),
        "barnSwallow" => new("aerial", 7.0, 2.8, 0.50, 1.6, 25, 0, 0),
        "mallard" => new("direct", 3.4, 4.0, 1.0, 2.2, 0, 0, 0),
        "asianKoel" => new("direct", 3.7, 3.0, 0.78, 1.5, 0, 0, 0),
        "swinhoesWhiteEye" => new("bounding", 1.9, 0.7, 0.82, 1.7, 6, 0, 0),
        "blackHeadedGull" => new("soaring", 6.0, 7.0, 0.30, 1.5, 0, 16, 8),
        "whimbrel" => new("steady", 4.6, 4.0, 0.92, 1.8, 0, 0, 0),
        "piedKingfisher" => new("direct", 3.0, 2.5, 0.90, 1.8, 0, 0, 0),
        "eurasianWoodcock" => new("direct", 2.8, 2.0, 0.94, 1.8, 0, 0, 0),
        "blackDrongo" => new("aerial", 4.5, 2.2, 0.58, 1.6, 18, 0, 0),
        "chinesePondHeron" => new("steady", 4.8, 4.0, 0.92, 1.6, 0, 0, 0),
        "yellowRumpedFlycatcher" => new("bounding", 2.0, 0.9, 0.80, 1.7, 10, 0, 0),
        "yellowBrowedWarbler" => new("bounding", 1.7, 0.7, 0.84, 1.8, 6, 0, 0),
        "greatTit" => new("bounding", 2.0, 0.8, 0.78, 1.8, 9, 0, 0),
        "commonMoorhen" => new("direct", 3.8, 3.0, 1.0, 1.8, 0, 0, 0),
        "greatSpottedWoodpecker" => new("bounding", 3.5, 1.6, 0.55, 1.6, 22, 0, 0),
        "vinousThroatedParrotbill" => new("bounding", 2.1, 0.9, 0.82, 1.7, 9, 0, 0),
        "blackWingedStilt" => new("steady", 4.5, 3.5, 0.94, 1.7, 0, 0, 0),
        "eurasianCoot" => new("direct", 4.0, 3.0, 1.0, 2.0, 0, 0, 0),
        "redBilledLeiothrix" => new("bounding", 2.2, 1.0, 0.80, 1.7, 8, 0, 0),
        "blackCollaredStarling" => new("direct", 2.8, 2.5, 0.90, 1.9, 0, 0, 0),
        "commonKingfisher" => new("direct", 2.0, 2.0, 1.0, 1.875, 0, 0, 0),
        "littleRingedPlover" => new("direct", 2.4, 2.2, 0.95, 1.9, 0, 0, 0),
        "yellowBilledGrosbeak" => new("bounding", 2.7, 1.3, 0.75, 1.7, 12, 0, 0),
        "redFlankedBluetail" => new("bounding", 2.0, 0.9, 0.80, 1.7, 8, 0, 0),
        "collaredScopsOwl" => new("owl", 4.6, 4.0, 0.55, 1.7, 0, 0, 0),
        "asianBarredOwlet" => new("owl", 4.0, 3.5, 0.62, 1.8, 0, 0, 0),
        "littleOwl" => new("owl", 3.5, 2.8, 0.68, 1.8, 6, 0, 0),
        _ => throw new ArgumentOutOfRangeException(nameof(id), id, "Choose an explicit flight profile for each new species")
    };
    // Travel speed is independent of wingbeat cadence and orbit duration.
    public static double CruiseSpeed(string id,double multiplier=1) => Math.Max(130,720/Profile(id).Transit)*(CanGlide(id)?1.65:1.35)*multiplier;
    public static bool CanGlide(string id)=>Profile(id).Style is "raptor" or "soaring" or "owl" || id is "nightHeron" or "littleEgret" or "greyHeron" or "chinesePondHeron" or "largeBilledCrow" or "greatEgret" or "easternCattleEgret" or "carrionCrow" or "daurianJackdaw";
    public static bool ShouldGlide(string id,double age,double fps,double speed,double cruise,bool braking,bool wasGliding=false) {
        if(!CanGlide(id) || braking || age<.65)return false;
        var threshold=Math.Max(wasGliding?100:110,cruise*(wasGliding?.78:.90));
        if(speed<threshold)return false;
        var m=Profile(id);var rate=Math.Max(4,fps);var burst=Math.Max(8/rate,Math.Round(m.Cycle*m.Powered*rate/8,MidpointRounding.AwayFromZero)*8/rate);
        return Math.Max(0,age)%m.Cycle>=burst;
    }
    public static string Frame(string id,double age,double fps,bool gliding=false,double banking=0) {
        if(gliding && CanGlide(id)){if(Math.Abs(banking)>.3)return "bank"+(banking<0?0:2);return "glide1";}
        var t=CanGlide(id)?Math.Max(0,age)%Profile(id).Cycle:Math.Max(0,age);
        return "fly"+(((int)(t*Math.Max(4,fps))+3)%8);
    }
    // Independent axis samples, fixed for each flight. Airspace includes sprite margins.
    public static V OrbitRadii(double width,double height,double widthSample,double heightSample) {
        var x=Math.Max(0,width/2-4)*(.62+.38*Math.Clamp(widthSample,0,1));
        var upper=Math.Max(0,Math.Min(height/2-4,Math.Min(240,Math.Min(height*.3,x*.45))));
        var lower=Math.Min(upper,Math.Max(60,x*.22));
        return new(x,lower+(upper-lower)*Math.Clamp(heightSample,0,1));
    }
    public static FlightPath OrbitPath(double horizontal,double vertical)=>new(Enumerable.Range(0,2049).Select(i=>{var a=i*2*Math.PI/2048;return new V(-horizontal*Math.Cos(a),vertical*Math.Sin(a));}).ToArray());
    public static double TravelProgress(double t,double duration) {
        var u=Math.Clamp(t,0,1);var ramp=Math.Min(.1,.18/Math.Max(.01,duration));var area=1-ramp;
        if(u<ramp)return u*u/(2*ramp*area);
        if(u>1-ramp)return 1-Math.Pow(1-u,2)/(2*ramp*area);
        return (u-ramp/2)/area;
    }
}

// Arc-length lookup keeps equal time steps at equal distances on a curve.
public sealed class FlightPath {
    readonly V[] points;readonly double[] distances;
    public double Length=>distances[^1];
    public FlightPath(V[] points) {
        if(points.Length<2)throw new ArgumentException("A path needs two points");
        this.points=points;distances=new double[points.Length];
        for(var i=1;i<points.Length;i++)distances[i]=distances[i-1]+V.Distance(points[i-1],points[i]);
    }
    public FlightPath(V a,V b,V c,V d):this(Enumerable.Range(0,65).Select(i=>{
        var t=i/64d;var s=1-t;
        return new V(s*s*s*a.X+3*s*s*t*b.X+3*s*t*t*c.X+t*t*t*d.X,s*s*s*a.Y+3*s*s*t*b.Y+3*s*t*t*c.Y+t*t*t*d.Y);
    }).ToArray()){}
    public V LoopTangent(double progress) {
        var t=progress%1;var a=Point((t+1-.00001)%1);var b=Point((t+.00001)%1);var length=Math.Max(.000001,V.Distance(a,b));
        return new((b.X-a.X)/length,(b.Y-a.Y)/length);
    }
    public V Point(double progress) {
        var distance=Math.Clamp(progress,0,1)*Length;var lo=0;var hi=distances.Length-1;
        while(hi-lo>1){var mid=(lo+hi)/2;if(distances[mid]<distance)lo=mid;else hi=mid;}
        var t=(distance-distances[lo])/Math.Max(.0000001,distances[hi]-distances[lo]);
        return new(points[lo].X+(points[hi].X-points[lo].X)*t,points[lo].Y+(points[hi].Y-points[lo].Y)*t);
    }
}

// Velocity is planned independently of whether the renderer can glide.
public sealed class FlightTiming {
    public double Distance {get;} public double PeakSpeed {get;} public double Acceleration {get;} public double Deceleration {get;} public double Duration {get;}
    public double BrakeStart=>Duration-Deceleration;
    public FlightTiming(double distance,double speed,double acceleration=.65,double deceleration=.85) {
        Distance=Math.Max(0,distance);speed=Math.Max(1,speed);var rampDistance=speed*(acceleration+deceleration)/2;
        var factor=rampDistance>0?Math.Min(1,Math.Sqrt(Distance/rampDistance)):1;
        PeakSpeed=speed*factor;Acceleration=acceleration*factor;Deceleration=deceleration*factor;
        var ramps=Acceleration+Deceleration;
        Duration=Math.Max(.001,ramps+Math.Max(0,Distance-PeakSpeed*ramps/2)/Math.Max(.001,PeakSpeed));
    }
    public double Speed(double time) {
        var t=Math.Clamp(time,0,Duration);
        if(Acceleration>0 && t<Acceleration)return PeakSpeed*.5*(1-Math.Cos(Math.PI*t/Acceleration));
        if(Deceleration>0 && t>BrakeStart)return PeakSpeed*.5*(1+Math.Cos(Math.PI*(t-BrakeStart)/Deceleration));
        return PeakSpeed;
    }
    public double Progress(double time) {
        var t=Math.Clamp(time,0,Duration);if(t>=Duration || Distance<=0)return 1;
        if(Acceleration>0 && t<Acceleration)return PeakSpeed*.5*(t-Acceleration/Math.PI*Math.Sin(Math.PI*t/Acceleration))/Distance;
        if(Deceleration>0 && t>BrakeStart){var remaining=Duration-t;return 1-PeakSpeed*.5*(remaining-Deceleration/Math.PI*Math.Sin(Math.PI*remaining/Deceleration))/Distance;}
        return PeakSpeed*(t-Acceleration/2)/Distance;
    }
}
