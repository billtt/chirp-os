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
    func updateHover(now:Double, at suppliedPoint:CGPoint? = nil) {
        let mouse=NSEvent.mouseLocation
        let point=suppliedPoint ?? CGPoint(x:mouse.x,y:primaryHeight-mouse.y)
        let hit=birds.reversed().first { bird in
            let s=spriteScale(for:bird)
            let x=(point.x-bird.position.x)/s+(bird.facingRight ? 29:19)
            let y=(point.y-bird.position.y)/s-bird.hopOffset+39
            guard x>=0,x<48,y>=0,y<48,
                  !bird.blockers(in:surfaces).contains(where:{$0.contains(point)}) else {return false}
            return arts[bird.profile.id]!.contains(frame:bird.frameName,x:bird.facingRight ? Int(x):47-Int(x),y:Int(y))
        }
        cameraBird=hit
        let ready=hoverTracker.update(lifeList.enabled ? nil : hit.map(ObjectIdentifier.init),now:now)
        hoveredBird=birds.first{ObjectIdentifier($0)==ready}
    }
}
