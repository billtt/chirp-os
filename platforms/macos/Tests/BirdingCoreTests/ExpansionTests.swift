import XCTest
@testable import BirdingCore

final class ExpansionTests:XCTestCase {
    func testOldSettingsPreserveLockedProbabilityAndCustomBehavior() throws {
        var obj=try JSONSerialization.jsonObject(with:JSONEncoder().encode(BirdSettings())) as! [String:Any]
        var catalog=obj["catalog"] as! [String:Any]
        var old=Array((catalog["species"] as! [[String:Any]]).prefix(7));old[0]["adultLengthCM"]=21
        catalog["species"]=old;obj["catalog"]=catalog
        var entries=old.map{["id":$0["id"]!,"points":0,"locked":false] as [String:Any]}
        entries[0]["points"]=10000;entries[0]["locked"]=true;obj["probabilities"]=["entries":entries]
        let upgraded=try BirdSettings.decode(JSONSerialization.data(withJSONObject:obj))
        XCTAssertEqual(upgraded.pendingSpecies?.count,39)
        XCTAssertEqual(upgraded.catalog.species.count,46)
        XCTAssertEqual(upgraded.catalog.profile(.redWhiskeredBulbul).adultLengthCM,21)
        XCTAssertEqual(upgraded.probabilities.entries[0].points,10000)
        XCTAssertTrue(upgraded.probabilities.entries[0].locked)
        XCTAssertTrue(upgraded.probabilities.entries.dropFirst(7).allSatisfy{$0.points==0 && !$0.locked})
        XCTAssertTrue(upgraded.probabilities.isValid)
    }

    func testNewSpeciesAllocationAndPendingPersistence() throws {
        var settings=BirdSettings()
        let ids=Array(settings.catalog.species.dropFirst(7).map(\.id))
        settings.pendingSpecies=ids
        settings.probabilities.adjust(at:0,to:10000)
        settings.probabilities.setLocked(true,at:0)
        settings.probabilities.allocateNewSpecies(ids,catalog:.standard)
        XCTAssertTrue(settings.probabilities.isValid)
        XCTAssertEqual(settings.probabilities.entries.prefix(7).reduce(0){$0+$1.points},1522)
        XCTAssertEqual(settings.probabilities.entries.dropFirst(7).reduce(0){$0+$1.points},8478)
        XCTAssertTrue(settings.probabilities.entries[0].locked)
        let restored=try BirdSettings.decode(JSONEncoder().encode(settings))
        XCTAssertEqual(restored.pendingSpecies,ids)
        settings.pendingSpecies=[]
        XCTAssertEqual(try BirdSettings.decode(JSONEncoder().encode(settings)).pendingSpecies,[])
    }
    func testExisting43SpeciesGainOnlyThreePendingOwls() throws {
        let owls:Set<SpeciesID> = [.collaredScopsOwl,.asianBarredOwlet,.littleOwl]
        let oldCatalog = SpeciesCatalog(species: SpeciesCatalog.standard.species.filter { !owls.contains($0.id) })
        var old = BirdSettings(catalog: oldCatalog)
        old.pendingSpecies = []
        old.probabilities.adjust(at: 0, to: 1234)
        old.probabilities.setLocked(true, at: 0)
        let upgraded = try BirdSettings.decode(JSONEncoder().encode(old))
        XCTAssertEqual(old.catalog.species.count, 43)
        XCTAssertEqual(upgraded.catalog.species.count, 46)
        XCTAssertEqual(Set(upgraded.pendingSpecies ?? []), owls)
        XCTAssertEqual(Array(upgraded.probabilities.entries.prefix(43)), old.probabilities.entries)
        XCTAssertTrue(upgraded.probabilities.entries.suffix(3).allSatisfy { $0.points == 0 && !$0.locked })
        XCTAssertTrue(upgraded.probabilities.isValid)
        XCTAssertEqual(try BirdSettings.decode(JSONEncoder().encode(upgraded)).pendingSpecies, upgraded.pendingSpecies)
        var allocated = upgraded
        allocated.probabilities.allocateNewSpecies(Array(owls), catalog: .standard)
        XCTAssertEqual(allocated.probabilities.entries.suffix(3).reduce(0) { $0 + $1.points }, 652)
        XCTAssertTrue(allocated.probabilities.isValid)
        XCTAssertTrue(allocated.probabilities.entries[0].locked)
    }

