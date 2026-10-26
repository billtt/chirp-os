namespace ChirpOS.Core;

public static class ObservationHearts {
    public const int Count=3;
    public const double Duration=1.2;
    public static (double X,double Y,double Size,double Opacity) Particle(int index,double age) {
        var pop=Math.Clamp((age-index*.035)/.24,0,1);var t=pop-1;
        var growth=1+2.70158*t*t*t+1.70158*t*t;
        var flight=Math.Clamp((age-.38)/(Duration-.38),0,1);
        var rise=42*flight*flight*(3-2*flight);
        return((index-1)*18,(index==1?7:0)+rise,(index==1?13:10)*growth,Math.Min(1,pop*4)*Math.Clamp((Duration-age)/.4,0,1));
    }
    public static double Clearance(double scale)=>Math.Max(10,6*scale);
    // Initial pop: center offset (7), pop overshoot (<15), and an 8-point gap.
    // Do not reserve space for the hearts’ later upward travel.
    public static double LabelClearance(double scale)=>Clearance(scale)+30;
}

public sealed class ObservationInteraction<T> where T:notnull {
    public const double Duration=1.2;
    sealed class State {
        public double LabelUntil=double.NegativeInfinity, HeartsUntil=double.NegativeInfinity;
        public readonly List<double> Clicks=[];
    }
    readonly Dictionary<T,State> states=[];
    public void Reset()=>states.Clear();
    public void Retain(IEnumerable<T> visits) {
        var live=visits.ToHashSet();
        foreach(var key in states.Keys.Where(key=>!live.Contains(key)).ToArray())states.Remove(key);
    }
    public (bool Label,bool Hearts) Click(T visit,double now) {
        if(!states.TryGetValue(visit,out var state))states[visit]=state=new();
        state.Clicks.RemoveAll(time=>now-time>=Duration);state.Clicks.Add(now);
        var label=now>=state.LabelUntil;
        var hearts=state.Clicks.Count>=2 && now>=state.HeartsUntil;
        if(label)state.LabelUntil=now+Duration;
        if(hearts){state.HeartsUntil=now+Duration;state.Clicks.Clear();}
        return(label,hearts);
    }
}

public static class SpriteHitTest {
    // Coordinates and radius are in source pixels, converted from screen pixels by the caller.
    public static bool Contains(double x,double y,double radius,Func<int,int,bool> pixel) {
        if(x< -radius || x>=48+radius || y< -radius || y>=48+radius)return false;
        var left=Math.Max(0,(int)Math.Floor(x-radius));var right=Math.Min(47,(int)Math.Floor(x+radius));
        var top=Math.Max(0,(int)Math.Floor(y-radius));var bottom=Math.Min(47,(int)Math.Floor(y+radius));
        for(var py=top;py<=bottom;py++)for(var px=left;px<=right;px++) {
            var dx=Math.Max(px-x,Math.Max(0,x-px-1));var dy=Math.Max(py-y,Math.Max(0,y-py-1));
            if(dx*dx+dy*dy<=radius*radius && pixel(px,py))return true;
        }
        return false;
    }
}
