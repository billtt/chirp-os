namespace ChirpOS.Core;
public enum GalleryAction { Resting, Flying, Flapping, Gliding, Landing, Preening, Other }
public static class GalleryPose {
    public static string Frame(string id,double age,double fps,GalleryAction action=GalleryAction.Resting) {
        var t=Math.Max(0,age);var m=FlightBehavior.Profile(id);
        switch(action){
        case GalleryAction.Resting:return t%5>4.8?"blink":((int)(t*1.2)%2==0?"stand":"breathe");
        case GalleryAction.Flying:return FlightBehavior.Frame(id,t,fps,t<1,m.Orbit>0?Math.Cos(t*2*Math.PI/m.Period):0);
        case GalleryAction.Flapping:return FlightBehavior.Frame(id,t,fps,true);
        case GalleryAction.Gliding:return "glide1";
        case GalleryAction.Landing:return "land"+Math.Min(2,(int)((t%1.6)/.14));
        case GalleryAction.Preening:return "preen"+((int)(t*3)%2);
        case GalleryAction.Other:
            if(id=="nightHeron"){var u=t%8;if(u<2)return "stretch";if(u<3)return (int)(u*8)%2==0?"shake":"stand";if(u<4)return "poop"+((int)(u*6)%2);return "stand";}
            if(id=="greatSpottedWoodpecker")return t%4<2?"cling0":"peck"+((int)(t*12)%2);
            var motion=SpeciesBehavior.Profile(id);
            if(motion.Action is "tail" or "probe" or "dabble" or "call" or "glean" or "rock" or "hammer" or "crack" or "stalk" or "wing")return "idle"+new[]{0,1,2,1}[(int)(t*motion.Rate)%4];
            return Frame(id,t,fps,GalleryAction.Resting);
        default:return "stand";
        }
    }
}
