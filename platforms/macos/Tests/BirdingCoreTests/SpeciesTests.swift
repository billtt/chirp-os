import XCTest
@testable import BirdingCore

final class SpeciesTests: XCTestCase {
    func data(_ edit: (inout [[String:Any]])->Void) throws -> Data {
        let source = try JSONEncoder().encode(SpeciesCatalog.standard)
        var obj = try JSONSerialization.jsonObject(with:source) as! [String:Any]
        var birds = obj["species"] as! [[String:Any]]; edit(&birds); obj["species"] = birds
        return try JSONSerialization.data(withJSONObject:obj)
    }
    func testRejectInvalidConfiguration() throws {
        for key in ["adultLengthCM","weight","flapFPS","speed","perchMin","perchMax"] {
            XCTAssertThrowsError(try SpeciesCatalog.decode(data { $0[0][key] = -1 }))
        }
        XCTAssertThrowsError(try SpeciesCatalog.decode(data { $0.removeLast() }))
        XCTAssertThrowsError(try SpeciesCatalog.decode(data { $0[0]["id"] = "notABird" }))
        XCTAssertThrowsError(try SpeciesCatalog.decode(data { for i in $0.indices { $0[i]["weight"] = 0 } }))
        XCTAssertThrowsError(try SpeciesCatalog.decode(data { $0[0]["perchMin"] = 80; $0[0]["perchMax"] = 20 }))
    }
    func testWeightedSelectionBoundariesAndDisabledBirds() throws {
        let c = try SpeciesCatalog.decode(data { for i in $0.indices { $0[i]["weight"] = i == 1 ? 1 : (i == 6 ? 3 : 0) } })
        XCTAssertEqual(c.choose(unit:0).id,.treeSparrow)
        XCTAssertEqual(c.choose(unit:0.2499).id,.treeSparrow)
        XCTAssertEqual(c.choose(unit:0.25).id,.longTailedShrike)
        XCTAssertEqual(c.choose(unit:1).id,.longTailedShrike)
        let draws = (0..<1000).map { c.choose(unit:Double($0)/1000).id }
        XCTAssertEqual(draws.filter{$0 == .treeSparrow}.count,250)
        XCTAssertEqual(draws.filter{$0 == .longTailedShrike}.count,750)
    }
    func testAdultLengthRatiosAndLandingClearance() {
        let c = SpeciesCatalog.standard
        XCTAssertEqual(c.profile(.greyHeron).relativeScale,2.5,accuracy:0.000001)
        XCTAssertEqual(c.profile(.redWhiskeredBulbul).relativeScale,1)
        XCTAssertEqual(c.profile(.lightVentedBulbul).relativeScale,1)
        XCTAssertEqual(c.profile(.spottedDove).relativeScale,pow(31/19.0,log(2.5)/log(94/19.0)),accuracy:0.0001)
        let host = Surface(id:1,rect:CGRect(x:0,y:300,width:600,height:200))
        let cover = Surface(id:2,rect:CGRect(x:333,y:240,width:100,height:100))
        let foot = CGPoint(x:300,y:300)
        XCTAssertTrue(Geometry.isLandingVisible(on:1,at:foot,surfaces:[cover,host],scale:c.profile(.treeSparrow).relativeScale))
        XCTAssertFalse(Geometry.isLandingVisible(on:1,at:foot,surfaces:[cover,host],scale:c.profile(.spottedDove).relativeScale))
    }
    func testSpeciesIdleCadenceAndFlightTiming() {
        let c = SpeciesCatalog.standard, host = Surface(id:1,rect:CGRect(x:0,y:300,width:600,height:200))
        for p in c.species {
            let b = Bird(position:.zero,fraction:0.5,profile:p)
            XCTAssertTrue((p.perchMin...p.perchMax).contains(b.perchDuration))
            b.fly(to:CGPoint(x:100,y:100),host:host,duration:4)
            XCTAssertEqual(b.flightDuration,2/p.speed,accuracy:0.0001)
            b.tick(0.21); XCTAssertEqual(b.frameName,"fly\(Int(0.21*p.flapFPS)%8)")
            let motion = SpeciesBehavior.motion(p.id)
            b.perch(on:host); b.tick(motion.start + motion.duration * 0.25)
            if p.id == .nightHeron { XCTAssertEqual(b.frameName,"stretch") }
            else { XCTAssertTrue(b.frameName.hasPrefix("idle"),p.id.rawValue) }
            if motion.hop > 0 { XCTAssertLessThan(b.hopOffset,0) } else { XCTAssertEqual(b.hopOffset,0) }
        }
    }
    func testAllSizesRetainDelayedDepthAndDeparture() {
        for p in SpeciesCatalog.standard.species {
            let b = Bird(position:.zero,fraction:0.5,profile:p)
            let host = Surface(id:1,rect:CGRect(x:0,y:300,width:600,height:200))
            b.fly(to:CGPoint(x:300,y:300),host:host,duration:2)
            b.tick(b.flightDuration*0.5); XCTAssertNil(b.depthID)
            b.tick(b.flightDuration*0.5); XCTAssertEqual(b.depthID,1)
            b.depart(to:CGPoint(x:-1000,y:100),duration:2); b.tick(5)
            XCTAssertTrue(b.departureFinished); XCTAssertFalse(b.needsDestination)
        }
    }
}
