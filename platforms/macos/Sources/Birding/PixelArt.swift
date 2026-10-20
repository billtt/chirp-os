import AppKit
import ImageIO
import BirdingCore

// Original 48×48 pixel drawings. Integer geometry, 17-color palette, no smoothing.
// Foot anchor is (29, 39) in every frame; animation never makes a perched bird skate.
struct PixelCanvas {
    static let size = 48
    var pixels = [UInt32](repeating: 0, count: 48*48)
    static let palette: [String: UInt32] = [
        "ink":0x20232CFF, "black":0x30333BFF, "crest":0x424752FF,
        "brown":0x68554CFF, "light":0x947760FF, "gold":0xB29575FF,
        "shadow":0x493F3DFF, "cream":0xECE4D0FF, "white":0xFFF5DFFF,
        "gray":0xB9B6A7FF, "red":0xD94B47FF, "bright":0xFF7861FF,
        "wine":0x8E343DFF, "feet":0xA78C7AFF, "eye":0x090E18FF,
        "shine":0xFFFFFFFF, "beak":0x555960FF]
    var colours = Self.palette
    mutating func dot(_ x: Int, _ y: Int, _ color: String) {
        if (0..<48).contains(x) && (0..<48).contains(y) { pixels[y*48+x] = colours[color]! }
    }
    mutating func box(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: String) {
        for py in y..<(y+h) { for px in x..<(x+w) { dot(px, py, c) } }
    }
    mutating func poly(_ points: [(Int,Int)], _ color: String) {
        for y in 0..<48 { for x in 0..<48 {
            let px = Double(x)+0.5, py = Double(y)+0.5
            var inside = false; var j = points.count-1
            for i in points.indices {
                let a = points[i], b = points[j]
                if (Double(a.1)>py) != (Double(b.1)>py),
                   px < Double(b.0-a.0)*(py-Double(a.1))/Double(b.1-a.1)+Double(a.0) { inside.toggle() }
                j = i
            }
            if inside { dot(x,y,color) }
        } }
    }
    var image: CGImage {
        var bytes = [UInt8](); bytes.reserveCapacity(48*48*4)
        for p in pixels { bytes += [UInt8((p>>24)&255), UInt8((p>>16)&255), UInt8((p>>8)&255), UInt8(p&255)] }
        let data = Data(bytes) as CFData
        return CGImage(width: 48, height: 48, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 192,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}

final class BirdArt {
    static let names = ["stand","breathe","blink","preen0","preen1","land0","land1","land2","fly0","fly1","fly2","fly3","fly4","fly5","fly6","fly7","idle0","idle1","idle2","stretch","shake","poop0","poop1","cling0","cling1","peck0","peck1"]
    let frames: [String: CGImage]
    let species: SpeciesID
    init(species: SpeciesID = .redWhiskeredBulbul) {
        self.species = species
        frames = Dictionary(uniqueKeysWithValues: Self.names.map {
            ($0, DetailedBirdArt.make($0, species: species))
        })
    }

    static func make(_ name: String) -> PixelCanvas {
        if name.hasPrefix("fly"), let phase = Int(name.dropFirst(3)) { return flight(phase) }
        var c = PixelCanvas()
        let phase = Int(name.last!.description) ?? 0
        let preen = name.hasPrefix("preen")
        let bob = name == "breathe" ? -1 : 0
        // Long, stepped tail with pale terminal feathers.
        c.poly([(20,28),(24,32),(10,44),(3,44),(7,38)], "ink")
        c.poly([(19,31),(21,33),(9,42),(5,42)], "brown")
        c.poly([(17,34),(18,35),(8,43),(6,43)], "light")
        c.box(4,42,4,2,"cream"); c.box(8,41,2,2,"gray")
        do {
            c.box(26,33,2,5,"ink"); c.box(31,33,2,5,"ink")
            c.box(27,35,1,3,"feet"); c.box(32,35,1,3,"feet")
            c.box(24,38,6,1,"ink"); c.box(30,38,6,1,"ink")
            c.dot(24,37,"feet"); c.dot(30,37,"feet")
        }
        // Pear-shaped body, red vent, warm white chest.
        c.poly([(26,17+bob),(32,18+bob),(36,25),(34,31),(30,35),(23,36),(17,32),(15,27),(19,21)], "ink")
        c.poly([(27,19+bob),(31,20+bob),(34,25),(33,30),(29,33),(23,34),(19,30),(19,24)], "cream")
        c.poly([(30,21),(33,24),(32,29),(29,31),(27,29),(27,23)], "white")
        c.poly([(22,28),(27,30),(30,32),(27,35),(22,34),(20,31)], "gray")
        c.poly([(21,32),(27,33),(26,36),(22,36),(19,34)], "wine")
        c.box(22,33,4,2,"red"); c.dot(23,33,"bright")
        // Folded wing: layered coverts and distinct primary feather tips.
        c.poly([(21,20+bob),(27,23+bob),(29,27),(24,33),(15,36),(17,30),(15,27),(17,23)], "shadow")
        c.poly([(20,21+bob),(25,23+bob),(26,27),(22,31),(17,33),(18,27)], "brown")
        c.poly([(19,23+bob),(23,23+bob),(25,26),(22,28),(18,29)], "light")
        c.box(20,23+bob,3,1,"gold"); c.box(18,26,3,1,"gold")
        c.poly([(25,27),(26,28),(19,33),(17,33)], "light")
        c.poly([(23,27),(24,28),(18,32),(17,32)], "shadow")
        // Upright black head and recognisable swept, pointed crest.
        let hx = preen ? -4 : 0, hy = preen ? 7 + phase : bob
        c.poly([(25+hx,16+hy),(24+hx,11+hy),(26+hx,7+hy),(26+hx,2+hy),(30+hx,6+hy),(32+hx,9+hy),(36+hx,10+hy),(38+hx,14+hy),(36+hx,19+hy),(31+hx,23+hy),(27+hx,21+hy)],"ink")
        c.poly([(27+hx,5+hy),(29+hx,8+hy),(28+hx,12+hy),(26+hx,13+hy),(26+hx,10+hy)],"crest")
        c.poly([(29+hx,11+hy),(34+hx,11+hy),(36+hx,13+hy),(34+hx,15+hy),(29+hx,15+hy)],"black")
        // White cheek remains below the eye; scarlet ear patch is behind it.
        c.poly([(29+hx,16+hy),(32+hx,16+hy),(35+hx,15+hy),(36+hx,17+hy),(33+hx,20+hy),(30+hx,20+hy),(28+hx,18+hy)],"white")
        c.box(27+hx,15+hy,3,3,"wine"); c.box(28+hx,15+hy,2,2,"red"); c.dot(28+hx,15+hy,"bright")
        c.poly([(29+hx,20+hy),(32+hx,21+hy),(31+hx,24+hy),(28+hx,22+hy),(26+hx,20+hy)],"black")
        c.poly([(36+hx,13+hy),(43+hx,15+hy),(37+hx,17+hy)],"ink")
        c.box(37+hx,14+hy,3,1,"beak")
        c.box(33+hx,13+hy,2,2,"eye")
        if name != "blink" && !preen { c.dot(34+hx,13+hy,"shine") }
        if name == "blink" { c.box(33,13+hy,2,1,"light") }
        // Landing frames keep the upright posture as the bird folds its wings.
        let wing = name == "land0" ? 1 : (name == "land1" ? 3 : -1)
        if wing == 0 || wing == 1 || wing == 5 {
            let lift = wing == 1 ? 0 : 5
            c.poly([(24,24),(16,19),(11,12+lift),(9,3+lift),(12,4+lift),(14,1+lift),(17,5+lift),(19,3+lift),(22,10+lift),(24,15)],"ink")
            c.poly([(23,22),(17,18),(13,11+lift),(13,6+lift),(16,10+lift),(17,7+lift),(21,14+lift)],"brown")
            c.poly([(21,20),(17,16),(15,10+lift),(18,13+lift),(21,15+lift)],"light")
            c.poly([(12,5+lift),(13,6+lift),(16,15),(15,15)],"gold")
        } else if wing == 2 || wing == 4 {
            c.poly([(25,24),(17,21),(9,22),(2,25),(4,28),(1,30),(5,31),(4,34),(12,32),(22,29)],"ink")
            c.poly([(23,25),(15,23),(8,25),(4,27),(12,27),(7,30),(15,29),(21,28)],"brown")
            c.poly([(22,25),(15,24),(8,26),(14,27),(20,27)],"light")
        } else if wing == 3 {
            c.poly([(24,24),(16,26),(12,33),(12,41),(15,40),(17,45),(20,43),(22,46),(25,37),(27,29)],"ink")
            c.poly([(23,27),(18,28),(15,34),(15,38),(18,36),(19,41),(22,36),(24,30)],"brown")
            c.poly([(22,28),(18,30),(17,35),(20,34),(22,31)],"light")
        }
        return c
    }
    // Flight is drawn independently from the upright perched silhouette.
    // A long horizontal body, tucked feet, fanned tail and two articulated wings.
    static func flight(_ phase: Int) -> PixelCanvas {
        var c = PixelCanvas()
        let bob = [1, 0, -1, -2, -1, 0, 1, 2][phase]
        let pitch = [0.06, 0.02, -0.04, -0.09, -0.06, 0.0, 0.05, 0.08][phase]
        func pose(_ p: (Int,Int)) -> (Int,Int) {
            let x = Double(p.0-27), y = Double(p.1-25)
            return (Int((27+x*cos(pitch)-y*sin(pitch)).rounded()),
                    Int((25+x*sin(pitch)+y*cos(pitch)).rounded())+bob)
        }
        func shape(_ points: [(Int,Int)], _ color: String) { c.poly(points.map(pose),color) }
        // Far wing is narrower and darker: it moves behind the shoulder and head.
        let farWings: [[(Int,Int)]] = [
            [(26,25),(24,14),(27,2),(29,5),(32,2),(33,8),(35,5),(35,15),(32,24)],
            [(26,24),(30,15),(38,9),(38,13),(43,11),(41,17),(44,17),(36,25)],
            [(25,24),(34,21),(44,22),(41,25),(46,26),(40,29),(32,28)],
            [(26,25),(35,30),(39,42),(35,40),(36,45),(31,41),(28,34)],
            [(26,25),(33,30),(34,38),(30,36),(27,32)],
            [(26,24),(34,24),(39,28),(35,30),(28,28)],
            [(26,25),(28,17),(33,13),(32,21),(30,25)],
            [(26,25),(25,14),(29,5),(31,9),(33,7),(32,19),(29,25)]
        ]
        shape(farWings[phase],"shadow")
        // Tail feathers flatten and fan during the power stroke, then close on recovery.
        let fan = [1,2,3,4,3,1,0,0][phase]
        shape([(20,25),(17,31),(2,33+fan),(3,30),(1,29-fan),(10,27),(15,24)],"ink")
        shape([(18,26),(17,29),(4,32+fan),(5,30),(3,29-fan),(12,28)],"brown")
        shape([(15,28),(6,30),(4,31+fan),(10,30)],"light")
        shape([(2,29-fan),(5,29-fan),(5,31-fan),(2,31-fan)],"cream")
        shape([(3,31+fan),(6,30+fan),(6,32+fan),(3,33+fan)],"white")
        // Stretched, gently pitching torso; belly contour changes with the wingbeat.
        let belly = [0,1,1,0,-1,-1,0,0][phase]
        shape([(16,25),(21,21),(29,20),(36,22),(38,25),(35,29),(29,32+belly),(22,32),(17,30)],"ink")
        shape([(18,26),(22,23),(29,22),(34,23),(35,26),(31,28),(23,29),(18,28)],"brown")
        shape([(20,24),(25,22),(31,22),(33,24),(26,25)],"light")
        shape([(22,28),(29,26),(35,24),(35,27),(30,30+belly),(24,31),(20,29)],"cream")
        shape([(28,27),(34,25),(33,28),(29,30)],"white")
        shape([(18,29),(23,30),(23,32),(18,32),(16,30)],"wine")
        shape([(18,30),(22,30),(21,32),(18,32)],"red")
        // Feet are swept back into the flank instead of hanging in the standing pose.
        shape([(25,31),(28,32),(24,33),(22,32)],"ink")
        shape([(24,31),(26,32),(23,32)],"feet")
        // Head extends forward; crest swept back. Red ear stays behind the bright eye.
        shape([(29,22),(28,18),(26,12),(31,15),(34,15),(38,16),(41,19),(41,23),(37,27),(33,26)],"ink")
        shape([(28,15),(32,17),(30,19)],"crest")
        shape([(32,17),(37,17),(39,19),(35,21),(31,20)],"black")
        shape([(34,22),(38,21),(40,22),(37,25),(34,25),(32,23)],"white")
        shape([(31,21),(34,21),(34,23),(31,24)],"wine")
        shape([(32,21),(34,21),(34,23),(32,23)],"red")
        let ear = pose((32,21)); c.dot(ear.0,ear.1,"bright")
        shape([(40,19),(47,21),(41,23)],"ink")
        shape([(41,20),(45,21),(41,21)],"beak")
        let eye = pose((37,19)); c.box(eye.0,eye.1,2,2,"eye"); c.dot(eye.0+1,eye.1,"shine")
        // Near wing: extended primaries on the downstroke, bent wrist on recovery.
        let wings: [[(Int,Int)]] = [
            [(28,25),(19,21),(12,12),(7,2),(11,3),(12,0),(16,3),(18,1),(21,6),(23,4),(26,13),(30,21)],
            [(28,25),(17,22),(7,17),(1,10),(6,10),(5,6),(11,9),(12,6),(18,12),(19,10),(26,17),(30,23)],
            [(29,24),(20,23),(12,23),(1,25),(4,28),(0,30),(5,31),(2,34),(9,34),(6,37),(16,34),(24,30)],
            [(28,23),(19,25),(13,32),(9,42),(13,41),(12,46),(16,44),(18,48),(21,44),(24,47),(27,39),(30,29)],
            [(28,24),(21,27),(18,33),(19,40),(22,38),(24,43),(26,39),(29,40),(31,33),(30,27)],
            [(28,24),(21,23),(16,26),(9,31),(12,33),(10,35),(17,34),(24,31),(30,28)],
            [(29,25),(21,23),(17,18),(17,11),(20,14),(22,11),(24,15),(28,17),(31,22)],
            [(28,25),(20,21),(15,14),(12,5),(15,6),(16,2),(20,6),(22,4),(24,11),(28,15),(30,22)]
        ]
        let outline = wings[phase]
        shape(outline,"ink")
        // Inset feather mass leaves a crisp one-pixel outline and separated feather tips.
        func inset(_ p: (Int,Int), _ amount: Double) -> (Int,Int) {
            (Int((27+Double(p.0-27)*amount).rounded()), Int((25+Double(p.1-25)*amount).rounded()))
        }
        shape(outline.map{inset($0,0.88)},"brown")
        shape(outline.map{inset($0,0.64)},"light")
        shape(outline.map{inset($0,0.38)},"gold")
        // Long primary shafts follow the fan instead of a static folded-wing patch.
        let featherTips: [[(Int,Int)]] = [
            [(11,4),(16,5),(21,7)],[(6,12),(11,11),(17,14)],[(5,28),(7,32),(11,34)],
            [(13,40),(17,42),(22,42)],[(21,36),(25,38)],[(14,31),(18,32)],[(20,16),(23,16)],[(16,8),(21,10)]
        ]
        for tip in featherTips[phase] {
            let root = inset(tip,0.32)
            shape([root,(root.0+1,root.1),tip,(tip.0-1,tip.1)],"shadow")
        }
        return c
    }

    func draw(name: String, at foot: CGPoint, scale: CGFloat, right: Bool, context: CGContext) {
        let image = frames[name] ?? frames["stand"]!
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: foot.x, y: foot.y)
        context.scaleBy(x: right ? scale : -scale, y: scale)
        // Context uses top-down geometry; invert only the bitmap itself.
        context.translateBy(x: -29, y: -39)
        context.translateBy(x: 0, y: 48); context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0,y: 0,width: 48,height: 48))
        context.restoreGState()
    }
    func exportFlightPreview(to folder: URL) throws {
        let url = folder.appendingPathComponent("flight-preview.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 8, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for phase in 0..<8 {
            let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:560,pixelsHigh:260,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            let graphics = NSGraphicsContext(bitmapImageRep:rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
            let ctx = graphics.cgContext
            ctx.setFillColor(NSColor(calibratedRed:0.09,green:0.13,blue:0.16,alpha:1).cgColor)
            ctx.fill(CGRect(x:0,y:0,width:560,height:260))
            ctx.translateBy(x:0,y:260); ctx.scaleBy(x:1,y:-1)
            draw(name:"fly\(phase)",at:CGPoint(x:110,y:149),scale:1,right:true,context:ctx)
            draw(name:"fly\(phase)",at:CGPoint(x:364,y:192),scale:4,right:true,context:ctx)
            for (label,x) in [("Desktop size · 1×",24.0),("Flight detail · 4×",272.0)] {
                ctx.saveGState(); ctx.translateBy(x:x,y:244); ctx.scaleBy(x:1,y:-1)
                (label as NSString).draw(at:.zero,withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.white])
                ctx.restoreGState()
            }
            NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination,rep.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.05,kCGImagePropertyGIFUnclampedDelayTime:0.05]] as CFDictionary)
        }
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain:"BirdArt",code:1,userInfo:[NSLocalizedDescriptionKey:"Cannot export flight preview"])
        }
    }

    func export(to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try exportFlightPreview(to:folder)
        for (name,image) in frames {
            let rep = NSBitmapImageRep(cgImage: image)
            try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name+".png"))
        }
        let width = 1152, height = ((Self.names.count+7)/8)*210+10
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
        let ctx = graphics.cgContext
        ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.16, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0,y: 0,width: width,height: height))
        ctx.translateBy(x: 0,y: CGFloat(height)); ctx.scaleBy(x: 1,y: -1)
        for (i,name) in Self.names.enumerated() {
            let x = CGFloat(i%8)*144, y = CGFloat(i/8)*210
            draw(name: name, at: CGPoint(x: x+82,y: y+166), scale: 3, right: true, context: ctx)
            ctx.saveGState(); ctx.translateBy(x: x+16,y: y+198); ctx.scaleBy(x: 1,y: -1)
            (name as NSString).draw(at: .zero, withAttributes: [.font:NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), .foregroundColor:NSColor.white])
            ctx.restoreGState()
        }
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("contact-sheet.png"))
    }
}
