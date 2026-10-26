import XCTest
@testable import BirdingCore

final class FlightBehaviorTests: XCTestCase {
    let host=Surface(id:1,rect:CGRect(x:100,y:500,width:900,height:300))
    let airspace=CGRect(x:80,y:120,width:1000,height:650)
    func bird(_ id:SpeciesID)->Bird { Bird(position:CGPoint(x:200,y:420),fraction:0.5,profile:SpeciesCatalog.standard.profile(id)) }
    func testSoarersCircleBrieflyAndThenLand() {
        for id:SpeciesID in [.blackKite,.commonBuzzard,.commonKestrel,.peregrineFalcon,.blackHeadedGull] {
            let b=bird(id); b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace,random:{0})
            var circleSeconds=0.0, extended=0, powered=0
            for _ in 0...Int(ceil(b.flightDuration*60)) {
                b.tick(1/60)
                if b.isCircling {
                    circleSeconds += 1/60
                    XCTAssertTrue(airspace.contains(b.position))
                    XCTAssertNil(b.depthID)
                    if b.frameName.hasPrefix("fly") { powered += 1 } else { extended += 1 }
                }
            }
            XCTAssertGreaterThan(circleSeconds,0)
            XCTAssertLessThanOrEqual(circleSeconds,8.02)
            XCTAssertGreaterThan(extended,0)
            XCTAssertGreaterThan(extended+powered,0)
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
            let b=bird(p.id); b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace,random:{0})
            let duration=b.flightDuration
            var poses=Set<String>()
            for _ in 0...Int(ceil(duration*60)) { b.tick(1/60); poses.insert(b.frameName) }
            XCTAssertEqual(b.state,.landing,p.id.rawValue)
            XCTAssertTrue(poses.contains(where:{$0.hasPrefix("fly")}),p.id.rawValue)
            if !FlightBehavior.canGlide(p.id) {
                XCTAssertFalse(poses.contains(where:{$0.hasPrefix("glide") || $0.hasPrefix("bank") || $0 == "bound"}),p.id.rawValue)
            }
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
        b.fly(to:CGPoint(x:-400,y:-300),host:nil,airspace:area,random:{0})
        var old=b.position
        for _ in 0...Int(ceil(b.flightDuration*120)) {
            b.tick(1/120)
            XCTAssertTrue(area.contains(b.position))
            XCTAssertLessThan(Geometry.distance(old,b.position),5)
            old=b.position
        }
        XCTAssertTrue(b.needsDestination)
    }
    func testMovingAndBlockedDestinationDuringOrbit() {
        let b=bird(.commonBuzzard);b.fly(to:CGPoint(x:550,y:500),host:host,airspace:airspace,random:{0});b.tick(3);XCTAssertTrue(b.isCircling)
        var moved=host;moved.rect.origin.x+=20
        b.updateHost(surfaces:[moved],sampleDT:0.03)
        b.tick(b.flightDuration-3)
        XCTAssertEqual(b.position,Geometry.foot(on:moved,fraction:0.5,edge:.top))
        b.fly(to:CGPoint(x:550,y:500),host:host,airspace:airspace,random:{0});b.tick(3);XCTAssertTrue(b.isCircling)
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
    func testCirclingMaintainsCruiseSpeedIncludingNarrowTurns() {
        for id:SpeciesID in [.blackKite,.commonBuzzard,.commonKestrel,.peregrineFalcon,.blackHeadedGull] {
            let b=bird(id);b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace,random:{0})
            var speeds=[Double](),previous=b.position,wasCircling=false
            for _ in 0..<Int(b.flightDuration*240) {
                b.tick(1/240)
                if wasCircling && b.isCircling { speeds.append(Double(Geometry.distance(previous,b.position))*240) }
                previous=b.position;wasCircling=b.isCircling
            }
            XCTAssertGreaterThan(speeds.min()!,100,id.rawValue)
            let cruise=FlightBehavior.cruiseSpeed(id,multiplier:SpeciesCatalog.standard.profile(id).speed)
            XCTAssertEqual(speeds.min()!,cruise,accuracy:1,id.rawValue)
            XCTAssertEqual(speeds.max()!,cruise,accuracy:1,id.rawValue)
            XCTAssertLessThan(speeds.max()!/speeds.min()!,1.05,id.rawValue)
            let radii=FlightBehavior.orbitRadii(width:Double(airspace.width),height:Double(airspace.height),widthSample:0,heightSample:0)
            let lapSeconds=FlightBehavior.orbitPath(horizontal:radii.width,vertical:radii.height).length/cruise
            XCTAssertEqual(Double(speeds.count)/240,min(FlightBehavior.motion(id).orbit,2*lapSeconds),accuracy:0.015)
            print("Cruise \(id.rawValue): \(Int(speeds.min()!))–\(Int(speeds.max()!)) pt/s")
        }
    }
    func testShortFlightsDoNotDriftForTheLongRouteDuration() {
        for p in SpeciesCatalog.standard.species where FlightBehavior.motion(p.id).orbit == 0 {
            let short=bird(p.id),long=bird(p.id)
            short.fly(to:CGPoint(x:320,y:420),host:nil,arc:20)
            long.fly(to:CGPoint(x:1000,y:420),host:nil,arc:20)
            XCTAssertLessThan(short.flightDuration,2.1,p.id.rawValue)
            XCTAssertGreaterThan(long.flightDuration,short.flightDuration*2,p.id.rawValue)
            short.tick(short.flightDuration*0.4);let old=short.position;short.tick(0.05)
            XCTAssertGreaterThan(Geometry.distance(old,short.position)/0.05,80,p.id.rawValue)
        }
    }
    func testArcLengthLookupClosesOrbitWithoutPausingAndHandlesZeroLength() {
        let path=FlightBehavior.orbitPath(horizontal:1,vertical:0.28)
        XCTAssertEqual(path.point(0).x,path.point(1).x,accuracy:1e-9)
        XCTAssertEqual(path.point(0).y,path.point(1).y,accuracy:1e-9)
        let stationary=FlightPath(.zero,.zero,.zero,.zero)
        XCTAssertEqual(stationary.point(0.5),.zero)
        for u in [0.01,0.25,0.5,0.75,0.99] {
            XCTAssertEqual(Double(Geometry.distance(path.point(u),path.point(u+0.001)))/0.001,path.length,accuracy:0.01)
        }
    }
    func testSmallBirdsOnlyFlapInFlightAndInTheGlideGallery() {
        for p in SpeciesCatalog.standard.species where !FlightBehavior.canGlide(p.id) {
            for age in stride(from:0.0,through:25,by:0.11) {
                XCTAssertTrue(FlightBehavior.frame(p.id,age:age,fps:p.flapFPS,gliding:true).hasPrefix("fly"))
                XCTAssertTrue(GalleryPose.frame(p.id,age:age,fps:p.flapFPS,action:.gliding).hasPrefix("fly"))
                XCTAssertTrue(GalleryPose.frame(p.id,age:age,fps:p.flapFPS,action:.flying).hasPrefix("fly"))
            }
        }
    }
    func testVelocityGateAndBrakingOverrideTimedGlide() {
        XCTAssertTrue(FlightBehavior.shouldGlide(.blackKite,age:4,fps:20,speed:160,cruise:160,braking:false))
        XCTAssertFalse(FlightBehavior.shouldGlide(.blackKite,age:4,fps:20,speed:80,cruise:80,braking:false))
        XCTAssertFalse(FlightBehavior.shouldGlide(.blackKite,age:4,fps:20,speed:160,cruise:160,braking:true,wasGliding:true))
        XCTAssertFalse(FlightBehavior.shouldGlide(.treeSparrow,age:4,fps:40,speed:400,cruise:300,braking:false))
    }
    func testAccelerationGlidingAndFlappingBeforeBrakingHaveNoSpeedJump() {
        for sample in [0.0,1.0] {
            for id:SpeciesID in [.blackKite,.commonBuzzard,.largeBilledCrow] {
                let b=bird(id);b.fly(to:CGPoint(x:1600,y:500),host:host,airspace:CGRect(x:80,y:120,width:1800,height:650),random:{sample})
                var glides=0,brakes=0,wasGliding=false,oldSpeed=0.0,brakeSpeeds=[Double]()
                for _ in 0..<Int(b.flightDuration*120) {
                    b.tick(1/120)
                    if b.isGliding {
                        glides+=1;XCTAssertGreaterThanOrEqual(b.flightSpeed,100)
                        XCTAssertFalse(b.isBraking)
                    }
                    if wasGliding != b.isGliding { XCTAssertLessThan(abs(b.flightSpeed-oldSpeed),8,id.rawValue) }
                    if b.isBraking { brakes+=1;XCTAssertTrue(b.frameName.hasPrefix("fly"));brakeSpeeds.append(b.flightSpeed) }
                    wasGliding=b.isGliding;oldSpeed=b.flightSpeed
                }
                XCTAssertGreaterThan(glides,0,id.rawValue);XCTAssertGreaterThan(brakes,0,id.rawValue)
                XCTAssertLessThan(brakeSpeeds.last!,brakeSpeeds.first!*0.1)
            }
        }
        var slow=SpeciesCatalog.standard.profile(.blackKite);slow.speed=0.3
        let b=Bird(position:CGPoint(x:200,y:420),fraction:0.5,profile:slow)
        b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace,random:{0})
        for _ in 0..<Int(b.flightDuration*60) { b.tick(1/60);XCTAssertFalse(b.isGliding) }
    }
    func testSpeedEnvelopeMatchesDistanceAndDoesNotBoostShortFlights() {
        for distance in [1.0,80,300,1500] {
            let timing=FlightTiming(distance:distance,speed:180)
            XCTAssertEqual(timing.speed(at:0),0,accuracy:1e-9)
            XCTAssertEqual(timing.speed(at:timing.duration),0,accuracy:1e-9)
            XCTAssertEqual(timing.progress(at:timing.duration),1)
            XCTAssertLessThanOrEqual(timing.peakSpeed,180)
            var integrated=0.0
            for i in 0..<10000 { integrated+=timing.speed(at:(Double(i)+0.5)*timing.duration/10000)*timing.duration/10000 }
            XCTAssertEqual(integrated,distance,accuracy:0.001)
        }
    }
    func testFasterCruiseAndPerchedMajorityAcrossSpecies() {
        for p in SpeciesCatalog.standard.species {
            let b=bird(p.id)
            b.fly(to:CGPoint(x:1000,y:500),host:host,airspace:airspace,random:{0})
            let meanPerch=(p.perchMin+p.perchMax)/2
            XCTAssertGreaterThan(meanPerch/(meanPerch+b.flightDuration),0.6,p.id.rawValue)
            let oldCruise=max(130,720/FlightBehavior.motion(p.id).transit)*p.speed
            var peak=0.0
            for _ in 0..<Int(b.flightDuration*120) { b.tick(1/120);peak=max(peak,b.flightSpeed) }
            XCTAssertGreaterThan(peak,oldCruise*(FlightBehavior.canGlide(p.id) ? 1.4:1.2),p.id.rawValue)
        }
    }
    func testPerchDefaultsMigrateOnceAndPreserveCustomRanges() throws {
        var old=BirdSettings();old.perchDefaultsVersion=nil
        for i in old.catalog.species.indices {
            old.catalog.species[i].perchMin/=2;old.catalog.species[i].perchMax/=2
        }
        let updated=try BirdSettings.decode(JSONEncoder().encode(old))
        XCTAssertEqual(updated.catalog.species,SpeciesCatalog.standard.species)
        XCTAssertEqual(updated.perchDefaultsVersion,1)
        old.catalog.species[0].perchMin+=1
        old.catalog.species[1].perchMax+=1
        let custom=try BirdSettings.decode(JSONEncoder().encode(old))
        XCTAssertEqual(Array(custom.catalog.species.prefix(2)),Array(old.catalog.species.prefix(2)))
        var intentional=updated
        intentional.catalog.species[0].perchMin/=2
        intentional.catalog.species[0].perchMax/=2
        let again=try BirdSettings.decode(JSONEncoder().encode(intentional))
        XCTAssertEqual(again.catalog.species,intentional.catalog.species)
    }

    func testNearbyPerchesUseShortOrbitsWithinScreen() {
        for area in [CGRect(x:80,y:120,width:1000,height:650),CGRect(x:-1600,y:-600,width:1600,height:900),CGRect(x:-600,y:0,width:600,height:900)] {
            for id:SpeciesID in [.blackKite,.commonBuzzard,.commonKestrel,.peregrineFalcon,.blackHeadedGull] {
                let start=CGPoint(x:area.midX,y:area.midY)
                let b=Bird(position:start,fraction:0.5,profile:SpeciesCatalog.standard.profile(id))
                let end=CGPoint(x:start.x+40,y:start.y)
                b.fly(to:end,host:nil,airspace:area,random:{0})
                var positions=[CGPoint]()
                for _ in 0..<Int(b.flightDuration*120) {
                    b.tick(1/120)
                    if b.isCircling { positions.append(b.position);XCTAssertTrue(area.contains(b.position),id.rawValue) }
                }
                XCTAssertFalse(positions.isEmpty,id.rawValue)
                XCTAssertLessThanOrEqual(Double(positions.count)/120,8.01,id.rawValue)
                b.tick(1)
                XCTAssertEqual(b.position,end)
            }
        }
    }

    func testRandomOrbitAxesReachFullScreenAndExitContinuously() {
        let area=CGRect(x:-1800,y:-600,width:1800,height:900)
        var widths=[Double](),heights=[Double]()
        for samples in [[0.0,0.0,0.0],[0.0,1.0,0.0],[0.0,1.0,1.0]] {
            var index=0
            let b=Bird(position:CGPoint(x:-900,y:-100),fraction:0.5,profile:SpeciesCatalog.standard.profile(.commonBuzzard))
            b.fly(to:CGPoint(x:-860,y:-100),host:host,airspace:area,random:{defer {index+=1};return samples[index]})
            XCTAssertEqual(index,3) // No per-frame jitter or resampling.
            var positions=[CGPoint](),previous=b.position,previousSpeed=0.0,wasCircling=false,checkedExit=false
            for _ in 0..<Int(b.flightDuration*120) {
                b.tick(1/120)
                XCTAssertLessThan(Geometry.distance(previous,b.position),3)
                if b.isCircling { positions.append(b.position) }
                if wasCircling && !b.isCircling { XCTAssertEqual(b.flightSpeed,previousSpeed,accuracy:2);checkedExit=true }
                previous=b.position;previousSpeed=b.flightSpeed;wasCircling=b.isCircling
            }
            XCTAssertTrue(checkedExit)
            XCTAssertTrue(positions.allSatisfy{area.contains($0)})
            XCTAssertFalse(positions.isEmpty)
            let radii=FlightBehavior.orbitRadii(width:Double(area.width),height:Double(area.height),widthSample:samples[1],heightSample:samples[2])
            widths.append(radii.width*2);heights.append(radii.height*2)
            b.tick(1);XCTAssertEqual(b.position,CGPoint(x:-860,y:-100))
        }
        XCTAssertGreaterThan(widths[1],Double(area.width)*0.99)
        XCTAssertGreaterThan(widths[1]/widths[0],1.5)
        XCTAssertEqual(widths[1],widths[2],accuracy:1)
        XCTAssertGreaterThan(heights[2]-heights[1],50)
        let thin=FlightBehavior.orbitRadii(width:8,height:8,widthSample:1,heightSample:1)
        XCTAssertEqual(thin,.zero)
    }

    func testCirclingIsOccasionalAndSkippedFlightsClearPreviousOrbit() {
        let b=bird(.commonBuzzard)
        var selected=0
        for sample in 0..<100 {
            var draws=0, circled=false
            b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace,random:{
                draws+=1;return draws == 1 ? Double(sample)/100 : 0.5
            })
            for _ in 0...Int(ceil(b.flightDuration*60)) { b.tick(1/60);circled = circled || b.isCircling }
            XCTAssertEqual(circled,sample<20)
            XCTAssertEqual(draws,circled ? 3 : 1)
            XCTAssertEqual(b.state,.landing)
            if circled { selected+=1 }
        }
        XCTAssertEqual(selected,20)
        for id:SpeciesID in [.treeSparrow,.commonBuzzard] {
            let b=bird(id)
            b.fly(to:CGPoint(x:700,y:500),host:host,airspace:airspace,urgent:id == .commonBuzzard,random:{
                XCTFail("Ineligible or urgent flights must not sample an orbit");return 0
            })
            for _ in 0...Int(ceil(b.flightDuration*60)) { b.tick(1/60);XCTAssertFalse(b.isCircling) }
        }
    }

    func testCirclingTravelNeverExceedsTwoLapsEvenOnSmallScreensOrAtHighSpeed() {
        for p in SpeciesCatalog.standard.species where FlightBehavior.motion(p.id).orbit>0 {
            for width in [100.0,600,1800] {
                for speed in [0.3,1.0,3.0] {
                    var profile=p;profile.speed=speed
                    let area=CGRect(x:-width,y:-900,width:width,height:900)
                    let start=CGPoint(x:area.midX,y:area.midY),end=CGPoint(x:area.midX+10,y:area.midY)
                    let b=Bird(position:start,fraction:0.5,profile:profile)
                    b.fly(to:end,host:nil,airspace:area,random:{0})
                    let radii=FlightBehavior.orbitRadii(width:width,height:900,widthSample:0,heightSample:0)
                    let circumference=FlightBehavior.orbitPath(horizontal:radii.width,vertical:radii.height).length
                    var distance=0.0,seconds=0.0,previous=b.position,wasCircling=false
                    for _ in 0...Int(ceil(b.flightDuration*960)) {
                        b.tick(1/960)
                        if b.isCircling { seconds+=1/960 }
                        if wasCircling && b.isCircling { distance+=Double(Geometry.distance(previous,b.position)) }
                        previous=b.position;wasCircling=b.isCircling
                    }
                    XCTAssertGreaterThan(seconds,0,p.id.rawValue)
                    XCTAssertLessThanOrEqual(seconds,FlightBehavior.motion(p.id).orbit+1/960)
                    XCTAssertLessThanOrEqual(distance/circumference,2,p.id.rawValue)
                    if width == 100 && speed == 3 { XCTAssertGreaterThan(distance/circumference,1.98,p.id.rawValue) }
                    XCTAssertEqual(b.position,end)
                }
            }
        }
    }

}
