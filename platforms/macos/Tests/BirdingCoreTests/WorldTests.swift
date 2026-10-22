import XCTest
import CoreGraphics
@testable import BirdingCore

final class WorldTests: XCTestCase {
    let host = Surface(id:42,rect:CGRect(x:100,y:300,width:500,height:250))
    func testSlowMovementKeepsRelativePerch() {
        let b = Bird(position:.zero,fraction:0.4); b.perch(on:host)
        let old = b.position
        var moved = host; moved.rect.origin.x += 4; moved.rect.origin.y += 2
        b.updateHost(surfaces:[moved],sampleDT:1.0/30)
        XCTAssertEqual(b.state,.perched); XCTAssertEqual(b.position.x,old.x+4); XCTAssertEqual(b.position.y,302)
    }
    func testFastDragStartles() {
        let b = Bird(position:.zero,fraction:0.5); b.perch(on:host)
        var moved = host; moved.rect.origin.x += 120
        b.updateHost(surfaces:[moved],sampleDT:1.0/30)
        XCTAssertEqual(b.state,.flying); XCTAssertNil(b.hostID); XCTAssertEqual(b.startledCount,1)
    }
    func testLongSamplingGapDoesNotInventVelocity() {
        let b = Bird(position:.zero,fraction:0.5); b.perch(on:host)
        var moved = host; moved.rect.origin.x += 120
        b.updateHost(surfaces:[moved],sampleDT:2)
        XCTAssertEqual(b.state,.perched)
    }
    func testClosedHostReleasesPerch() {
        let b = Bird(position:.zero,fraction:0.5); b.perch(on:host)
        b.updateHost(surfaces:[],sampleDT:0.03)
        XCTAssertNil(b.hostID); XCTAssertEqual(b.state,.flying)
    }
    func testResizePreservesFraction() {
        let b = Bird(position:.zero,fraction:0.7); b.perch(on:host)
        var resized = host; resized.rect.size.width = 220
        b.updateHost(surfaces:[resized],sampleDT:0.03)
        XCTAssertEqual(b.position.x,Geometry.perchX(0.7,rect:resized.rect))
    }
    func testFlightLandingAndIdleSequence() {
        let b = Bird(position:.zero,fraction:0.5)
        b.fly(to:CGPoint(x:350,y:300),host:host,duration:1)
        b.tick(0.25); XCTAssertEqual(b.state,.flying); XCTAssertLessThan(b.position.y,150)
        b.tick(b.flightDuration-0.25); XCTAssertEqual(b.state,.landing); XCTAssertEqual(b.frameName,"land0")
        b.tick(0.43); XCTAssertEqual(b.state,.perched)
        b.tick(0.05); XCTAssertEqual(b.frameName,"blink")
        b.tick(2.5); XCTAssertTrue(b.frameName.hasPrefix("idle"))
        b.tick(6.1); XCTAssertTrue(b.frameName.hasPrefix("preen"))
    }
    func testMovingFlightTargetUpdatesEndpoint() {
        let b = Bird(position:.zero,fraction:0.5); b.fly(to:.zero,host:host,duration:1)
        b.updateHost(surfaces:[host],sampleDT:0.03); b.tick(b.flightDuration)
        XCTAssertEqual(b.position,CGPoint(x:350,y:300))
    }
    func testZOrderOnlyMasksWindowsInFrontOfHost() {
        let b = Bird(position:.zero,fraction:0.5); b.perch(on:host)
        let front = Surface(id:1,rect:CGRect(x:0,y:0,width:100,height:100))
        let behind = Surface(id:2,rect:CGRect(x:50,y:50,width:200,height:200))
        XCTAssertEqual(b.blockers(in:[front,host,behind]),[front.rect])
        XCTAssertEqual(b.blockers(in:[host,front,behind]),[])
    }
    func testOverlappingOccludersNeverPunchHoles() {
        let rect = CGRect(x:0,y:0,width:100,height:100)
        let blockers = [CGRect(x:20,y:0,width:60,height:60),CGRect(x:40,y:20,width:60,height:60)]
        let pieces = Geometry.visiblePieces(rect,blockers:blockers)
        XCTAssertEqual(pieces.reduce(0){$0+$1.width*$1.height},4400)
        for piece in pieces { for blocker in blockers { XCTAssertTrue(piece.intersection(blocker).isEmpty) } }
    }
    func testFullyOccludedBirdHasNoPieces() {
        XCTAssertTrue(Geometry.visiblePieces(CGRect(x:10,y:10,width:10,height:10),blockers:[CGRect(x:0,y:0,width:100,height:100)]).isEmpty)
    }
    func testMultiDisplayCoordinatesIncludingNegativeOrigins() {
        XCTAssertEqual(Geometry.quartz(CGRect(x:-1440,y:-200,width:1440,height:900),primaryHeight:1080),CGRect(x:-1440,y:380,width:1440,height:900))
        XCTAssertEqual(Geometry.quartz(CGRect(x:0,y:1080,width:1920,height:1080),primaryHeight:1080).minY,-1080)
    }
    func testFreeFlightStaysBelowUtilityWindows() {
        let b = Bird(position:.zero,fraction:0.5)
        let panel = Surface(id:5,rect:CGRect(x:0,y:0,width:50,height:50),layer:3)
        XCTAssertEqual(b.blockers(in:[panel,host]),[panel.rect])
    }
    func testFlightFromFrontAToRearCOnlyAdoptsDepthOnArrival() {
        let a = Surface(id:1,rect:CGRect(x:100,y:350,width:500,height:300))
        let b = Surface(id:2,rect:CGRect(x:100,y:250,width:500,height:300))
        let c = Surface(id:3,rect:CGRect(x:100,y:150,width:500,height:300))
        let windows = [a,b,c]
        let bird = Bird(position:.zero,fraction:0.5)
        bird.perch(on:a)
        let end = CGPoint(x:350,y:150)
        XCTAssertTrue(Geometry.isLandingVisible(on:c.id,at:end,surfaces:windows,scale:1))
        bird.fly(to:end,host:c,duration:2,arc:0)
        XCTAssertEqual(bird.hostID,c.id)
        XCTAssertNil(bird.depthID)
        XCTAssertTrue(bird.blockers(in:windows).isEmpty)
        bird.updateHost(surfaces:windows,sampleDT:0.03)
        bird.tick(0.25)
        XCTAssertTrue(b.rect.contains(bird.position), "Regression: bird is traversing B's rectangle")
        XCTAssertTrue(bird.blockers(in:windows).isEmpty, "B must not hide the bird during A→C")
        bird.tick(bird.flightDuration-0.26)
        XCTAssertEqual(bird.state,.flying)
        XCTAssertNil(bird.depthID)
        bird.tick(0.02)
        XCTAssertEqual(bird.state,.landing)
        XCTAssertEqual(bird.depthID,c.id)
        XCTAssertEqual(bird.position.y,end.y,accuracy:0.001)
        XCTAssertEqual(bird.blockers(in:windows),[a.rect,b.rect])
    }
    func testPartlyCoveredLandingIsRejectedEvenWithMostlyVisibleHead() {
        let end = CGPoint(x:350,y:300)
        let cover = Surface(id:1,rect:CGRect(x:365,y:250,width:20,height:80))
        XCTAssertFalse(Geometry.isLandingVisible(on:host.id,at:end,surfaces:[cover,host],scale:1))
        XCTAssertTrue(Geometry.isLandingVisible(on:host.id,at:end,surfaces:[host,cover],scale:1))
        // Tail extends below the top edge; testing only the head would miss this.
        let tailCover = Surface(id:2,rect:CGRect(x:320,y:303,width:20,height:20))
        XCTAssertFalse(Geometry.isLandingVisible(on:host.id,at:end,surfaces:[tailCover,host],scale:1))
    }
    func testLandingVisibilityAccountsForDisplayScale() {
        let end = CGPoint(x:350,y:300)
        let cover = Surface(id:1,rect:CGRect(x:385,y:250,width:20,height:80))
        XCTAssertTrue(Geometry.isLandingVisible(on:host.id,at:end,surfaces:[cover,host],scale:1))
        XCTAssertFalse(Geometry.isLandingVisible(on:host.id,at:end,surfaces:[cover,host],scale:1.5))
    }
    func testNewOccluderDuringFlightRequestsNewRouteWithoutTeleporting() {
        let bird = Bird(position:CGPoint(x:350,y:600),fraction:0.5)
        let end = CGPoint(x:350,y:300)
        bird.fly(to:end,host:host,duration:2,arc:0)
        bird.updateHost(surfaces:[host],sampleDT:0.03)
        bird.tick(0.25)
        let current = bird.position
        let cover = Surface(id:1,rect:CGRect(x:100,y:250,width:500,height:400))
        bird.updateHost(surfaces:[cover,host],sampleDT:0.03)
        XCTAssertTrue(bird.needsDestination)
        XCTAssertEqual(bird.state,.flying)
        XCTAssertNil(bird.hostID)
        XCTAssertNil(bird.depthID)
        bird.tick(3)
        XCTAssertEqual(bird.position,current)
        XCTAssertEqual(bird.landedCount,0)
        XCTAssertEqual(bird.startledCount,0)
        bird.fly(to:CGPoint(x:800,y:100),host:nil,duration:2)
        XCTAssertFalse(bird.needsDestination)
        bird.tick(0.1)
        XCTAssertNotEqual(bird.position,current)
    }
    func testZOrderChangeDuringFlightInvalidatesCoveredDestination() {
        let bird = Bird(position:CGPoint(x:350,y:600),fraction:0.5)
        let cover = Surface(id:1,rect:CGRect(x:100,y:250,width:500,height:400))
        bird.fly(to:CGPoint(x:350,y:300),host:host,duration:2)
        bird.updateHost(surfaces:[host,cover],sampleDT:0.03)
        XCTAssertFalse(bird.needsDestination)
        bird.updateHost(surfaces:[cover,host],sampleDT:0.03)
        XCTAssertTrue(bird.needsDestination)
    }
    func testAlreadyPerchedBirdKeepsDepthWhenCoveredLater() {
        let bird = Bird(position:.zero,fraction:0.5)
        bird.perch(on:host)
        let cover = Surface(id:1,rect:CGRect(x:100,y:250,width:500,height:400))
        bird.updateHost(surfaces:[cover,host],sampleDT:0.03)
        XCTAssertEqual(bird.state,.perched)
        XCTAssertEqual(bird.depthID,host.id)
        XCTAssertFalse(bird.needsDestination)
        XCTAssertEqual(bird.blockers(in:[cover,host]),[cover.rect])
    }
}
