import Foundation

public enum ObservationHearts {
    public static let count=3
    public static let duration=1.2
    /// Grow in place, settle, then float upward and fade. Offsets use upward-positive Y.
    public static func particle(_ index:Int, age:Double) -> (x:Double,y:Double,size:Double,opacity:Double) {
        let pop=min(1,max(0,(age-Double(index)*0.035)/0.24))
        let t=pop-1
        let growth=1+2.70158*t*t*t+1.70158*t*t
        let flight=min(1,max(0,(age-0.38)/(duration-0.38)))
        let rise=42*flight*flight*(3-2*flight)
        return (Double(index-1)*18, (index == 1 ? 7:0)+rise,
                (index == 1 ? 13:10)*growth, min(1,pop*4)*min(1,max(0,(duration-age)/0.4)))
    }
    public static func clearance(scale:Double) -> Double { max(10,6*scale) }
}

/// Feedback is timed per individual bird, independently of observation counts.
public final class ObservationInteraction<Visit: Hashable> {
    public static var duration: Double { 1.2 }
    private struct State {
        var labelUntil = -Double.infinity
        var heartsUntil = -Double.infinity
        var clicks: [Double] = []
    }
    private var states: [Visit: State] = [:]
    public init() {}
    public func reset() { states.removeAll() }
    public func retain(_ visits: Set<Visit>) { states = states.filter { visits.contains($0.key) } }
    public func click(_ visit: Visit, now: Double) -> (label: Bool, hearts: Bool) {
        var state = states[visit] ?? State()
        state.clicks.removeAll { now - $0 >= Self.duration }
        state.clicks.append(now)
        let label = now >= state.labelUntil
        let hearts = state.clicks.count >= 3 && now >= state.heartsUntil
        if label { state.labelUntil = now + Self.duration }
        if hearts { state.heartsUntil = now + Self.duration; state.clicks.removeAll() }
        states[visit] = state
        return (label, hearts)
    }
}

public enum SpriteHitTest {
    /// Coordinates and radius are in source pixels; callers convert screen padding by scale.
    public static func contains(x: Double, y: Double, radius: Double, pixel: (Int, Int) -> Bool) -> Bool {
        guard x >= -radius, x < 48 + radius, y >= -radius, y < 48 + radius else { return false }
        let left = max(0, Int(floor(x-radius))), right = min(47, Int(floor(x+radius)))
        let top = max(0, Int(floor(y-radius))), bottom = min(47, Int(floor(y+radius)))
        guard left <= right, top <= bottom else { return false }
        for py in top...bottom { for px in left...right {
            let dx = max(Double(px)-x, max(0, x-Double(px+1)))
            let dy = max(Double(py)-y, max(0, y-Double(py+1)))
            if dx*dx+dy*dy <= radius*radius && pixel(px, py) { return true }
        }}
        return false
    }
}
