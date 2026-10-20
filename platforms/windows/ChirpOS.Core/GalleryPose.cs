namespace ChirpOS.Core;
public static class GalleryPose {
    public static string Frame(string id,double age,double fps) {
        var phases=new List<(double Duration,string[] Frames,double Rate)>{(2,["stand","breathe"],1.8),(.4,["blink"],1),(3,Enumerable.Range(0,8).Select(i=>"fly"+i).ToArray(),fps),(.42,["land0","land1","land2"],1/.14),(3,["idle0","idle1","idle2","idle1"],SpeciesBehavior.Profile(id).Rate),(2,["preen0","preen1"],4)};
        if(id=="nightHeron")phases.AddRange([(2,["stretch"],1),(1,["shake","stand"],8),(1,["poop0","poop1"],6)]);
        if(id=="greatSpottedWoodpecker")phases.AddRange([(2,["cling0"],1),(2,["peck0","peck1"],12)]);
        var t=Math.Max(0,age)%phases.Sum(p=>p.Duration);
        foreach(var p in phases){if(t<p.Duration)return p.Frames[(int)(t*p.Rate)%p.Frames.Length];t-=p.Duration;}return "stand";
    }
}
