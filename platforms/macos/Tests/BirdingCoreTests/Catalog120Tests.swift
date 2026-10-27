import XCTest
@testable import BirdingCore

final class Catalog120Tests: XCTestCase {
    func testHundredSpeciesUpgradeAndAllocationPreservePreferences() throws {
        let previous=SpeciesCatalog(species:Array(SpeciesCatalog.standard.species.prefix(100)))
        var old=BirdSettings(catalog:previous)
        old.pendingSpecies=[]
        old.catalog.species[0].speed=1.35
        old.catalog.species[0].adultLengthCM=23
        old.probabilities.adjust(at:0,to:1234)
        old.probabilities.setLocked(true,at:0)
        var upgraded=try BirdSettings.decode(JSONEncoder().encode(old))
        let additions=Array(SpeciesCatalog.standard.species.suffix(20).map(\.id))
        XCTAssertEqual(upgraded.pendingSpecies,additions)
        XCTAssertEqual(upgraded.catalog.species.count,120)
        XCTAssertEqual(Array(upgraded.probabilities.entries.prefix(100)),old.probabilities.entries)
        XCTAssertEqual(upgraded.catalog.profile(.redWhiskeredBulbul).speed,1.35)
        XCTAssertEqual(upgraded.catalog.profile(.redWhiskeredBulbul).adultLengthCM,23)
        XCTAssertTrue(upgraded.probabilities.entries.suffix(20).allSatisfy{$0.points==0 && !$0.locked})
        XCTAssertEqual(try BirdSettings.decode(JSONEncoder().encode(upgraded)).pendingSpecies,additions)
        upgraded.probabilities.allocateNewSpecies(additions,catalog:.standard)
        XCTAssertEqual(upgraded.probabilities.entries.suffix(20).reduce(0){$0+$1.points},1667)
        XCTAssertEqual(upgraded.probabilities.entries.prefix(100).reduce(0){$0+$1.points},8333)
        XCTAssertTrue(upgraded.probabilities.entries[0].locked)
        XCTAssertTrue(upgraded.probabilities.isValid)
    }
    func testNewActionsAreAvailableInGalleryAndLargeBirdFitsLanding() throws {
        let catalog=SpeciesCatalog.standard
        for p in catalog.species.suffix(20) {
            let frames=Set((0..<300).map{GalleryPose.frame(p.id,age:Double($0)/30,fps:p.flapFPS,action:.other)})
            XCTAssertEqual(frames,Set(["idle0","idle1","idle2"]),p.id.rawValue)
            XCTAssertFalse(FlightBehavior.canGlide(p.id),p.id.rawValue)
            XCTAssertFalse((p.appearanceNotes ?? "").isEmpty)
        }
        let crane=catalog.profile(.redCrownedCrane)
        XCTAssertEqual(crane.adultLengthCM,145)
        XCTAssertGreaterThan(crane.relativeScale,catalog.profile(.himalayanVulture).relativeScale)
        XCTAssertEqual(try SpeciesCatalog.decode(JSONEncoder().encode(catalog)).profile(.redCrownedCrane),crane)
        let host=Surface(id:1,rect:CGRect(x:0,y:400,width:1000,height:300))
        let cover=Surface(id:2,rect:CGRect(x:555,y:240,width:100,height:160))
        XCTAssertTrue(Geometry.isLandingVisible(on:1,at:CGPoint(x:500,y:400),surfaces:[host],scale:crane.relativeScale))
        XCTAssertFalse(Geometry.isLandingVisible(on:1,at:CGPoint(x:500,y:400),surfaces:[cover,host],scale:crane.relativeScale))
        var invalid=catalog
        invalid.species[0].adultLengthCM=161
        XCTAssertThrowsError(try SpeciesCatalog.decode(JSONEncoder().encode(invalid)))
    }
}
