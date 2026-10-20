import AppKit
import ImageIO
import BirdingCore

extension BirdArt {
    static func exportSpecies(to folder:URL) throws {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let profiles = SpeciesCatalog.standard.species
        let arts = profiles.map { BirdArt(species:$0.id) }
        for (i,p) in profiles.enumerated() { try arts[i].export(to:folder.appendingPathComponent(p.id.rawValue)) }
        func render(time:Double?, detail:Bool = false) -> NSBitmapImageRep {
            let width = 1200, height = 90 + ((profiles.count+4)/5)*230
            let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            let graphics = NSGraphicsContext(bitmapImageRep:rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
            let ctx = graphics.cgContext
            ctx.setFillColor(NSColor(calibratedRed:0.09,green:0.13,blue:0.16,alpha:1).cgColor)
            ctx.fill(CGRect(x:0,y:0,width:width,height:height))
            ctx.translateBy(x:0,y:CGFloat(height)); ctx.scaleBy(x:1,y:-1)
            func label(_ text:String,x:Double,y:Double,size:CGFloat = 16) {
                ctx.saveGState(); ctx.translateBy(x:x,y:y); ctx.scaleBy(x:1,y:-1)
                (text as NSString).draw(at:.zero,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:NSColor.white]); ctx.restoreGState()
            }
            label("啾啾 · 鸟种图鉴 / ChirpOS birds",x:24,y:40,size:23)
            label(detail ? "左：习性动作最大幅度 · 右：起始姿势" : "左：站立 / 习性动作 · 右：飞行 · 预览统一放大，实际体型按标注比例",x:24,y:72,size:14)
            for (i,p) in profiles.enumerated() {
                let cellX = Double((i%5)*240), cellY = Double((i/5)*230)+90
                let x = cellX+65, scale = 2.0
                let motion = SpeciesBehavior.motion(p.id)
                let age = motion.start + (time ?? 0)
                let pose = detail ? "idle2" : time.map { _ in SpeciesBehavior.frame(p.id,age:age) ?? "stand" } ?? "stand"
                let hop = time == nil ? 0 : SpeciesBehavior.hop(p.id,age:age)
                arts[i].draw(name:pose,at:CGPoint(x:x,y:cellY+100+hop*scale),scale:scale,right:true,context:ctx)
                ctx.setStrokeColor(NSColor(calibratedWhite:0.5,alpha:0.4).cgColor); ctx.setLineWidth(1)
                ctx.move(to:CGPoint(x:cellX+10,y:cellY+101)); ctx.addLine(to:CGPoint(x:cellX+110,y:cellY+101)); ctx.strokePath()
                let phase = time.map { Int($0*p.flapFPS)%8 } ?? 2
                arts[i].draw(name:detail ? "idle0" : "fly\(phase)",at:CGPoint(x:x+120,y:cellY+100),scale:scale,right:true,context:ctx)
                label(p.name,x:cellX+16,y:cellY+145)
                label(p.englishName ?? "",x:cellX+16,y:cellY+170,size:11)
                label(String(format:"%.1f cm · %.2f×",p.adultLengthCM,p.relativeScale),x:cellX+16,y:cellY+198,size:13)
            }
            NSGraphicsContext.restoreGraphicsState()
            return rep
        }
        try render(time:nil).representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("species-lineup.png"))
        try render(time:nil,detail:true).representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("species-actions.png"))
        let url = folder.appendingPathComponent("species-animations.gif")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,"com.compuserve.gif" as CFString,48,nil) else { throw NSError(domain:"Preview",code:1) }
        CGImageDestinationSetProperties(dest,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for f in 0..<48 {
            CGImageDestinationAddImage(dest,render(time:Double(f)*0.1).cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1,kCGImagePropertyGIFUnclampedDelayTime:0.1]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else { throw NSError(domain:"Preview",code:2) }
        // Checks actual RGBA images, not just the drawing definitions.
        var hashes = Set<Data>()
        for art in arts {
            let stand = art.frames["stand"]!.dataProvider!.data! as Data
            guard hashes.insert(stand).inserted else { throw NSError(domain:"Preview",code:3) }
            let flight = Set((0..<8).map { art.frames["fly\($0)"]!.dataProvider!.data! as Data })
            guard flight.count == 8 else { throw NSError(domain:"Preview",code:4) }
            let idle = Set((0..<3).map { art.frames["idle\($0)"]!.dataProvider!.data! as Data })
            guard idle.count == 3 else { throw NSError(domain:"Preview.Idle.\(art.species.rawValue)",code:6) }
            for image in art.frames.values {
                let bytes = [UInt8](image.dataProvider!.data! as Data)
                guard stride(from:3,to:bytes.count,by:4).filter({ bytes[$0] > 0 }).count > 100 else { throw NSError(domain:"Preview",code:5) }
            }
        }
        print("Species art: PASS — \(arts.count) distinct birds, \(arts.count*names.count) nonempty frames, \(arts.count*8) distinct flight poses")
    }
}
