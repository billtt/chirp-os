import Foundation
import CoreGraphics

/// Stylized desktop timings, not measurements of wild birds. Every species must
/// choose a flight style; new raptors reuse the powered/soaring route machinery.
public enum FlightBehavior {
    public enum Style { case bounding, direct, steady, aerial, soaring, raptor, owl }
    public struct Motion {
        public let style: Style
        public let transit, cycle, powered, rate, wave, orbit, period: Double
    }
    public static func motion(_ id: SpeciesID) -> Motion {
        switch id {
        case .silkyStarling: return Motion(style: .direct, transit: 3.46, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .crestedMyna: return Motion(style: .direct, transit: 3.53, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .greatCrestedGrebe: return Motion(style: .steady, transit: 6.39, cycle: 5, powered: 0.9, rate: 1.5, wave: 0, orbit: 0, period: 0)
        case .daurianRedstart: return Motion(style: .bounding, transit: 2.29, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .taiwanBarbet: return Motion(style: .direct, transit: 3.39, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .groundTit: return Motion(style: .bounding, transit: 2.43, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .greatEgret: return Motion(style: .steady, transit: 7, cycle: 5, powered: 0.9, rate: 1.5, wave: 0, orbit: 0, period: 0)
        case .uplandBuzzard: return Motion(style: .raptor, transit: 7, cycle: 12, powered: 0.15, rate: 1.5, wave: 0, orbit: 40, period: 14)
        case .littleGrebe: return Motion(style: .direct, transit: 3.57, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .carrionCrow: return Motion(style: .direct, transit: 4.12, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .plainLaughingthrush: return Motion(style: .bounding, transit: 2.63, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .orientalTurtleDove: return Motion(style: .direct, transit: 3.75, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .easternSpotBilledDuck: return Motion(style: .direct, transit: 4.36, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .eurasianNuthatch: return Motion(style: .bounding, transit: 2.25, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .rufousBreastedAccentor: return Motion(style: .bounding, transit: 2.36, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .eurasianMagpie: return Motion(style: .bounding, transit: 3.03, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .eurasianGreatTit: return Motion(style: .bounding, transit: 2.25, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .marshTit: return Motion(style: .bounding, transit: 2.16, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .ashyDrongo: return Motion(style: .aerial, transit: 4.67, cycle: 2.2, powered: 0.58, rate: 1.6, wave: 18, orbit: 0, period: 0)
        case .eurasianCollaredDove: return Motion(style: .direct, transit: 3.72, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .greyTreepie: return Motion(style: .bounding, transit: 2.89, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .whiteCheekedStarling: return Motion(style: .direct, transit: 3.46, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .henricsLaughingthrush: return Motion(style: .bounding, transit: 2.57, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .indianWhiteEye: return Motion(style: .bounding, transit: 2.07, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .easternCattleEgret: return Motion(style: .steady, transit: 6.42, cycle: 5, powered: 0.9, rate: 1.5, wave: 0, orbit: 0, period: 0)
        case .commonPheasant: return Motion(style: .direct, transit: 3.2, cycle: 3, powered: 1, rate: 2, wave: 0, orbit: 0, period: 0)
        case .sootyHeadedBulbul: return Motion(style: .bounding, transit: 2.46, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .whiteBrowedLaughingthrush: return Motion(style: .bounding, transit: 2.72, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .whiteWagtail: return Motion(style: .bounding, transit: 2.43, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .blueWhistlingThrush: return Motion(style: .bounding, transit: 2.79, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .redBilledChough: return Motion(style: .soaring, transit: 6.15, cycle: 7, powered: 0.32, rate: 1.5, wave: 0, orbit: 20, period: 10)
        case .redBilledBlueMagpie: return Motion(style: .bounding, transit: 3.3, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .blackThroatedBushtit: return Motion(style: .bounding, transit: 2.07, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .greenBackedTit: return Motion(style: .bounding, transit: 2.21, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .blueThroatedBarbet: return Motion(style: .direct, transit: 3.43, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .blueFrontedRedstart: return Motion(style: .bounding, transit: 2.29, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .greaterCoucal: return Motion(style: .direct, transit: 4.12, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .hornedLark: return Motion(style: .bounding, transit: 2.36, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .redThroatedThrush: return Motion(style: .bounding, transit: 2.57, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .ruddyShelduck: return Motion(style: .direct, transit: 4.43, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .blackRedstart: return Motion(style: .bounding, transit: 2.4, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .daurianJackdaw: return Motion(style: .direct, transit: 3.78, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .greyCappedGreenfinch: return Motion(style: .bounding, transit: 2.25, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .silverThroatedBushtit: return Motion(style: .bounding, transit: 2.21, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .commonTailorbird: return Motion(style: .bounding, transit: 2.16, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .collaredFinchbill: return Motion(style: .bounding, transit: 2.52, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .himalayanVulture: return Motion(style: .raptor, transit: 8, cycle: 16, powered: 0.08, rate: 1.3, wave: 0, orbit: 52, period: 18)
        case .twite: return Motion(style: .bounding, transit: 2.25, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .yellowBilledBlueMagpie: return Motion(style: .bounding, transit: 3.24, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .ornateSunbird: return Motion(style: .direct, transit: 2.85, cycle: 3, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .brownBreastedBulbul: return Motion(style: .bounding, transit: 2.49, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .whiskeredYuhina: return Motion(style: .bounding, transit: 2.21, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .blackTailedGull: return Motion(style: .soaring, transit: 6.47, cycle: 7, powered: 0.32, rate: 1.5, wave: 0, orbit: 20, period: 10)
        case .blackBulbul: return Motion(style: .bounding, transit: 2.6, cycle: 1.3, powered: 0.78, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .redWhiskeredBulbul: return Motion(style: .bounding, transit: 2.4, cycle: 1.2, powered: 0.72, rate: 1.6, wave: 10, orbit: 0, period: 0)
        case .treeSparrow: return Motion(style: .bounding, transit: 1.8, cycle: 0.8, powered: 0.80, rate: 1.6, wave: 7, orbit: 0, period: 0)
        case .lightVentedBulbul: return Motion(style: .bounding, transit: 2.6, cycle: 1.3, powered: 0.74, rate: 1.7, wave: 11, orbit: 0, period: 0)
        case .spottedDove: return Motion(style: .direct, transit: 3.0, cycle: 3.0, powered: 0.86, rate: 2.0, wave: 0, orbit: 0, period: 0)
        case .chineseBlackbird: return Motion(style: .bounding, transit: 2.5, cycle: 1.5, powered: 0.80, rate: 1.7, wave: 8, orbit: 0, period: 0)
        case .magpieRobin: return Motion(style: .bounding, transit: 2.2, cycle: 1.0, powered: 0.78, rate: 1.6, wave: 9, orbit: 0, period: 0)
        case .longTailedShrike: return Motion(style: .bounding, transit: 2.8, cycle: 1.8, powered: 0.72, rate: 1.6, wave: 12, orbit: 0, period: 0)
        case .nightHeron: return Motion(style: .steady, transit: 5.8, cycle: 5.0, powered: 0.88, rate: 1.5, wave: 0, orbit: 0, period: 0)
        case .plumbeousWaterRedstart: return Motion(style: .bounding, transit: 2.1, cycle: 0.9, powered: 0.82, rate: 1.6, wave: 8, orbit: 0, period: 0)
        case .littleEgret: return Motion(style: .steady, transit: 5.4, cycle: 4.5, powered: 0.90, rate: 1.6, wave: 0, orbit: 0, period: 0)
        case .greyHeron: return Motion(style: .steady, transit: 7.0, cycle: 6.0, powered: 0.90, rate: 1.4, wave: 0, orbit: 0, period: 0)
        case .commonKestrel: return Motion(style: .raptor, transit: 4.0, cycle: 5.0, powered: 0.40, rate: 1.7, wave: 0, orbit: 18, period: 9)
        case .peregrineFalcon: return Motion(style: .raptor, transit: 3.6, cycle: 6.0, powered: 0.30, rate: 1.6, wave: 0, orbit: 20, period: 10)
        case .blackKite: return Motion(style: .raptor, transit: 5.0, cycle: 10.0, powered: 0.16, rate: 1.6, wave: 0, orbit: 36, period: 12)
        case .commonBuzzard: return Motion(style: .raptor, transit: 5.8, cycle: 12.0, powered: 0.14, rate: 1.5, wave: 0, orbit: 42, period: 14)
        case .orientalMagpie: return Motion(style: .bounding, transit: 3.6, cycle: 2.0, powered: 0.82, rate: 1.5, wave: 14, orbit: 0, period: 0)
        case .azureWingedMagpie: return Motion(style: .bounding, transit: 3.1, cycle: 1.6, powered: 0.78, rate: 1.6, wave: 12, orbit: 0, period: 0)
        case .largeBilledCrow: return Motion(style: .direct, transit: 4.3, cycle: 4.5, powered: 0.70, rate: 1.5, wave: 0, orbit: 0, period: 0)
        case .hoopoe: return Motion(style: .bounding, transit: 3.0, cycle: 1.8, powered: 0.65, rate: 1.5, wave: 20, orbit: 0, period: 0)
        case .barnSwallow: return Motion(style: .aerial, transit: 7.0, cycle: 2.8, powered: 0.50, rate: 1.6, wave: 25, orbit: 0, period: 0)
        case .mallard: return Motion(style: .direct, transit: 3.4, cycle: 4.0, powered: 1.0, rate: 2.2, wave: 0, orbit: 0, period: 0)
        case .asianKoel: return Motion(style: .direct, transit: 3.7, cycle: 3.0, powered: 0.78, rate: 1.5, wave: 0, orbit: 0, period: 0)
        case .swinhoesWhiteEye: return Motion(style: .bounding, transit: 1.9, cycle: 0.7, powered: 0.82, rate: 1.7, wave: 6, orbit: 0, period: 0)
        case .blackHeadedGull: return Motion(style: .soaring, transit: 6.0, cycle: 7.0, powered: 0.30, rate: 1.5, wave: 0, orbit: 16, period: 8)
        case .whimbrel: return Motion(style: .steady, transit: 4.6, cycle: 4.0, powered: 0.92, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .piedKingfisher: return Motion(style: .direct, transit: 3.0, cycle: 2.5, powered: 0.90, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .eurasianWoodcock: return Motion(style: .direct, transit: 2.8, cycle: 2.0, powered: 0.94, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .blackDrongo: return Motion(style: .aerial, transit: 4.5, cycle: 2.2, powered: 0.58, rate: 1.6, wave: 18, orbit: 0, period: 0)
        case .chinesePondHeron: return Motion(style: .steady, transit: 4.8, cycle: 4.0, powered: 0.92, rate: 1.6, wave: 0, orbit: 0, period: 0)
        case .yellowRumpedFlycatcher: return Motion(style: .bounding, transit: 2.0, cycle: 0.9, powered: 0.80, rate: 1.7, wave: 10, orbit: 0, period: 0)
        case .yellowBrowedWarbler: return Motion(style: .bounding, transit: 1.7, cycle: 0.7, powered: 0.84, rate: 1.8, wave: 6, orbit: 0, period: 0)
        case .greatTit: return Motion(style: .bounding, transit: 2.0, cycle: 0.8, powered: 0.78, rate: 1.8, wave: 9, orbit: 0, period: 0)
        case .commonMoorhen: return Motion(style: .direct, transit: 3.8, cycle: 3.0, powered: 1.0, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .greatSpottedWoodpecker: return Motion(style: .bounding, transit: 3.5, cycle: 1.6, powered: 0.55, rate: 1.6, wave: 22, orbit: 0, period: 0)
        case .vinousThroatedParrotbill: return Motion(style: .bounding, transit: 2.1, cycle: 0.9, powered: 0.82, rate: 1.7, wave: 9, orbit: 0, period: 0)
        case .blackWingedStilt: return Motion(style: .steady, transit: 4.5, cycle: 3.5, powered: 0.94, rate: 1.7, wave: 0, orbit: 0, period: 0)
        case .eurasianCoot: return Motion(style: .direct, transit: 4.0, cycle: 3.0, powered: 1.0, rate: 2.0, wave: 0, orbit: 0, period: 0)
        case .redBilledLeiothrix: return Motion(style: .bounding, transit: 2.2, cycle: 1.0, powered: 0.80, rate: 1.7, wave: 8, orbit: 0, period: 0)
        case .blackCollaredStarling: return Motion(style: .direct, transit: 2.8, cycle: 2.5, powered: 0.90, rate: 1.9, wave: 0, orbit: 0, period: 0)
        case .commonKingfisher: return Motion(style: .direct, transit: 2.0, cycle: 2.0, powered: 1.0, rate: 1.875, wave: 0, orbit: 0, period: 0)
        case .littleRingedPlover: return Motion(style: .direct, transit: 2.4, cycle: 2.2, powered: 0.95, rate: 1.9, wave: 0, orbit: 0, period: 0)
        case .yellowBilledGrosbeak: return Motion(style: .bounding, transit: 2.7, cycle: 1.3, powered: 0.75, rate: 1.7, wave: 12, orbit: 0, period: 0)
        case .redFlankedBluetail: return Motion(style: .bounding, transit: 2.0, cycle: 0.9, powered: 0.80, rate: 1.7, wave: 8, orbit: 0, period: 0)
        case .collaredScopsOwl: return Motion(style: .owl, transit: 4.6, cycle: 4.0, powered: 0.55, rate: 1.7, wave: 0, orbit: 0, period: 0)
        case .asianBarredOwlet: return Motion(style: .owl, transit: 4.0, cycle: 3.5, powered: 0.62, rate: 1.8, wave: 0, orbit: 0, period: 0)
        case .littleOwl: return Motion(style: .owl, transit: 3.5, cycle: 2.8, powered: 0.68, rate: 1.8, wave: 6, orbit: 0, period: 0)
        }
    }
    /// Tune travel speed independently of wingbeat cadence and orbit duration.
    public static func cruiseSpeed(_ id:SpeciesID, multiplier:Double=1) -> Double {
        max(130,720/motion(id).transit) * (canGlide(id) ? 1.65:1.35) * multiplier
    }
    public static func canGlide(_ id:SpeciesID) -> Bool {
        switch motion(id).style {
        case .raptor,.soaring,.owl:return true
        default:return [.nightHeron,.littleEgret,.greyHeron,.chinesePondHeron,.largeBilledCrow,.greatEgret,.easternCattleEgret,.carrionCrow,.daurianJackdaw].contains(id)
        }
    }
    public static func shouldGlide(_ id:SpeciesID,age:Double,fps:Double,speed:Double,cruise:Double,braking:Bool,wasGliding:Bool=false) -> Bool {
        guard canGlide(id),!braking,age>=0.65 else { return false }
        // Hysteresis prevents rapid pose changes near the threshold. These
        // thresholds select a pose; they never change the bird's velocity.
        let threshold=max(wasGliding ? 100:110,cruise*(wasGliding ? 0.78:0.90))
        guard speed>=threshold else { return false }
        let m=motion(id),rate=max(4,fps)
        let burst=max(8/rate,(m.cycle*m.powered*rate/8).rounded()*8/rate)
        return max(0,age).truncatingRemainder(dividingBy:m.cycle)>=burst
    }
    public static func frame(_ id: SpeciesID, age: Double, fps: Double, gliding:Bool=false, banking: Double = 0) -> String {
        if gliding && canGlide(id) {
            if abs(banking)>0.3 { return "bank\(banking<0 ? 0:2)" }
            return "glide1"
        }
        let t=canGlide(id) ? max(0,age).truncatingRemainder(dividingBy:motion(id).cycle):max(0,age)
        return "fly\((Int(t*max(4,fps))+3)%8)"
    }
    /// Sample each axis independently, once per flight. Airspace already reserves
    /// sprite margins; the extra four points keep the path off its exact boundary.
    public static func orbitRadii(width:Double,height:Double,widthSample:Double,heightSample:Double) -> CGSize {
        let x=max(0,width/2-4)*(0.62+0.38*min(1,max(0,widthSample)))
        let upper=max(0,min(height/2-4,min(240,min(height*0.3,x*0.45))))
        let lower=min(upper,max(60,x*0.22))
        return CGSize(width:x,height:lower+(upper-lower)*min(1,max(0,heightSample)))
    }
    public static func orbitPath(horizontal:Double,vertical:Double) -> FlightPath {
        FlightPath(points:(0...2048).map { i in
            let angle=Double(i)*2*Double.pi/2048
            return CGPoint(x:-horizontal*cos(angle),y:vertical*sin(angle))
        })
    }
    /// Short takeoff/landing ramps, leaving the middle of a journey at cruise.
    public static func travelProgress(_ t:Double, duration:Double) -> Double {
        let u=min(1,max(0,t)), ramp=min(0.1,0.18/max(0.01,duration)), area=1-ramp
        if u<ramp { return u*u/(2*ramp*area) }
        if u>1-ramp { return 1-pow(1-u,2)/(2*ramp*area) }
        return (u-ramp/2)/area
    }
}

/// Arc-length lookup, shared by transit curves and the projected ellipse.
/// Equal time steps cover equal distances even at an ellipse's narrow ends.
public struct FlightPath {
    private let points:[CGPoint]
    private let distances:[Double]
    public let length:Double
    public init(points:[CGPoint]) {
        precondition(points.count>=2)
        self.points=points
        var distances=[0.0]
        for i in 1..<points.count { distances.append(distances.last!+Double(Geometry.distance(points[i-1],points[i]))) }
        self.distances=distances;length=distances.last!
    }
    public init(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint) {
        self.init(points:(0...64).map { i in
            let t=CGFloat(i)/64,s=1-t
            let w0=s*s*s,w1=3*s*s*t,w2=3*s*t*t,w3=t*t*t
            let x=w0*a.x+w1*b.x+w2*c.x+w3*d.x
            let y=w0*a.y+w1*b.y+w2*c.y+w3*d.y
            return CGPoint(x:x,y:y)
        })
    }
    public func loopTangent(_ progress:Double) -> CGPoint {
        let t=progress.truncatingRemainder(dividingBy:1)
        let a=point((t+1-0.00001).truncatingRemainder(dividingBy:1))
        let b=point((t+0.00001).truncatingRemainder(dividingBy:1))
        let length=max(0.000001,Geometry.distance(a,b))
        return CGPoint(x:(b.x-a.x)/length,y:(b.y-a.y)/length)
    }
    public func point(_ progress:Double) -> CGPoint {
        let distance=min(1,max(0,progress))*length
        var lo=0,hi=distances.count-1
        while hi-lo>1 { let mid=(lo+hi)/2;if distances[mid]<distance { lo=mid } else { hi=mid } }
        let t=(distance-distances[lo])/max(0.0000001,distances[hi]-distances[lo])
        return CGPoint(x:points[lo].x+(points[hi].x-points[lo].x)*t,y:points[lo].y+(points[hi].y-points[lo].y)*t)
    }
}

/// A smooth speed envelope independent of animation choice. Short flights have
/// a lower peak instead of accelerating just to qualify for a gliding pose.
public struct FlightTiming {
    public let distance,peakSpeed,acceleration,deceleration,duration:Double
    public var brakeStart:Double { duration-deceleration }
    public init(distance:Double,speed:Double,acceleration:Double=0.65,deceleration:Double=0.85) {
        self.distance=max(0,distance)
        let speed=max(1,speed),rampDistance=speed*(acceleration+deceleration)/2
        let factor=rampDistance>0 ? min(1,sqrt(self.distance/rampDistance)):1
        self.peakSpeed=speed*factor;self.acceleration=acceleration*factor;self.deceleration=deceleration*factor
        let ramps=self.acceleration+self.deceleration
        self.duration=max(0.001,ramps+max(0,self.distance-self.peakSpeed*ramps/2)/max(0.001,self.peakSpeed))
    }
    public func speed(at time:Double) -> Double {
        let t=min(duration,max(0,time))
        if acceleration>0 && t<acceleration { return peakSpeed*0.5*(1-cos(.pi*t/acceleration)) }
        if deceleration>0 && t>brakeStart { return peakSpeed*0.5*(1+cos(.pi*(t-brakeStart)/deceleration)) }
        return peakSpeed
    }
    public func progress(at time:Double) -> Double {
        let t=min(duration,max(0,time))
        if t>=duration || distance<=0 { return 1 }
        if acceleration>0 && t<acceleration { return peakSpeed*0.5*(t-acceleration / .pi*sin(.pi*t/acceleration))/distance }
        if deceleration>0 && t>brakeStart {
            let remaining=duration-t
            return 1-peakSpeed*0.5*(remaining-deceleration / .pi*sin(.pi*remaining/deceleration))/distance
        }
        return peakSpeed*(t-acceleration/2)/distance
    }
}
