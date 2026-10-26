import Foundation

public enum BirdFeedbackLayout {
    /// Stay above the bird even at the screen edge; overflowing pixels are clipped.
    public static func label(bird:CGRect,screen:CGRect,size:CGSize) -> CGRect {
        let width=min(size.width,screen.width)
        let x=min(screen.maxX-width,max(screen.minX,bird.midX-width/2))
        return CGRect(x:x,y:bird.minY-8-size.height,width:width,height:size.height)
    }
}
