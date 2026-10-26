import Foundation
import CoreGraphics

public struct Surface: Equatable {
    public let id: UInt32
    public let pid: Int32
    public var rect: CGRect // Quartz desktop coordinates: y grows downward.
    public let layer: Int
    public let isGround: Bool
    public init(id: UInt32, pid: Int32 = 0, rect: CGRect, layer: Int = 0, isGround: Bool = false) {
        self.id = id; self.pid = pid; self.rect = rect; self.layer = layer; self.isGround = isGround
    }
}

public enum Geometry {
    /// A virtual ledge at the work-area bottom; rect.maxY is the physical screen
    /// bottom, used to keep tails visible when the Dock/taskbar is hidden or lateral.
    public static func ground(id:UInt32,display:CGRect,workArea:CGRect) -> Surface {
        let left=max(display.minX,workArea.minX),right=min(display.maxX,workArea.maxX)
        let y=min(display.maxY,max(display.minY,workArea.maxY))
        return Surface(id:id,rect:CGRect(x:left,y:y,width:max(0,right-left),height:display.maxY-y),isGround:true)
    }
    public static func blockers(on host:Surface,surfaces:[Surface]) -> [Surface] {
        // Ground birds share the floating overlay with birds in flight. Normal
        // windows cannot invalidate this last-resort ledge, but utility panels can.
        if host.isGround { return surfaces.filter { !$0.isGround && $0.layer>0 } }
        guard let depth=surfaces.firstIndex(where:{$0.id==host.id}) else { return [] }
        return surfaces.prefix(depth).filter { !$0.isGround }
    }
    // Sequential subtraction, not even-odd clipping: overlapping occluders stay opaque.
    public static func subtract(_ rect: CGRect, _ blocker: CGRect) -> [CGRect] {
        let cut = rect.intersection(blocker)
        guard !cut.isNull, !cut.isEmpty else { return [rect] }
        return [CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: cut.minY - rect.minY),
                CGRect(x: rect.minX, y: cut.maxY, width: rect.width, height: rect.maxY - cut.maxY),
                CGRect(x: rect.minX, y: cut.minY, width: cut.minX - rect.minX, height: cut.height),
                CGRect(x: cut.maxX, y: cut.minY, width: rect.maxX - cut.maxX, height: cut.height)]
            .filter { $0.width > 0 && $0.height > 0 }
    }
    public static func visiblePieces(_ rect: CGRect, blockers: [CGRect]) -> [CGRect] {
        blockers.reduce([rect]) { pieces, blocker in pieces.flatMap { subtract($0, blocker) } }
    }
    // Reserve the whole landing sprite, including tail below the feet and either
    // facing direction. A partly exposed head is not enough for a safe arrival.
    public static func landingFootprint(at foot: CGPoint, scale: CGFloat) -> CGRect {
        CGRect(x: foot.x - 29*scale, y: foot.y - 39*scale, width: 58*scale, height: 48*scale)
    }
    public static func isLandingVisible(on hostID: UInt32, at foot: CGPoint,
                                        surfaces: [Surface], scale: CGFloat) -> Bool {
        guard let host = surfaces.first(where: { $0.id == hostID }) else { return false }
        let area = landingFootprint(at: foot, scale: scale)
        return !blockers(on:host,surfaces:surfaces).contains {
            !$0.rect.intersection(area).isEmpty && !$0.rect.intersection(area).isNull
        }
    }
    // Continuous foot-position intervals, clipped by screens, occluders and reservations.
    public static func landingRanges(on host: Surface, surfaces: [Surface], screen: CGRect,
                                     scale: CGFloat, occupied: [CGRect] = []) -> [ClosedRange<CGFloat>] {
        guard surfaces.contains(where: { $0.id == host.id }) else { return [] }
        let y = foot(on:host,fraction:0.5,edge:.top,scale:scale).y, half = 29 * scale
        guard y - 39 * scale >= screen.minY, y + 9 * scale <= screen.maxY else { return [] }
        let lo = max(perchX(0, rect: host.rect), screen.minX + half)
        let hi = min(perchX(1, rect: host.rect), screen.maxX - half)
        guard hi > lo else { return [] }
        var ranges = [lo...hi]
        for rect in blockers(on:host,surfaces:surfaces).map(\.rect) + occupied {
            guard rect.maxY > y - 39 * scale, rect.minY < y + 9 * scale else { continue }
            let left = rect.minX - half, right = rect.maxX + half
            ranges = ranges.flatMap { range -> [ClosedRange<CGFloat>] in
                if right <= range.lowerBound || left >= range.upperBound { return [range] }
                var result: [ClosedRange<CGFloat>] = []
                if left > range.lowerBound { result.append(range.lowerBound...left) }
                if right < range.upperBound { result.append(right...range.upperBound) }
                return result
            }
        }
        return ranges.filter { $0.upperBound - $0.lowerBound > 0.01 }
    }
    public static func foot(on host:Surface, fraction:CGFloat, edge:PerchEdge, scale:CGFloat=1) -> CGPoint {
        if host.isGround { return CGPoint(x:perchX(fraction,rect:host.rect),y:min(host.rect.minY,host.rect.maxY-9*scale)) }
        if edge == .top { return CGPoint(x:perchX(fraction,rect:host.rect),y:host.rect.minY) }
        return CGPoint(x:edge == .left ? host.rect.minX:host.rect.maxX,
                       y:host.rect.minY+42+max(0,host.rect.height-84)*min(1,max(0,fraction)))
    }
    public static func sideRanges(on host:Surface, edge:PerchEdge, surfaces:[Surface], screen:CGRect,
                                  scale:CGFloat, occupied:[CGRect]) -> [ClosedRange<CGFloat>] {
        guard !host.isGround, surfaces.contains(where:{$0.id==host.id}) else { return [] }
        let x=edge == .left ? host.rect.minX:host.rect.maxX
        guard x-29*scale >= screen.minX, x+29*scale <= screen.maxX else { return [] }
        let lo=max(host.rect.minY+42,screen.minY+39*scale)
        let hi=min(host.rect.maxY-42,screen.maxY-9*scale)
        guard hi>lo else { return [] }
        var ranges=[lo...hi]
        for r in blockers(on:host,surfaces:surfaces).map(\.rect)+occupied {
            guard r.maxX>x-29*scale, r.minX<x+29*scale else {continue}
            let a=r.minY-9*scale,b=r.maxY+39*scale
            ranges=ranges.flatMap { q -> [ClosedRange<CGFloat>] in
                if b<=q.lowerBound || a>=q.upperBound {return [q]}
                var result:[ClosedRange<CGFloat>]=[]
                if a>q.lowerBound {result.append(q.lowerBound...a)}
                if b<q.upperBound {result.append(b...q.upperBound)}
                return result
            }
        }
        return ranges.filter{$0.upperBound-$0.lowerBound>0.01}
    }
    public static func quartz(_ cocoa: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: cocoa.minX, y: primaryHeight - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }
    public static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x-b.x, a.y-b.y) }
    public static func perchX(_ fraction: CGFloat, rect: CGRect) -> CGFloat {
        let margin = min(42, rect.width / 3)
        return rect.minX + margin + max(0, rect.width - margin * 2) * min(1, max(0, fraction))
    }
}

