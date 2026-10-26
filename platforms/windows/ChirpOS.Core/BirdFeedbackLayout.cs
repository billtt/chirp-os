namespace ChirpOS.Core;

public static class BirdFeedbackLayout {
    // Keep the label above the bird. Screen edges may clip it, never move it sideways or down.
    public static Box Label(Box bird,Box screen,double width,double height,double clearance=8) {
        width=Math.Min(width,screen.W);
        var x=Math.Clamp(bird.X+bird.W/2-width/2,screen.X,screen.Right-width);
        return new(x,bird.Y-clearance-height,width,height);
    }
}
