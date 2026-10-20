import Foundation
import CoreGraphics

public struct Surface: Equatable {
    public let id: UInt32
    public let pid: Int32
    public var rect: CGRect // Quartz desktop coordinates: y grows downward.
    public let layer: Int
    public init(id: UInt32, pid: Int32 = 0, rect: CGRect, layer: Int = 0) {
        self.id = id; self.pid = pid; self.rect = rect; self.layer = layer
    }
}

public enum Geometry {
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
        guard let depth = surfaces.firstIndex(where: { $0.id == hostID }) else { return false }
        let area = landingFootprint(at: foot, scale: scale)
        return !surfaces.prefix(depth).contains {
            !$0.rect.intersection(area).isEmpty && !$0.rect.intersection(area).isNull
        }
    }
    // Continuous foot-position intervals, clipped by screens, occluders and reservations.
    public static func landingRanges(on host: Surface, surfaces: [Surface], screen: CGRect,
                                     scale: CGFloat, occupied: [CGRect] = []) -> [ClosedRange<CGFloat>] {
        guard let depth = surfaces.firstIndex(where: { $0.id == host.id }) else { return [] }
        let y = host.rect.minY, half = 29 * scale
        guard y - 39 * scale >= screen.minY, y + 9 * scale <= screen.maxY else { return [] }
        let lo = max(perchX(0, rect: host.rect), screen.minX + half)
        let hi = min(perchX(1, rect: host.rect), screen.maxX - half)
        guard hi > lo else { return [] }
        var ranges = [lo...hi]
        for rect in surfaces.prefix(depth).map(\.rect) + occupied {
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
    public static func foot(on host:Surface, fraction:CGFloat, edge:PerchEdge) -> CGPoint {
        if edge == .top { return CGPoint(x:perchX(fraction,rect:host.rect),y:host.rect.minY) }
        return CGPoint(x:edge == .left ? host.rect.minX:host.rect.maxX,
                       y:host.rect.minY+42+max(0,host.rect.height-84)*min(1,max(0,fraction)))
    }
    public static func sideRanges(on host:Surface, edge:PerchEdge, surfaces:[Surface], screen:CGRect,
                                  scale:CGFloat, occupied:[CGRect]) -> [ClosedRange<CGFloat>] {
        guard let depth=surfaces.firstIndex(where:{$0.id==host.id}) else { return [] }
        let x=edge == .left ? host.rect.minX:host.rect.maxX
        guard x-29*scale >= screen.minX, x+29*scale <= screen.maxX else { return [] }
        let lo=max(host.rect.minY+42,screen.minY+39*scale)
        let hi=min(host.rect.maxY-42,screen.maxY-9*scale)
        guard hi>lo else { return [] }
        var ranges=[lo...hi]
        for r in surfaces.prefix(depth).map(\.rect)+occupied {
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
        self.position = position; self.origin = position; self.target = position; self.fraction = fraction
    }
    // Duration is the original route timing; the multiplier halves travel time only.
    // Landing and idle clocks keep their natural timing.
    public func fly(to point: CGPoint, host: Surface?, duration: Double = 3, arc: CGFloat = 90) {
        isDeparting = false
        origin = position; target = point; hostID = host?.id; depthID = nil
        previousHost = nil; flightDuration = max(0.3, duration) / (Self.flightSpeedMultiplier * profile.speed); self.arc = arc
        flightAge = 0; stateTime = 0; state = .flying; destinationInvalidated = false
    }
    public func depart(to point: CGPoint, duration: Double) {
        fly(to: point, host: nil, duration: duration, arc: 30)
        isDeparting = true
    }
    public var departureFinished: Bool { isDeparting && flightAge >= flightDuration }
    public func perch(on host: Surface) {
        hostID = host.id; depthID = host.id; previousHost = host.rect
        position = Geometry.foot(on:host,fraction:fraction,edge:edge)
        state = .perched; stateTime = 0; destinationInvalidated = false
        if edge != .top { facingRight = edge == .left }
    }
    public func flee() {
        startledCount += 1
        fly(to: CGPoint(x: position.x + (facingRight ? 210 : -210), y: position.y - 100), host: nil, duration: 1.25, arc: 45)
    }
    // Called at the actual metadata sampling interval, independent of animation frames.
    public func updateHost(surfaces: [Surface], sampleDT: Double, spriteScale: CGFloat = 1) {
        guard let id = hostID else { return }
        guard let host = surfaces.first(where: { $0.id == id }) else { flee(); return }
        let point = Geometry.foot(on:host,fraction:fraction,edge:edge)
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
                if sampleDT < 0.20 && delta > 8 && delta / max(0.016, sampleDT) > 950 {
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
            let smooth = t*t*(3-2*t)
            let next = CGPoint(x: origin.x + (target.x-origin.x)*smooth,
                               y: origin.y + (target.y-origin.y)*smooth - sin(t * .pi)*arc)
            if abs(next.x-position.x) > 0.05 { facingRight = next.x > position.x }
            position = next
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
        if let depthID, let index = surfaces.firstIndex(where: { $0.id == depthID }) {
            return surfaces.prefix(index).map(\.rect)
        }
        // Every flight is above normal windows; menus / utility panels still cover it.
        return surfaces.filter { $0.layer > 0 }.map(\.rect)
    }
    public var hopOffset: CGFloat {
        guard state == .perched, edge == .top else { return 0 }
        return CGFloat(SpeciesBehavior.hop(profile.id, age: stateTime))
    }
    public var frameName: String {
        switch state {
        case .flying: return "fly\(Int(stateTime * profile.flapFPS) % 8)"
        case .landing: if edge != .top { return "cling0" }; return "land\(min(2, Int(stateTime / 0.14)))"
        case .perched:
            return SpeciesBehavior.frame(profile.id, age: stateTime, side: edge != .top) ?? "stand"
        }
    }
}