public enum PerchEdge { case top, left, right }

public enum BirdState: String { case flying, landing, perched }
public final class Bird {
    public static let flightSpeedMultiplier: Double = 2
    public private(set) var isDeparting = false
    public var edge: PerchEdge = .top
    public let profile: SpeciesProfile
    public var position: CGPoint
    public var state: BirdState = .flying
    public var hostID: UInt32?
    public var depthID: UInt32?
    public var fraction: CGFloat
    public var facingRight = true
    public private(set) var stateTime: Double = 0
    public var flightDuration: Double = 1.5
    public var perchDuration: Double = 15
    public private(set) var startledCount = 0
    public private(set) var landedCount = 0
    public private(set) var followedDistance: CGFloat = 0
    private var previousHost: CGRect?
    private var origin: CGPoint
    private var target: CGPoint
    private var arc: CGFloat = 90
    private var flightAge: Double = 0
    private var destinationInvalidated = false
    public init(position: CGPoint, fraction: CGFloat, profile: SpeciesProfile = SpeciesCatalog.standard.profile(.redWhiskeredBulbul)) {
        self.profile = profile
        self.perchDuration = Double.random(in: profile.perchMin...profile.perchMax)
        self.position = position; self.origin = position; self.target = position; self.plannedTarget = position; self.fraction = fraction
    }
    private var transitDuration: Double = 1
    private var orbitDuration: Double = 0
    private var orbitCenter: CGPoint = .zero
    private var orbitRadius: CGFloat = 100
    private var orbitHeight: CGFloat = 100
    private var orbitPath:FlightPath?
    private var urgentFlight = false
    private var entryDuration=0.0, exitDuration=0.0, orbitTurns=1.0
    private var approach:FlightPath?, exitPath:FlightPath?, transitPath:FlightPath?
    private var plannedTarget:CGPoint = .zero
    private var approachTiming:FlightTiming?, exitTiming:FlightTiming?, transitTiming:FlightTiming?
    private var cruiseSpeed=0.0
    public private(set) var flightSpeed=0.0
    public private(set) var isGliding=false
    public var isBraking:Bool {
        if orbitDuration>0 {
            return flightAge>=entryDuration+orbitDuration && flightAge-entryDuration-orbitDuration >= (exitTiming?.brakeStart ?? .infinity)-0.12
        }
        return flightAge >= (transitTiming?.brakeStart ?? .infinity)-0.12
    }
    public var isCircling: Bool { orbitDuration > 0 && flightAge >= entryDuration && flightAge < entryDuration + orbitDuration }
    private var orbitPoint:CGPoint {
        let turns=max(0,(flightAge-entryDuration)/max(0.001,orbitDuration))*orbitTurns
        return orbitPath!.point(turns.truncatingRemainder(dividingBy:1))
    }
    // Transit speed and time spent airborne are separate: soaring must not be
    // squeezed into the old window-to-window travel duration.

