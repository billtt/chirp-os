import AppKit
import BirdingCore

extension BirdArt {
    /// Tests the final RGBA composites, including geometry that can otherwise be
    /// drawn successfully and then completely hidden by a later body/wing pass.
    static func verifyArt(to folder:URL) throws {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        BirdPainter.verifyPigmentBounds=true
        BirdPainter.verifiedPigmentPasses=0
        defer {
            BirdPainter.verifyPigmentBounds=false
            BirdPlumage.omitFlightFeetForVerification=false
        }
        var failures:[String]=[], rows:[[String:Any]]=[], stands=Set<Data>()
        let flightNames=names.filter { $0.hasPrefix("fly") || $0.hasPrefix("glide") || $0.hasPrefix("bank") || $0 == "bound" }
        for profile in SpeciesCatalog.standard.species {
            let art=BirdArt(species:profile.id)
            let id=profile.id.rawValue
            func bytes(_ image:CGImage)->[UInt8] { [UInt8](image.dataProvider!.data! as Data) }
            let stand=art.frames["stand"]!.dataProvider!.data! as Data
            if !stands.insert(stand).inserted {failures.append("\(id): duplicate standing art")}
            if stand != art.frames["land2"]!.dataProvider!.data! as Data {failures.append("\(id): final landing frame differs from standing")}
            let landing=Set((0...2).map {art.frames["land\($0)"]!.dataProvider!.data! as Data})
            if landing.count != 3 {failures.append("\(id): missing closing-wing transition")}
            let flight=Set((0..<8).map {art.frames["fly\($0)"]!.dataProvider!.data! as Data})
            if flight.count != 8 {failures.append("\(id): repeated wingbeat frame")}
            let idle=Set((0..<3).map {art.frames["idle\($0)"]!.dataProvider!.data! as Data})
            if idle.count != 3 {failures.append("\(id): repeated species action frame")}
            for (frame,image) in art.frames {
                let pixels=bytes(image), size=image.width, stride=image.bytesPerRow
                let ink=(0..<size).reduce(0) {total,y in total+(0..<size).filter {pixels[y*stride+$0*4+3]>0}.count}
                if ink <= 100 {failures.append("\(id)/\(frame): empty silhouette")}
                let edge=(0..<size).contains { i in
                    pixels[i*4+3]>0 || pixels[(size-1)*stride+i*4+3]>0 || pixels[i*stride+3]>0 || pixels[i*stride+(size-1)*4+3]>0
                }
                if edge {failures.append("\(id)/\(frame): silhouette touches atlas edge")}
            }
            var exposed:[String:Int]=[:]
            for frame in flightNames {
                BirdPlumage.omitFlightFeetForVerification=true
                let without=DetailedBirdArt.make(frame,species:profile.id)
                BirdPlumage.omitFlightFeetForVerification=false
                let a=bytes(art.frames[frame]!), b=bytes(without)
                // Count silhouette pixels, not merely foot-coloured pixels
                // painted on the abdomen. A fully covered foot scores zero.
                exposed[frame]=stride(from:3,to:a.count,by:4).filter {a[$0]>0 && b[$0]==0}.count
            }
            let visible=exposed.values.filter {$0>0}.count
            // Upstrokes expose tucked toes. A downstroke can naturally cover
            // them, so do not force toes to be painted over the near wing.
            if (exposed["fly0"] ?? 0)==0 || (exposed["fly7"] ?? 0)==0 {
                failures.append("\(id): flight feet hidden (\(visible)/\(flightNames.count) poses)")
            }
            if [.ruddyShelduck,.easternSpotBilledDuck,.mallard,.greatCrestedGrebe,.littleGrebe].contains(profile.id) && visible != flightNames.count {
                failures.append("\(id): trailing aquatic feet obscured")
            }
            rows.append(["id":id,"name":profile.name,"visibleFeet":exposed])
        }
        let report:[String:Any]=["passed":failures.isEmpty,"species":rows,"frames":rows.count*names.count,
                                "pigmentPasses":BirdPainter.verifiedPigmentPasses,"failures":failures]
        let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try data.write(to:folder.appendingPathComponent("art-report.json"))
        for failure in failures { print(failure) }
        print("Art verification: \(failures.isEmpty ? "PASS":"FAIL") — \(rows.count) birds, \(rows.count*names.count) frames, \(BirdPainter.verifiedPigmentPasses) clipped colour passes")
        if !failures.isEmpty {throw NSError(domain:"ArtVerification",code:1)}
    }
}