    func testGalleryCyclesSpecialAndStandardActions() {
        let night=Set((0..<1200).map{GalleryPose.frame(.nightHeron,age:Double($0)/30,fps:20)})
        for frame in ["stand","blink","fly0","fly7","land2","idle1","preen1","stretch","shake","poop0","poop1"] {XCTAssertTrue(night.contains(frame),frame)}
        let wood=Set((0..<1200).map{GalleryPose.frame(.greatSpottedWoodpecker,age:Double($0)/30,fps:24)})
        XCTAssertTrue(wood.contains("cling0") && wood.contains("peck0") && wood.contains("peck1"))
    }
    func testHoverRequiresContinuousIdentityAndResetsOnExit() {
        var h=HoverTracker<Int>()
        XCTAssertNil(h.update(1,now:10));XCTAssertNil(h.update(1,now:10.99))
        XCTAssertEqual(h.update(1,now:11),1)
        XCTAssertNil(h.update(2,now:13.1));XCTAssertNil(h.update(nil,now:14))
        XCTAssertNil(h.update(2,now:17));XCTAssertEqual(h.update(2,now:20),2)
    }
    func testNightHeronWatchAndBriefActions() {
        XCTAssertEqual(SpeciesBehavior.frame(.nightHeron,age:12),"stand")
        XCTAssertEqual(SpeciesBehavior.frame(.nightHeron,age:21),"stretch")
        XCTAssertTrue(SpeciesBehavior.frame(.nightHeron,age:31.4)!.hasPrefix("poop"))
        XCTAssertEqual(SpeciesBehavior.frame(.nightHeron,age:33),"stand")
        XCTAssertGreaterThanOrEqual(SpeciesCatalog.standard.profile(.nightHeron).perchMin,53)
    }
    func testSidePerchTracksResizeAndFacesHost() {
        let host=Surface(id:1,rect:CGRect(x:300,y:100,width:500,height:600))
        let bird=Bird(position:.zero,fraction:0.5,profile:SpeciesCatalog.standard.profile(.greatSpottedWoodpecker))
        bird.edge = .right;bird.perch(on:host)
        XCTAssertEqual(bird.position,CGPoint(x:800,y:400));XCTAssertFalse(bird.facingRight)
        var resized=host;resized.rect.size.width+=30
        bird.updateHost(surfaces:[resized],sampleDT:0.033)
        XCTAssertEqual(bird.position.x,830);XCTAssertEqual(bird.state,.perched)
        bird.tick(4.2);XCTAssertTrue(bird.frameName.hasPrefix("peck"))
        bird.fly(to:CGPoint(x:830,y:200),host:resized);XCTAssertNil(bird.depthID)
    }
    func testSideRangesRejectOcclusionAndReserveSpace() {
        let host=Surface(id:1,rect:CGRect(x:300,y:100,width:500,height:600))
        let cover=Surface(id:2,rect:CGRect(x:250,y:200,width:100,height:180))
        let screen=CGRect(x:0,y:0,width:1200,height:900)
        let ranges=Geometry.sideRanges(on:host,edge:.left,surfaces:[cover,host],screen:screen,scale:1,occupied:[])
        XCTAssertFalse(ranges.isEmpty)
        for r in ranges {for y in stride(from:r.lowerBound+0.1,to:r.upperBound,by:5) {
            XCTAssertFalse(Geometry.landingFootprint(at:CGPoint(x:300,y:y),scale:1).intersects(cover.rect))
        }}
        XCTAssertTrue(Geometry.sideRanges(on:host,edge:.left,surfaces:[host],screen:screen,scale:1,occupied:[host.rect.insetBy(dx:-100,dy:-100)]).isEmpty)
    }
}
