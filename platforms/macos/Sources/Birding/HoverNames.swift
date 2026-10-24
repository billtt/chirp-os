import AppKit
import BirdingCore

extension BirdArt {
    func topPixel(frame:String) -> Int {
        for y in 0..<48 { if (0..<48).contains(where:{contains(frame:frame,x:$0,y:y)}) {return y} }
        return 0
    }
    func contains(frame:String,x:Int,y:Int) -> Bool {
        guard (0..<48).contains(x),(0..<48).contains(y),let image=frames[frame],
              let data=image.dataProvider?.data,let bytes=CFDataGetBytePtr(data) else {return false}
        let px=min(image.width-1,x*image.width/48),py=min(image.height-1,y*image.height/48)
        return bytes[py*image.bytesPerRow+px*4+3]>0
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
        let ready=hoverTracker.update(hit.map(ObjectIdentifier.init),now:now)
        hoveredBird=birds.first{ObjectIdentifier($0)==ready}
    }
}