    public func fly(to point: CGPoint, host: Surface?, duration: Double = 3, arc: CGFloat = 90, airspace: CGRect? = nil, urgent: Bool = false, random: () -> Double = { Double.random(in:0...1) }) {
        isDeparting = false
        if host?.isGround == true { edge = .top }
        origin = position; target = point; hostID = host?.id; depthID = nil
        previousHost = nil
        let m = FlightBehavior.motion(profile.id)
        urgentFlight = urgent
        transitDuration = max(0.3, duration) / (Self.flightSpeedMultiplier * profile.speed)
        orbitDuration = !urgent && m.orbit > 0 && random() < FlightBehavior.orbitProbability ? m.orbit : 0
        flightDuration = transitDuration + orbitDuration
        self.arc = arc
        let cruise=FlightBehavior.cruiseSpeed(profile.id,multiplier:profile.speed)*Self.flightSpeedMultiplier/2
        if orbitDuration>0 {
            let radii=FlightBehavior.orbitRadii(width:Double(airspace?.width ?? max(800,Geometry.distance(origin,point)*1.5)),height:Double(airspace?.height ?? 800),widthSample:random(),heightSample:random())
            orbitRadius=radii.width;orbitHeight=radii.height
            orbitPath=FlightBehavior.orbitPath(horizontal:Double(orbitRadius),vertical:Double(orbitHeight))
            // Keep the cruise speed and leave tangentially at the time or lap limit.
            orbitTurns=min(FlightBehavior.maxOrbitTurns,orbitDuration*cruise/max(1,orbitPath!.length))
            orbitDuration=orbitTurns*max(1,orbitPath!.length)/cruise
        }
        orbitCenter = CGPoint(x: (origin.x + point.x) / 2, y: min(origin.y, point.y) - 40)
        if let area = airspace {
            orbitCenter.x = min(area.maxX - orbitRadius, max(area.minX + orbitRadius, orbitCenter.x))
            orbitCenter.y = min(area.maxY - orbitHeight, max(area.minY + orbitHeight, orbitCenter.y))
            // A transit arch must also fit above the destination screen's edge.
            self.arc = min(arc, max(0, min(origin.y, point.y) - area.minY))
        }
        if orbitRadius < 24 || orbitHeight < 12 { orbitDuration = 0 }
        plannedTarget=point
        cruiseSpeed=cruise;isGliding=false;flightSpeed=0;transitTiming=nil
        func inside(_ p:CGPoint) -> CGPoint {
            guard let area=airspace else { return p }
            return CGPoint(x:min(area.maxX,max(area.minX,p.x)),y:min(area.maxY,max(area.minY,p.y)))
        }
        if orbitDuration>0 {
            let entry=CGPoint(x:orbitCenter.x-orbitRadius,y:orbitCenter.y)
            let arriveBend=min(orbitHeight*0.8,Geometry.distance(origin,entry)*0.4)
            let last=orbitPath!.point(orbitTurns.truncatingRemainder(dividingBy:1))
            let exit=CGPoint(x:orbitCenter.x+last.x,y:orbitCenter.y+last.y)
            let tangent=orbitPath!.loopTangent(orbitTurns)
            // A fractional exit may face away from the perch; give it room to turn.
            var leaveBend=min(orbitRadius*0.6,Geometry.distance(exit,point)*0.4)
            // Shorten the tangent as a whole near screen edges; clamping its
            // coordinates independently would introduce a sudden heading change.
            if let area=airspace {
                if tangent.x>0.000001 { leaveBend=min(leaveBend,(area.maxX-exit.x)/tangent.x) }
                if tangent.x < -0.000001 { leaveBend=min(leaveBend,(area.minX-exit.x)/tangent.x) }
                if tangent.y>0.000001 { leaveBend=min(leaveBend,(area.maxY-exit.y)/tangent.y) }
                if tangent.y < -0.000001 { leaveBend=min(leaveBend,(area.minY-exit.y)/tangent.y) }
            }
            approach=FlightPath(origin,inside(CGPoint(x:origin.x+(entry.x-origin.x)*0.35,y:origin.y+(entry.y-origin.y)*0.35)),inside(CGPoint(x:entry.x,y:entry.y-arriveBend)),entry)
            exitPath=FlightPath(exit,inside(CGPoint(x:exit.x+tangent.x*leaveBend,y:exit.y+tangent.y*leaveBend)),inside(CGPoint(x:point.x,y:point.y-min(self.arc,leaveBend))),point)
            // Match the tangential speed on both sides of the orbit join.
            approachTiming=FlightTiming(distance:approach!.length,speed:cruiseSpeed,acceleration:min(0.65,1.8*approach!.length/cruiseSpeed),deceleration:0)
            exitTiming=FlightTiming(distance:exitPath!.length,speed:cruiseSpeed,acceleration:0,deceleration:min(0.85,1.8*exitPath!.length/cruiseSpeed))
            entryDuration=approachTiming!.duration;exitDuration=exitTiming!.duration
            transitDuration=entryDuration+exitDuration
        } else {
            transitPath=FlightPath(origin,CGPoint(x:origin.x+(point.x-origin.x)/3,y:origin.y+(point.y-origin.y)/3-self.arc*4/3),CGPoint(x:origin.x+(point.x-origin.x)*2/3,y:origin.y+(point.y-origin.y)*2/3-self.arc*4/3),point)
            if !urgent {
                transitTiming=FlightTiming(distance:transitPath!.length,speed:cruise)
                transitDuration=transitTiming!.duration;cruiseSpeed=transitTiming!.peakSpeed
            }
        }
        flightDuration=transitDuration+orbitDuration
        flightAge = 0; stateTime = 0; state = .flying; destinationInvalidated = false
    }
    public func depart(to point: CGPoint, duration: Double) {
        fly(to: point, host: nil, duration: duration, arc: 30, urgent: true)
        isDeparting = true
    }
    public var departureFinished: Bool { isDeparting && flightAge >= flightDuration }
    public func perch(on host: Surface, spriteScale:CGFloat=1) {
        if host.isGround { edge = .top }
        hostID = host.id; depthID = host.id; previousHost = host.rect
        position = Geometry.foot(on:host,fraction:fraction,edge:edge,scale:spriteScale)
        state = .perched; stateTime = 0; destinationInvalidated = false;isGliding=false;flightSpeed=0
        if edge != .top { facingRight = edge == .left }
    }
    public func flee() {
        startledCount += 1
        fly(to: CGPoint(x: position.x + (facingRight ? 210 : -210), y: position.y - 100), host: nil, duration: 1.25, arc: 45, urgent: true)
    }
    // Called at the actual metadata sampling interval, independent of animation frames.
    public func updateHost(surfaces: [Surface], sampleDT: Double, spriteScale: CGFloat = 1) {
        guard let id = hostID else { return }
        guard let host = surfaces.first(where: { $0.id == id }) else { flee(); return }
        let point = Geometry.foot(on:host,fraction:fraction,edge:edge,scale:spriteScale)
        if state == .flying && !Geometry.isLandingVisible(on: id, at: point, surfaces: surfaces, scale: spriteScale) {
            // Stay exactly where we are until the controller chooses a new route.
            // This is a blocked destination, not a startle or an instantaneous landing.
            hostID = nil; depthID = nil; previousHost = nil
            destinationInvalidated = true
            return
        }
        if state != .flying {
            if let old = previousHost {
                let delta = Geometry.distance(host.rect.origin, old.origin)
                // Ignore long sampling gaps (sleep/Space transitions) when estimating velocity.
                if !host.isGround && sampleDT < 0.20 && delta > 8 && delta / max(0.016, sampleDT) > 950 {
                    flee(); return
                }
                followedDistance += Geometry.distance(position, point)
            }
            position = point
        } else { target = point }
        previousHost = host.rect
    }
    public func tick(_ dt: Double) {
        guard !destinationInvalidated else { return }
        stateTime += dt
        if state == .flying {
            flightAge += dt
            let t = min(1, flightAge / flightDuration)
            let m = FlightBehavior.motion(profile.id)
            let next: CGPoint
            if orbitDuration > 0 {
                if flightAge < entryDuration {
                    next=approach!.point(approachTiming!.progress(at:flightAge))
                } else if isCircling {
                    let p=orbitPoint
                    next=CGPoint(x:orbitCenter.x+p.x,y:orbitCenter.y+p.y)
                } else {
                    let u=exitTiming!.progress(at:flightAge-entryDuration-orbitDuration)
                    let p=exitPath!.point(u)
                    next=CGPoint(x:p.x+(target.x-plannedTarget.x)*u,y:p.y+(target.y-plannedTarget.y)*u)
                }
            } else {
                let u=transitTiming?.progress(at:flightAge) ?? FlightBehavior.travelProgress(t,duration:transitDuration),p=transitPath?.point(u) ?? origin
                let wave = urgentFlight ? 0 : m.wave * sin(2 * .pi * flightAge / m.cycle) * pow(sin(t * .pi), 2)
                next=CGPoint(x:p.x+(target.x-plannedTarget.x)*u,y:p.y+(target.y-plannedTarget.y)*u+wave)
            }
            if abs(next.x-position.x) > 0.05 { facingRight = next.x > position.x }
            let destination=t >= 1 ? target:next
            flightSpeed=Double(Geometry.distance(position,destination))/max(0.000001,dt)
            position=destination
            isGliding = !urgentFlight && t<1 && FlightBehavior.shouldGlide(profile.id,age:flightAge,fps:profile.flapFPS,speed:flightSpeed,cruise:cruiseSpeed,braking:isBraking,wasGliding:isGliding)
            if t >= 1 && hostID != nil {
                // Only adopt the host's depth once the feet have reached its top edge.
                depthID = hostID
                state = .landing; stateTime = 0; landedCount += 1
                if edge != .top { facingRight = edge == .left }
            }
        } else if state == .landing && stateTime > 0.42 {
            state = .perched; stateTime = 0
        }
    }
    public var needsDestination: Bool {
        !isDeparting && (destinationInvalidated || (state == .flying && flightAge >= flightDuration && hostID == nil) ||
        (state == .perched && stateTime >= perchDuration))
    }
    public func blockers(in surfaces: [Surface]) -> [CGRect] {
        if let depthID, let host = surfaces.first(where: { $0.id == depthID }) {
            return Geometry.blockers(on:host,surfaces:surfaces).map(\.rect)
        }
        // Every flight is above normal windows; menus / utility panels still cover it.
        return surfaces.filter { !$0.isGround && $0.layer > 0 }.map(\.rect)
    }
    public var hopOffset: CGFloat {
        guard state == .perched, edge == .top else { return 0 }
        return CGFloat(SpeciesBehavior.hop(profile.id, age: stateTime))
    }
    public var frameName: String {
        switch state {
        case .flying:
            return FlightBehavior.frame(profile.id,age:flightAge,fps:profile.flapFPS,gliding:isGliding,banking:isCircling ? -orbitPoint.x/orbitRadius:0)
        case .landing: if edge != .top { return "cling0" }; return "land\(min(2, Int(stateTime / 0.14)))"
        case .perched:
            return SpeciesBehavior.frame(profile.id, age: stateTime, side: edge != .top) ?? "stand"
        }
    }
}
