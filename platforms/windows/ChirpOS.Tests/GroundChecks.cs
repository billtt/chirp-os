using ChirpOS.Core;

internal static class GroundChecks {
    internal static int Run(Species[] species) {
        var count=0;void Check(bool passed,string label){if(!passed)throw new Exception("Ground: "+label);count++;}
        var display=new Box(-1200,-300,1200,900);var work=new Box(-1200,-275,1200,815);
        var ground=Geometry.Ground(-1,display,work);var window=new Surface(1,display);
        foreach(var layout in new[]{work,display,new Box(-1120,-275,1120,875),new Box(-1200,-220,1200,820)})foreach(var scale in new[]{1d,2.5,3.75}) {
            var floor=Geometry.Ground(-1,display,layout);var ranges=Geometry.LandingRanges(floor,[floor],display,scale,[]);
            Check(ranges.Count>0,"bottom, side and hidden taskbars have landing room");
            var y=Geometry.Foot(floor,.5,scale:scale).Y;
            Check(y==Math.Min(layout.Bottom,display.Bottom-9*scale) && ranges.All(q=>display.Contains(Geometry.Landing(new(q.Lo,y),scale)) && display.Contains(Geometry.Landing(new(q.Hi,y),scale))),"full sprite remains inside display");
        }
        var foot=Geometry.Foot(ground,.5);
        var taskbar=new Surface(3,new(display.X,work.Bottom,display.W,display.Bottom-work.Bottom),Topmost:true,CanPerch:false,IsTaskbar:true);
        Check(Geometry.LandingRanges(ground,[taskbar,window,ground],display,1,[]).Count>0 && Geometry.Visible(ground.Id,foot,[taskbar,window,ground],1),"real taskbar supports rather than rejects a landing");
        var standing=new Bird(species[0],foot,new Random(1));standing.Perch(ground);
        Check(standing.Blockers([taskbar,window,ground]).SequenceEqual(new[]{taskbar.Rect}),"taskbar masks only the sprite pixels behind the bar");
        Check(Geometry.LandingRanges(window,[window,ground],display,1,[]).Count==0 && Geometry.LandingRanges(ground,[window,ground],display,1,[]).Count>0,"maximized window falls back to ground");
        Check(Geometry.Visible(ground.Id,foot,[window,ground],1),"normal windows do not invalidate ground");
        var reservation=Geometry.Landing(foot,2);reservation=new(reservation.X-8,reservation.Y-8,reservation.W+16,reservation.H+16);
        var available=Geometry.LandingRanges(ground,[window,ground],display,1,[reservation]);
        Check(available.Count>0 && !available.Any(q=>q.Lo<=foot.X && q.Hi>=foot.X),"ground birds reserve space");
        var panel=new Surface(2,reservation,Topmost:true);
        Check(!Geometry.Visible(ground.Id,foot,[window,panel,ground],1),"utility panels still cover ground birds");
        Check(!Geometry.Blockers(window,[ground,window]).Any(),"virtual floor never masks other birds");
        var rng=new Random(14);
        foreach(var profile in species){
            var bird=new Bird(profile,new(-1000,-100),rng);var end=Geometry.Foot(ground,.5,scale:profile.Scale);
            bird.Fly(end,ground,airspace:display,random:()=>.5);bird.Tick(bird.FlightDuration);
            Check(bird.State==BirdState.Landing,"each species lands on ground");bird.Tick(.5);
            Check(bird.State==BirdState.Perched && V.Distance(bird.Position,end)<.001 && !bird.NeedsDestination,"each species rests after landing");
            bird.Tick(bird.PerchDuration-.1);Check(!bird.NeedsDestination,"ground keeps configured perch duration");bird.Tick(.2);Check(bird.NeedsDestination,"ground resting eventually permits another flight");
        }
        var resting=new Bird(species[0],new(0,0),rng);resting.Perch(ground,2.5);var hidden=Geometry.Ground(-1,display,display);
        resting.UpdateHost([hidden],.03,2.5);
        Check(resting.State==BirdState.Perched && resting.Startles==0 && resting.Position==Geometry.Foot(hidden,.5,scale:2.5),"auto-hide does not startle ground bird");
        resting.UpdateHost([ground],.03,2.5);Check(resting.State==BirdState.Perched && resting.Position.Y==ground.Rect.Y,"taskbar reappearance updates ground");
        resting.UpdateHost([],.03,2.5);resting.Tick(resting.FlightDuration);Check(resting.Host==null && resting.NeedsDestination,"removed display releases its bird");
        var approach=new Bird(species[0],new(-800,100),rng);approach.Fly(Geometry.Foot(ground,.5,scale:2),ground);approach.Tick(.2);approach.UpdateHost([hidden],.03,2);approach.Tick(approach.FlightDuration);
        Check(approach.State==BirdState.Landing && approach.Position==Geometry.Foot(hidden,.5,scale:2),"work-area changes update approach target");
        var wood=new Bird(species.Single(x=>x.Id=="greatSpottedWoodpecker"),new(0,0),rng){Edge=PerchEdge.Left};wood.Perch(ground);
        Check(wood.Edge==PerchEdge.Top && !wood.Frame.StartsWith("cling") && Geometry.SideRanges(ground,PerchEdge.Left,[ground],display,1,[]).Count==0,"woodpecker stands on ground");
        Console.WriteLine($"{count} ground checks passed.");return count;
    }
}
