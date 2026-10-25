import AppKit
import BirdingCore

extension BirdArt {
    static func exportShared(to folder:URL) throws {
        try FileManager.default.createDirectory(at:folder.appendingPathComponent("art"),withIntermediateDirectories:true)
        let catalog = SpeciesCatalog.standard
        try JSONEncoder().encode(catalog).write(to:folder.appendingPathComponent("species.json"))
        for profile in catalog.species {
            let art = BirdArt(species:profile.id)
            let size=art.frames["stand"]!.width
            let ctx = CGContext(data:nil,width:size*names.count,height:size,bitsPerComponent:8,bytesPerRow:0,
                                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.interpolationQuality = .none
            for (i,name) in names.enumerated() { ctx.draw(art.frames[name]!,in:CGRect(x:i*size,y:0,width:size,height:size)) }
            let rep = NSBitmapImageRep(cgImage:ctx.makeImage()!)
            try rep.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("art/\(profile.id.rawValue).png"))
        }
        let metadata:[String:Any] = ["schemaVersion":2,"logicalFrameSize":48,"frameSizes":Dictionary(uniqueKeysWithValues:catalog.species.map{($0.id.rawValue,BirdArt(species:$0.id).frames["stand"]!.width)}),"footAnchor":[29,39],"frames":names,
                                    "source":"platforms/macos/Sources/Birding/{PixelArt,SpeciesArt,DetailedBirdArt,ExpansionBirdArt}.swift"]
        try JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("art/manifest.json"))
    }
}
