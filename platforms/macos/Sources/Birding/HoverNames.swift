import AppKit
import BirdingCore

extension BirdArt {
    func topPixel(frame:String) -> Int { topPixels[frame] ?? 0 }
    func contains(frame:String,x:Int,y:Int) -> Bool {
        guard (0..<48).contains(x), (0..<48).contains(y) else { return false }
        return hitMasks[frame]?[y*48+x] ?? false
    }
}
extension DesktopController {
    func feedbackScreen(for bird:Bird) -> CGRect {
        let point=NSPoint(x:bird.position.x,y:primaryHeight-bird.position.y)
        let frame=(NSScreen.screens.first{$0.frame.contains(point)} ?? NSScreen.main!).visibleFrame
        return CGRect(x:frame.minX,y:primaryHeight-frame.maxY,width:frame.width,height:frame.height)
    }
    func feedbackBounds(for bird:Bird) -> CGRect {
        let art=arts[bird.profile.id]!,scale=spriteScale(for:bird)
        let pixels=art.pixelBounds[bird.frameName]!.union(art.pixelBounds["stand"]!)
        let left=bird.facingRight ? pixels.minX : 48-pixels.maxX
        return CGRect(x:bird.position.x+(left-(bird.facingRight ? 29:19))*scale,
                      y:bird.position.y+(pixels.minY+bird.hopOffset-39)*scale,
                      width:pixels.width*scale,height:pixels.height*scale)
    }
    func updateHover(now:Double, at suppliedPoint:CGPoint? = nil) {
        let mouse=NSEvent.mouseLocation
        let point=suppliedPoint ?? CGPoint(x:mouse.x,y:primaryHeight-mouse.y)
        func hitBird(padding:CGFloat) -> Bird? {
            birds.reversed().first { bird in
                let s=spriteScale(for:bird)
                let x=(point.x-bird.position.x)/s+(bird.facingRight ? 29:19)
                let y=(point.y-bird.position.y)/s-bird.hopOffset+39
                let blockers=bird.blockers(in:surfaces)
                guard !blockers.contains(where:{$0.contains(point)}) else {return false}
                return SpriteHitTest.contains(x:x,y:y,radius:padding/s) { px,py in
                    guard arts[bird.profile.id]!.contains(frame:bird.frameName,x:bird.facingRight ? px:47-px,y:py) else {return false}
                    let sample=CGPoint(x:bird.position.x+(CGFloat(px)+0.5-(bird.facingRight ? 29:19))*s,
                                       y:bird.position.y+(CGFloat(py)+0.5+bird.hopOffset-39)*s)
                    return !blockers.contains(where:{$0.contains(sample)})
                }
            }
        }
        // Prefer a direct silhouette hit over a neighbour's expanded target.
        let hit=hitBird(padding:0) ?? (lifeList.enabled ? hitBird(padding:5) : nil)
        cameraBird=hit
        let ready=hoverTracker.update(lifeList.enabled ? nil : hit.map(ObjectIdentifier.init),now:now)
        hoveredBird=birds.first{ObjectIdentifier($0)==ready}
    }
}
