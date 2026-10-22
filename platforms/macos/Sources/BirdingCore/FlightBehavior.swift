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
    public static func frame(_ id: SpeciesID, age: Double, fps: Double, powered: Bool = false, banking: Double = 0) -> String {
        let m = motion(id), rate = max(4, fps)
        let t = max(0, age).truncatingRemainder(dividingBy: m.cycle)
        // End each powered burst on the extended-wing keyframe (fly2).
        let burst = max(8 / rate, (m.cycle * m.powered * rate / 8).rounded() * 8 / rate)
        if powered || m.powered >= 1 || t < burst {
            return "fly\((Int((powered ? max(0, age) : t) * rate) + 3) % 8)"
        }
        if m.style == .bounding { return "bound" }
        if abs(banking) > 0.3 { return "bank\(banking < 0 ? 0 : 2)" }
        return "glide1"
    }
    public static func smooth(_ t: Double) -> Double { let u = min(1, max(0, t)); return u*u*(3-2*u) }
}
