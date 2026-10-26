using ChirpOS.Core;

internal static class CirclingChecks {
    internal static int Run(Species[] species) {
        var count=0;
        void Check(bool passed,string label){if(!passed)throw new Exception("Circling: "+label);count++;}
        var rng=new Random(17);
        var host=new Surface(1,new(100,500,900,300));var airspace=new Box(80,120,1000,650);
        var bird=new Bird(species.Single(p=>p.Id=="commonBuzzard"),new(200,420),rng);
        var selected=0;
        for(var sample=0;sample<100;sample++) {
            var draws=0;var circled=false;
            bird.Fly(new(700,500),host,airspace:airspace,random:()=>++draws==1?sample/100d:.5);
            for(var i=0;i<=(int)Math.Ceiling(bird.FlightDuration*60);i++){bird.Tick(1d/60);circled|=bird.IsCircling;}
            Check(circled==(sample<20) && draws==(circled?3:1),"occasional selection clears previous orbit and samples once");
            Check(bird.State==BirdState.Landing,"selected and skipped orbits both land");
            if(circled)selected++;
        }
        Check(selected==20,"twenty percent of evenly spaced samples circle");
        foreach(var id in new[]{"treeSparrow","commonBuzzard"}) {
            var b=new Bird(species.Single(p=>p.Id==id),new(200,420),rng);
            b.Fly(new(700,500),host,airspace:airspace,urgent:id=="commonBuzzard",random:()=>throw new Exception("Ineligible or urgent flight sampled an orbit"));
            var circled=false;
            for(var i=0;i<=(int)Math.Ceiling(b.FlightDuration*60);i++){b.Tick(1d/60);circled|=b.IsCircling;}
            Check(!circled,"ineligible and urgent flights never circle");
        }
        foreach(var profile in species.Where(p=>FlightBehavior.Profile(p.Id).Orbit>0))
        foreach(var width in new[]{100d,600,1800})
        foreach(var speed in new[]{.3,1d,3d}) {
            var area=new Box(-width,-900,width,900);var start=new V(-width/2,-450);var end=new V(start.X+10,start.Y);
            var b=new Bird(profile with {Speed=speed},start,rng);
            b.Fly(end,null,airspace:area,random:()=>0);
            var radii=FlightBehavior.OrbitRadii(width,900,0,0);
            var circumference=FlightBehavior.OrbitPath(radii.X,radii.Y).Length;
            var distance=0d;var seconds=0d;var previous=b.Position;var wasCircling=false;
            for(var i=0;i<=(int)Math.Ceiling(b.FlightDuration*960);i++) {
                b.Tick(1d/960);
                if(b.IsCircling)seconds+=1d/960;
                if(wasCircling && b.IsCircling)distance+=V.Distance(previous,b.Position);
                previous=b.Position;wasCircling=b.IsCircling;
            }
            Check(seconds>0 && seconds<=FlightBehavior.Profile(profile.Id).Orbit+1d/960,profile.Id+" respects duration limit");
            Check(distance/circumference<=2,profile.Id+" travels no more than two laps");
            if(width==100 && speed==3)Check(distance/circumference>1.98,profile.Id+" reaches lap cap on small fast orbit");
            Check(V.Distance(b.Position,end)<.001,profile.Id+" lands after capped orbit");
        }
        return count;
    }
}
