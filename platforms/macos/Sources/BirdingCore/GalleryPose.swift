import Foundation

public enum GalleryAction: Int, CaseIterable { case resting, flying, flapping, gliding, landing, preening, other }
public enum GalleryPose {
    public static func frame(_ id: SpeciesID, age: Double, fps: Double, action: GalleryAction = .resting, speedMultiplier:Double=1) -> String {
        let t = max(0, age)
        switch action {
        case .resting: return t.truncatingRemainder(dividingBy: 5) > 4.8 ? "blink" : (Int(t*1.2)%2 == 0 ? "stand" : "breathe")
        case .flying:
            let m = FlightBehavior.motion(id)
            let cruise=FlightBehavior.cruiseSpeed(id,multiplier:speedMultiplier)
            let timing=FlightTiming(distance:cruise*max(8,m.cycle*1.5),speed:cruise)
            let age=t.truncatingRemainder(dividingBy:timing.duration)
            let gliding=FlightBehavior.shouldGlide(id,age:age,fps:fps,speed:timing.speed(at:age),cruise:cruise,braking:age>=timing.brakeStart-0.12)
            return FlightBehavior.frame(id,age:age,fps:fps,gliding:gliding,banking:m.orbit>0 ? cos(age*2 * .pi/m.period):0)
        case .flapping: return FlightBehavior.frame(id, age:t, fps:fps)
        case .gliding: return FlightBehavior.canGlide(id) ? "glide1":FlightBehavior.frame(id,age:t,fps:fps)
        case .landing: return "land\(min(2,Int(t.truncatingRemainder(dividingBy:1.6)/0.14)))"
        case .preening: return "preen\(Int(t*3)%2)"
        case .other:
            if id == .nightHeron {
                let u=t.truncatingRemainder(dividingBy:8)
                if u < 2 { return "stretch" }
                if u < 3 { return Int(u*8)%2 == 0 ? "shake" : "stand" }
                if u < 4 { return "poop\(Int(u*6)%2)" }
                return "stand"
            }
            if id == .eurasianNuthatch { return t.truncatingRemainder(dividingBy:4) < 2 ? "cling0" : "peck\(Int(t*4)%2)" }
            if id == .greatSpottedWoodpecker { return t.truncatingRemainder(dividingBy:4) < 2 ? "cling0" : "peck\(Int(t*12)%2)" }
            // These species have distinct perched actions in the art atlas.
            // General watching, scanning and head-bobbing stay at rest here.
            switch SpeciesBehavior.motion(id).action {
            case .tail, .probe, .dabble, .call, .glean, .rock, .hammer, .crack, .stalk, .wing:
                let motion=SpeciesBehavior.motion(id)
                return "idle\([0,1,2,1][Int(t*motion.rate)%4])"
            default: return frame(id,age:t,fps:fps,action:.resting)
            }
        }
    }
}
