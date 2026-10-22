import XCTest
@testable import BirdingCore

final class FlightBehaviorTests: XCTestCase {
    let host=Surface(id:1,rect:CGRect(x:100,y:500,width:900,height:300))
    let airspace=CGRect(x:80,y:120,width:1000,height:650)
    func bird(_ id:SpeciesID)->Bird { Bird(position:CGPoint(x:200,y:420),fraction:0.5,profile:SpeciesCatalog.standard.profile(id)) }
    func testSoarersCircleForLongPeriodsWithPoweredBurstsAndThenLand() {
        for id:SpeciesID in [.blackKite,.commonBuzzard,.commonKestrel,.peregrineFalcon,.blackHeadedGull] {
            let b=bird(id); b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace)
            XCTAssertGreaterThan(b.flightDuration,15)
            var circleSeconds=0.0, extended=0, powered=0, reversals=0, right=b.facingRight
            for _ in 0...Int(ceil(b.flightDuration*60)) {
                b.tick(1/60)
                if b.isCircling {
                    circleSeconds += 1/60
                    XCTAssertTrue(airspace.contains(b.position))
                    XCTAssertNil(b.depthID)
                    if b.frameName.hasPrefix("fly") { powered += 1 } else { extended += 1 }
                    if right != b.facingRight { reversals += 1; right=b.facingRight }
                }
            }
            XCTAssertGreaterThan(circleSeconds,15)
            XCTAssertGreaterThan(extended,powered)
            XCTAssertGreaterThan(powered,0)
            XCTAssertGreaterThanOrEqual(reversals,3)
            XCTAssertEqual(b.position.x,700,accuracy:0.001)
            XCTAssertEqual(b.position.y,500,accuracy:0.001)
            XCTAssertEqual(b.depthID,1)
        }
    }
    func testSpeciesHaveDistinctCadenceAndRoutes() {
        let catalog=SpeciesCatalog.standard
        XCTAssertGreaterThan(catalog.profile(.treeSparrow).flapFPS,catalog.profile(.greyHeron).flapFPS*2)
        XCTAssertGreaterThan(catalog.profile(.mallard).flapFPS,catalog.profile(.blackKite).flapFPS)
        for p in catalog.species {
            let b=bird(p.id); b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace)
            let duration=b.flightDuration
            var poses=Set<String>()
            for _ in 0...Int(ceil(duration*60)) { b.tick(1/60); poses.insert(b.frameName) }
            XCTAssertEqual(b.state,.landing,p.id.rawValue)
            XCTAssertTrue(poses.contains(where:{$0.hasPrefix("fly")}),p.id.rawValue)
            if FlightBehavior.motion(p.id).style == .bounding { XCTAssertTrue(poses.contains("bound"),p.id.rawValue) }
        }
    }
    func testRaptorEscapeAndDepartureBypassCircling() {
        let b=bird(.blackKite); b.flee()
        XCTAssertLessThan(b.flightDuration,1)
        b.tick(0.2);XCTAssertFalse(b.isCircling);XCTAssertTrue(b.frameName.hasPrefix("fly"))
        b.depart(to:CGPoint(x:-200,y:250),duration:3)
        XCTAssertLessThan(b.flightDuration,2)
        b.tick(2);XCTAssertTrue(b.departureFinished);XCTAssertFalse(b.needsDestination)
    }
    func testOrbitContinuityAndNegativeMonitorCoordinates() {
        let area=CGRect(x:-1400,y:-900,width:1200,height:700)
        let b=Bird(position:CGPoint(x:-1200,y:-600),fraction:0.5,profile:SpeciesCatalog.standard.profile(.commonBuzzard))
        b.fly(to:CGPoint(x:-400,y:-300),host:nil,airspace:area)
        var old=b.position
        for _ in 0...Int(ceil(b.flightDuration*120)) {
            b.tick(1/120)
            XCTAssertTrue(area.contains(b.position))
            XCTAssertLessThan(Geometry.distance(old,b.position),5)
            old=b.position
        }
        XCTAssertTrue(b.needsDestination)
    }
    func testMovingAndBlockedDestinationDuringLongOrbit() {
        let b=bird(.commonBuzzard);b.fly(to:CGPoint(x:550,y:500),host:host,airspace:airspace);b.tick(12)
        var moved=host;moved.rect.origin.x+=20
        b.updateHost(surfaces:[moved],sampleDT:0.03)
        b.tick(b.flightDuration-12)
        XCTAssertEqual(b.position,Geometry.foot(on:moved,fraction:0.5,edge:.top))
        b.fly(to:CGPoint(x:550,y:500),host:host,airspace:airspace);b.tick(12)
        let pos=b.position
        b.updateHost(surfaces:[Surface(id:2,rect:CGRect(x:100,y:400,width:900,height:200)),host],sampleDT:0.03)
        b.tick(100)
        XCTAssertEqual(b.position,pos);XCTAssertTrue(b.needsDestination)
    }
    func testLegacyDefaultRatesUpgradeWithoutChangingCustomRates() throws {
        var old=BirdSettings()
        old.catalog.species[0].flapFPS=20
        old.catalog.species[1].flapFPS=37
        let restored=try BirdSettings.decode(JSONEncoder().encode(old))
        XCTAssertEqual(restored.catalog.species[0].flapFPS,32)
        XCTAssertEqual(restored.catalog.species[1].flapFPS,37)
        let again=try BirdSettings.decode(JSONEncoder().encode(restored))
        XCTAssertEqual(again.catalog.species,restored.catalog.species)
    }
}
