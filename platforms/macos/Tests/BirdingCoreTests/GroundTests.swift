import XCTest
@testable import BirdingCore

final class GroundTests: XCTestCase {
    let display=CGRect(x:-1200,y:-300,width:1200,height:900)
    func floor(_ work:CGRect?=nil) -> Surface {
        Geometry.ground(id:UInt32.max-1,display:display,workArea:work ?? CGRect(x:-1200,y:-275,width:1200,height:815))
    }
    func testDockTaskbarHiddenAndSideLayoutsKeepEveryBirdInsideDisplay() {
        for work in [CGRect(x:-1200,y:-275,width:1200,height:815),display,CGRect(x:-1120,y:-275,width:1120,height:875),CGRect(x:-1200,y:-220,width:1200,height:820)] {
            let ground=floor(work)
            for scale:CGFloat in [1,2.5,3.75] {
                let ranges=Geometry.landingRanges(on:ground,surfaces:[ground],screen:display,scale:scale)
                XCTAssertFalse(ranges.isEmpty)
                for range in ranges {
                    for x in [range.lowerBound,range.upperBound] {
                        let y=Geometry.foot(on:ground,fraction:0.5,edge:.top,scale:scale).y
                        XCTAssertTrue(display.contains(Geometry.landingFootprint(at:CGPoint(x:x,y:y),scale:scale)))
                        XCTAssertEqual(y,min(work.maxY,display.maxY-9*scale))
                        XCTAssertGreaterThanOrEqual(x,work.minX);XCTAssertLessThanOrEqual(x,work.maxX)
                    }
                }
            }
        }
    }
    func testMaximizedWindowsDoNotRemoveGroundButPanelsAndReservationsDo() {
        let ground=floor(),window=Surface(id:1,rect:display)
        let foot=Geometry.foot(on:ground,fraction:0.5,edge:.top)
        XCTAssertTrue(Geometry.landingRanges(on:window,surfaces:[window,ground],screen:display,scale:1).isEmpty)
        XCTAssertFalse(Geometry.landingRanges(on:ground,surfaces:[window,ground],screen:display,scale:1).isEmpty)
        XCTAssertTrue(Geometry.isLandingVisible(on:ground.id,at:foot,surfaces:[window,ground],scale:1))
        let reservation=Geometry.landingFootprint(at:foot,scale:2).insetBy(dx:-8,dy:-8)
        let ranges=Geometry.landingRanges(on:ground,surfaces:[window,ground],screen:display,scale:1,occupied:[reservation])
        XCTAssertFalse(ranges.isEmpty);XCTAssertFalse(ranges.contains{$0.contains(foot.x)})
        let panel=Surface(id:2,rect:reservation,layer:3)
        XCTAssertFalse(Geometry.isLandingVisible(on:ground.id,at:foot,surfaces:[window,panel,ground],scale:1))
        let b=Bird(position:foot,fraction:0.5);b.perch(on:ground)
        XCTAssertEqual(b.blockers(in:[window,panel,ground]),[panel.rect])
        XCTAssertEqual(Geometry.blockers(on:window,surfaces:[ground,window]),[])
    }
    func testAllSpeciesLandAndRestOnGroundForTheirConfiguredDuration() {
        let ground=floor()
        for p in SpeciesCatalog.standard.species {
            let b=Bird(position:CGPoint(x:-1000,y:-100),fraction:0.5,profile:p)
            let end=Geometry.foot(on:ground,fraction:0.5,edge:.top,scale:p.relativeScale)
            b.fly(to:end,host:ground,airspace:display,random:{0.5})
            b.tick(b.flightDuration);XCTAssertEqual(b.state,.landing,p.id.rawValue)
            b.tick(0.5);XCTAssertEqual(b.state,.perched,p.id.rawValue)
            XCTAssertEqual(b.position,end);XCTAssertFalse(b.needsDestination)
            b.tick(b.perchDuration-0.1);XCTAssertFalse(b.needsDestination)
            b.tick(0.2);XCTAssertTrue(b.needsDestination)
        }
    }
    func testDockResizeAndAutoHideDoNotStartleRestingBirds() {
        let ground=floor(),hidden=floor(display)
        let b=Bird(position:.zero,fraction:0.5);b.perch(on:ground,spriteScale:2.5)
        b.updateHost(surfaces:[hidden],sampleDT:0.03,spriteScale:2.5)
        XCTAssertEqual(b.state,.perched);XCTAssertEqual(b.startledCount,0)
        XCTAssertEqual(b.position,Geometry.foot(on:hidden,fraction:0.5,edge:.top,scale:2.5))
        b.updateHost(surfaces:[ground],sampleDT:0.03,spriteScale:2.5)
        XCTAssertEqual(b.state,.perched);XCTAssertEqual(b.position.y,ground.rect.minY)
        b.updateHost(surfaces:[],sampleDT:0.03)
        XCTAssertEqual(b.state,.flying);XCTAssertNil(b.hostID)
        b.tick(b.flightDuration);XCTAssertTrue(b.needsDestination)
    }
    func testGroundMovementDuringApproachUpdatesLandingTarget() {
        let ground=floor(),hidden=floor(display)
        let b=Bird(position:CGPoint(x:-800,y:100),fraction:0.5)
        b.fly(to:Geometry.foot(on:ground,fraction:0.5,edge:.top,scale:2),host:ground)
        b.tick(0.2);b.updateHost(surfaces:[hidden],sampleDT:0.03,spriteScale:2)
        b.tick(b.flightDuration)
        XCTAssertEqual(b.state,.landing)
        XCTAssertEqual(b.position,Geometry.foot(on:hidden,fraction:0.5,edge:.top,scale:2))
    }
    func testWoodpeckersStandRatherThanClingToVirtualGround() {
        let ground=floor(),b=Bird(position:.zero,fraction:0.5,profile:SpeciesCatalog.standard.profile(.greatSpottedWoodpecker))
        b.edge = .left;b.perch(on:ground)
        XCTAssertEqual(b.edge,.top);XCTAssertFalse(b.frameName.hasPrefix("cling"))
        XCTAssertTrue(Geometry.sideRanges(on:ground,edge:.left,surfaces:[ground],screen:display,scale:1,occupied:[]).isEmpty)
    }
}
