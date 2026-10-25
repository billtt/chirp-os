import XCTest
import CoreGraphics
@testable import BirdingCore

final class PopulationTests: XCTestCase {
    func testEmptyStartupThenExactlyOneArrival() {
        let p = Population()
        XCTAssertNil(p.tick(0.4,residents:0,total:0,random:{0.5}))
        XCTAssertEqual(p.tick(0.41,residents:0,total:0,random:{0.5}),.arrive)
        XCTAssertNil(p.tick(0.1,residents:1,total:1,random:{0.5}))
    }
    func testStableRandomPopulationNeverCrossesBounds() {
        var seed: UInt64 = 17
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1
            return Double(seed >> 11) / Double(UInt64(1)<<53)
        }
        for range in [PopulationRange.standard,PopulationRange(lower:8,upper:12)!,PopulationRange(lower:15,upper:20)!] {
            let p = Population(range:range)
            var count = 0, arrivals = 0, departures = 0, reached = false
            var visited = Set<Int>()
            for _ in 0..<2000 {
                if let event = p.tick(30,residents:count,total:count,random:random) {
                    if event == .arrive { count += 1; arrivals += 1 } else { count -= 1; departures += 1 }
                }
                reached = reached || count >= range.lower
                if reached { XCTAssertTrue(((range.lower == range.upper ? range.lower-1:range.lower)...range.upper).contains(count)); visited.insert(count) }
                XCTAssertLessThanOrEqual(count,range.upper)
            }
            XCTAssertTrue(reached); XCTAssertGreaterThan(arrivals,range.upper)
            XCTAssertGreaterThan(departures,0); XCTAssertGreaterThan(visited.count,1)
        }
    }
    func testPendingDeparturesReserveSpaceUntilOffscreen() {
        let p = Population()
        XCTAssertNil(p.tick(30,residents:3,total:5,random:{0}))
        XCTAssertEqual(p.tick(30,residents:3,total:4,random:{0}),.arrive)
    }
    func testRangeChangeIsGradualAndDoesNotUndershoot() {
        let p = Population(range:PopulationRange(lower:15,upper:20)!)
        p.setRange(.standard)
        var count = 18
        for _ in 0..<13 {
            XCTAssertEqual(p.tick(30,residents:count,total:count,random:{0.5}),.depart)
            count -= 1
        }
        XCTAssertEqual(count,5)
        XCTAssertNil(p.tick(0,residents:count,total:count,random:{0.5}))
        p.setRange(PopulationRange(lower:8,upper:12)!)
        XCTAssertEqual(p.tick(2,residents:count,total:count,random:{0.5}),.arrive)
    }
    func testZeroElapsedTimeDoesNotAccumulateEvents() {
        let p = Population()
        for _ in 0..<100 { XCTAssertNil(p.tick(0,residents:0,total:0)) }
        XCTAssertEqual(p.remaining,0.8)
    }
    func testRejectInvalidRangeAndAllowSingleTarget() {
        XCTAssertNil(PopulationRange(lower:0,upper:5))
        XCTAssertNil(PopulationRange(lower:8,upper:3))
        XCTAssertNil(PopulationRange(lower:3,upper:51))
        let p = Population(range:PopulationRange(lower:3,upper:3)!)
        XCTAssertEqual(p.tick(30,residents:3,total:3,random:{0.5}),.depart)
        XCTAssertNil(p.tick(5,residents:2,total:3,random:{0.5}))
        XCTAssertEqual(p.tick(5,residents:2,total:2,random:{0.5}),.arrive)
        XCTAssertEqual(p.remaining,36)
    }
    func testMigrationPointsAreOutsideAllScreensIncludingNegativeOrigins() {
        let screens = [CGRect(x:-2560,y:0,width:2560,height:1440),CGRect(x:0,y:0,width:2560,height:1440)]
        for right in [false,true] {
            let p = Migration.outsidePoint(screens:screens,right:right,fraction:0.4,margin:100)!
            let footprint = Geometry.landingFootprint(at:p,scale:1.5)
            XCTAssertFalse(screens.contains{$0.intersects(footprint)})
            XCTAssertEqual(p.x,right ? 2660 : -2660)
        }
        XCTAssertNil(Migration.outsidePoint(screens:[],right:true,fraction:0.5,margin:100))
    }
    func testDepartureCannotBecomeAnotherPerchingFlight() {
        let bird = Bird(position:CGPoint(x:400,y:300),fraction:0.5)
        let end = CGPoint(x:-100,y:200)
        bird.depart(to:end,duration:4)
        bird.tick(1)
        XCTAssertTrue(bird.isDeparting); XCTAssertFalse(bird.departureFinished)
        XCTAssertFalse(bird.needsDestination); XCTAssertNil(bird.hostID); XCTAssertNil(bird.depthID)
        bird.tick(1)
        XCTAssertTrue(bird.departureFinished); XCTAssertFalse(bird.needsDestination)
        XCTAssertEqual(bird.position,end)
    }
    func testSettledFlockChangesLessOftenWithoutSlowingStartup() {
        let settled=Population()
        XCTAssertEqual(settled.tick(1,residents:4,total:4,random:{0.5}),.arrive)
        XCTAssertEqual(settled.remaining,36)
        XCTAssertNil(settled.tick(20,residents:5,total:5,random:{0.5}))
        let startup=Population()
        XCTAssertEqual(startup.tick(1,residents:0,total:0,random:{0.5}),.arrive)
        XCTAssertEqual(startup.remaining,4.25)
    }

}
