import XCTest
@testable import BirdingCore

final class ObservationInteractionTests:XCTestCase {
    func testRaisedLabelSitsJustAboveInitialHeartPopAtEveryScale() {
        for scale in [0.5,1,2,4,6] {
            for top in [-900.0,0,300] {
                let bird=CGRect(x:400,y:top,width:100,height:100)
                let screen=CGRect(x:0,y:0,width:1000,height:700)
                let normal=BirdFeedbackLayout.label(bird:bird,screen:screen,size:CGSize(width:220,height:25))
                let raised=BirdFeedbackLayout.label(bird:bird,screen:screen,size:CGSize(width:220,height:25),clearance:ObservationHearts.labelClearance(scale:scale))
                XCTAssertEqual(raised.midX,normal.midX)
                XCTAssertLessThan(raised.maxY,normal.minY)
                for tick in 0...38 {
                    for index in 0..<ObservationHearts.count {
                        let particle=ObservationHearts.particle(index,age:Double(tick)/100)
                        let heartTop=top-ObservationHearts.clearance(scale:scale)-particle.y-particle.size
                        XCTAssertLessThanOrEqual(raised.maxY+8,heartTop)
                        if index == 1 && tick == 24 {
                            XCTAssertLessThanOrEqual(heartTop-raised.maxY,12)
                        }
                    }
                }
            }
        }
    }
    func testNameLabelsAvoidBirdAtScreenEdges() {
        for origin in [CGPoint.zero,CGPoint(x:-1200,y:-900)] {
            let screen=CGRect(origin:origin,size:CGSize(width:1000,height:700))
            for rect in [CGRect(x:400,y:300,width:100,height:100),CGRect(x:400,y:5,width:100,height:100),
                         CGRect(x:5,y:5,width:100,height:100),CGRect(x:895,y:5,width:100,height:100),
                         CGRect(x:10,y:0,width:980,height:100)] {
                let bird=rect.offsetBy(dx:origin.x,dy:origin.y)
                let placement=BirdFeedbackLayout.label(bird:bird,screen:screen,size:CGSize(width:220,height:25))
                XCTAssertFalse(placement.intersects(bird))
                XCTAssertGreaterThanOrEqual(placement.minX,screen.minX)
                XCTAssertLessThanOrEqual(placement.maxX,screen.maxX)
                XCTAssertEqual(placement.maxY,bird.minY-8)
                let lower=BirdFeedbackLayout.label(bird:bird.offsetBy(dx:0,dy:300),screen:screen,size:CGSize(width:220,height:25))
                XCTAssertEqual(placement.midX,lower.midX) // No sideways jump near the top.

            }
        }
        let bird=CGRect(x:0,y:0,width:100,height:100)
        let crowded=BirdFeedbackLayout.label(bird:bird,screen:bird,size:CGSize(width:100,height:25))
        XCTAssertFalse(crowded.intersects(bird))
    }
    func testThreeHeartsPopInPlaceBeforeFloatingAndFading() {
        XCTAssertEqual(ObservationHearts.count,3)
        for index in 0..<ObservationHearts.count {
            let pop=ObservationHearts.particle(index,age:0.15)
            let hold=ObservationHearts.particle(index,age:0.35)
            let floating=ObservationHearts.particle(index,age:0.9)
            XCTAssertEqual(pop.x,hold.x);XCTAssertEqual(pop.y,hold.y)
            XCTAssertGreaterThan(pop.size,0);XCTAssertEqual(hold.opacity,1)
            XCTAssertGreaterThan(floating.y,hold.y);XCTAssertLessThan(floating.opacity,hold.opacity)
            XCTAssertEqual(ObservationHearts.particle(index,age:ObservationHearts.duration).opacity,0)
        }
        XCTAssertGreaterThan(ObservationHearts.clearance(scale:4),ObservationHearts.clearance(scale:1))
    }
    func testRapidClicksPreserveLabelAndTriggerOneBurst() {
        let interaction=ObservationInteraction<Int>()
        let first=interaction.click(1,now:0)
        XCTAssertTrue(first.label);XCTAssertFalse(first.hearts)
        let second=interaction.click(1,now:0.2)
        XCTAssertFalse(second.label);XCTAssertTrue(second.hearts)
        let third=interaction.click(1,now:0.4)
        XCTAssertFalse(third.label);XCTAssertFalse(third.hearts)
        for time in [0.5,0.6,0.7,0.8] {
            let next=interaction.click(1,now:time)
            XCTAssertFalse(next.label);XCTAssertFalse(next.hearts)
        }
        XCTAssertTrue(interaction.click(1,now:1.21).label)
    }
    func testIndependentBirdsSlowClicksAndCleanup() {
        let interaction=ObservationInteraction<Int>()
        _=interaction.click(1,now:0)
        XCTAssertTrue(interaction.click(2,now:0.1).label)
        XCTAssertFalse(interaction.click(1,now:0.2).label)
        XCTAssertFalse(interaction.click(1,now:1.5).hearts)
        XCTAssertFalse(interaction.click(1,now:3).hearts)
        interaction.retain([2])
        XCTAssertTrue(interaction.click(1,now:3.1).label)
        interaction.reset()
        let reset=interaction.click(1,now:3.2)
        XCTAssertTrue(reset.label);XCTAssertFalse(reset.hearts)
    }
    func testHitPaddingUsesScreenDistanceAtDifferentScales() {
        for scale in [0.5,1.0,2.0,4.0] {
            func hit(_ x:Double,_ y:Double)->Bool {
                SpriteHitTest.contains(x:x,y:y,radius:5/scale) { $0 == 0 && $1 == 10 }
            }
            XCTAssertTrue(hit(-4.9/scale,10.5))
            XCTAssertFalse(hit(-5.1/scale,10.5))
            XCTAssertFalse(hit(-4/scale,10-4/scale)) // Circular padding, not a square.
        }
        XCTAssertTrue(SpriteHitTest.contains(x:0.5,y:10.5,radius:0) {$0 == 0 && $1 == 10})
        XCTAssertFalse(SpriteHitTest.contains(x:-0.1,y:10.5,radius:0) {$0 == 0 && $1 == 10})
        XCTAssertFalse(SpriteHitTest.contains(x:0,y:10,radius:5) {_,_ in false})
    }
}
