import Foundation

/// Desktop interpretations of characteristic actions, not field-measured frequencies.
/// Keep the explicit species schedules in sync with Windows SpeciesBehavior.
public enum SpeciesBehavior {
    public enum Action { case watch, stalk, tail, scan, bow, probe, wing, dabble, call, glean, rock, hammer, peck, crack }
    public struct Motion {
        public let action: Action
        public let cycle, start, duration, rate, hop: Double
    }
    public static func motion(_ id: SpeciesID) -> Motion {
        switch id {
        case .silkyStarling: return Motion(action: .bow, cycle: 13.32, start: 3, duration: 2.2, rate: 2, hop: 0)
        case .crestedMyna: return Motion(action: .peck, cycle: 9.48, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .greatCrestedGrebe: return Motion(action: .watch, cycle: 19, start: 5, duration: 2.4, rate: 2, hop: 0)
        case .daurianRedstart: return Motion(action: .tail, cycle: 6.6, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .taiwanBarbet: return Motion(action: .call, cycle: 17.16, start: 4, duration: 2.8, rate: 2, hop: 0)
        case .groundTit: return Motion(action: .probe, cycle: 11.92, start: 3, duration: 2.4, rate: 3, hop: 0)
        case .greatEgret: return Motion(action: .stalk, cycle: 26.92, start: 5, duration: 3, rate: 1.6, hop: 0)
        case .uplandBuzzard: return Motion(action: .scan, cycle: 26.44, start: 7, duration: 3, rate: 1.2, hop: 0)
        case .littleGrebe: return Motion(action: .watch, cycle: 19, start: 5, duration: 2.4, rate: 2, hop: 0)
        case .carrionCrow: return Motion(action: .bow, cycle: 15.24, start: 3, duration: 2.2, rate: 2, hop: 0)
        case .plainLaughingthrush: return Motion(action: .peck, cycle: 9.48, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .orientalTurtleDove: return Motion(action: .bow, cycle: 14.04, start: 3, duration: 2.2, rate: 2, hop: 0)
        case .easternSpotBilledDuck: return Motion(action: .dabble, cycle: 25.2, start: 6, duration: 3, rate: 1.5, hop: 0)
        case .eurasianNuthatch: return Motion(action: .probe, cycle: 11.52, start: 3, duration: 2.4, rate: 3, hop: 0)
        case .rufousBreastedAccentor: return Motion(action: .peck, cycle: 8.76, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .eurasianMagpie: return Motion(action: .tail, cycle: 9.08, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .eurasianGreatTit: return Motion(action: .hammer, cycle: 8.52, start: 2, duration: 2, rate: 5, hop: 1)
        case .marshTit: return Motion(action: .hammer, cycle: 8.36, start: 2, duration: 2, rate: 5, hop: 1)
        case .ashyDrongo: return Motion(action: .tail, cycle: 7.72, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .eurasianCollaredDove: return Motion(action: .bow, cycle: 13.96, start: 3, duration: 2.2, rate: 2, hop: 0)
        case .greyTreepie: return Motion(action: .tail, cycle: 8.44, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .whiteCheekedStarling: return Motion(action: .peck, cycle: 9.32, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .henricsLaughingthrush: return Motion(action: .peck, cycle: 9.32, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .indianWhiteEye: return Motion(action: .glean, cycle: 5.2, start: 1, duration: 1.8, rate: 5, hop: 1.2)
        case .easternCattleEgret: return Motion(action: .stalk, cycle: 23.4, start: 5, duration: 3, rate: 1.6, hop: 0)
        case .commonPheasant: return Motion(action: .peck, cycle: 14.2, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .sootyHeadedBulbul: return Motion(action: .call, cycle: 17.0, start: 4, duration: 2.8, rate: 2, hop: 0)
        case .whiteBrowedLaughingthrush: return Motion(action: .peck, cycle: 9.8, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .whiteWagtail: return Motion(action: .tail, cycle: 5.5, start: 1, duration: 2.2, rate: 4, hop: 0)
        case .blueWhistlingThrush: return Motion(action: .tail, cycle: 8.04, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .redBilledChough: return Motion(action: .probe, cycle: 13.52, start: 3, duration: 2.4, rate: 3, hop: 0)
        case .redBilledBlueMagpie: return Motion(action: .tail, cycle: 10.6, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .blackThroatedBushtit: return Motion(action: .glean, cycle: 5.2, start: 1, duration: 1.8, rate: 5, hop: 1.8)
        case .greenBackedTit: return Motion(action: .hammer, cycle: 8.44, start: 2, duration: 2, rate: 5, hop: 1)
        case .blueThroatedBarbet: return Motion(action: .call, cycle: 17.24, start: 4, duration: 2.8, rate: 2, hop: 0)
        case .blueFrontedRedstart: return Motion(action: .tail, cycle: 6.6, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .greaterCoucal: return Motion(action: .call, cycle: 19.24, start: 4, duration: 2.8, rate: 2, hop: 0)
        case .hornedLark: return Motion(action: .peck, cycle: 8.76, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .redThroatedThrush: return Motion(action: .peck, cycle: 9.32, start: 2, duration: 1.8, rate: 4, hop: 0)
        case .ruddyShelduck: return Motion(action: .dabble, cycle: 25.52, start: 6, duration: 3, rate: 1.5, hop: 0)
        case .blackRedstart: return Motion(action: .tail, cycle: 6.84, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .daurianJackdaw: return Motion(action: .bow, cycle: 14.12, start: 3, duration: 2.2, rate: 2, hop: 0)
        case .greyCappedGreenfinch: return Motion(action: .crack, cycle: 13.52, start: 4, duration: 2.6, rate: 3, hop: 0)
        case .silverThroatedBushtit: return Motion(action: .glean, cycle: 5.44, start: 1, duration: 1.8, rate: 5, hop: 1.8)
        case .commonTailorbird: return Motion(action: .tail, cycle: 6.36, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .collaredFinchbill: return Motion(action: .crack, cycle: 14.16, start: 4, duration: 2.6, rate: 3, hop: 0)
        case .himalayanVulture: return Motion(action: .scan, cycle: 32, start: 10, duration: 4, rate: 0.8, hop: 0)
        case .twite: return Motion(action: .crack, cycle: 13.52, start: 4, duration: 2.6, rate: 3, hop: 0)
        case .yellowBilledBlueMagpie: return Motion(action: .tail, cycle: 10.2, start: 1.5, duration: 2, rate: 4, hop: 0)
        case .ornateSunbird: return Motion(action: .probe, cycle: 11.28, start: 3, duration: 2.4, rate: 3, hop: 0)
        case .brownBreastedBulbul: return Motion(action: .call, cycle: 17.08, start: 4, duration: 2.8, rate: 2, hop: 0)
        case .whiskeredYuhina: return Motion(action: .glean, cycle: 5.44, start: 1, duration: 1.8, rate: 5, hop: 1.2)
        case .blackTailedGull: return Motion(action: .bow, cycle: 15.24, start: 3, duration: 2.2, rate: 2, hop: 0)
        case .blackBulbul: return Motion(action: .call, cycle: 17.4, start: 4, duration: 2.8, rate: 2, hop: 0)
        case .littleOwl: return Motion(action: .bow, cycle: 9.5, start: 2, duration: 1.8, rate: 3, hop: 0)
        case .asianBarredOwlet: return Motion(action: .scan, cycle: 12, start: 3, duration: 2.2, rate: 2.2, hop: 0)
        case .collaredScopsOwl: return Motion(action: .call, cycle: 19, start: 4, duration: 2.4, rate: 1.6, hop: 0)
        case .nightHeron: return Motion(action: .watch, cycle: 53, start: 20, duration: 2, rate: 1, hop: 0)
        case .plumbeousWaterRedstart: return Motion(action: .tail, cycle: 6, start: 1.5, duration: 1.4, rate: 5, hop: 0)
        case .littleEgret: return Motion(action: .stalk, cycle: 19, start: 4, duration: 2.5, rate: 2, hop: 0)
        case .greyHeron: return Motion(action: .watch, cycle: 29, start: 9, duration: 3, rate: 1, hop: 0)
        case .commonKestrel: return Motion(action: .scan, cycle: 13, start: 3, duration: 2, rate: 2, hop: 0)
        case .peregrineFalcon: return Motion(action: .scan, cycle: 21, start: 6, duration: 2.6, rate: 1, hop: 0)
        case .blackKite: return Motion(action: .scan, cycle: 24, start: 8, duration: 3, rate: 1.2, hop: 0)
        case .commonBuzzard: return Motion(action: .scan, cycle: 27, start: 10, duration: 3.5, rate: 0.8, hop: 0)
        case .orientalMagpie: return Motion(action: .tail, cycle: 11, start: 2, duration: 2, rate: 2, hop: 1)
        case .azureWingedMagpie: return Motion(action: .tail, cycle: 8, start: 1.5, duration: 2, rate: 3, hop: 1.8)
        case .largeBilledCrow: return Motion(action: .bow, cycle: 18, start: 4, duration: 2.4, rate: 1.5, hop: 0)
        case .hoopoe: return Motion(action: .probe, cycle: 12, start: 3, duration: 2.4, rate: 3, hop: 0)
        case .barnSwallow: return Motion(action: .wing, cycle: 10, start: 2, duration: 1.5, rate: 5, hop: 0)
        case .mallard: return Motion(action: .dabble, cycle: 22, start: 5, duration: 3, rate: 1.4, hop: 0)
        case .asianKoel: return Motion(action: .call, cycle: 17, start: 3, duration: 2.8, rate: 2, hop: 0)
        case .swinhoesWhiteEye: return Motion(action: .glean, cycle: 6.5, start: 1, duration: 1.6, rate: 5, hop: 1.5)
        case .blackHeadedGull: return Motion(action: .bow, cycle: 16, start: 4, duration: 2, rate: 2, hop: 0)
        case .whimbrel: return Motion(action: .probe, cycle: 15, start: 4, duration: 2.5, rate: 1.5, hop: 0)
        case .piedKingfisher: return Motion(action: .watch, cycle: 14, start: 3, duration: 2, rate: 3, hop: 0)
        case .eurasianWoodcock: return Motion(action: .rock, cycle: 9, start: 2, duration: 2.8, rate: 3, hop: 0)
        case .blackDrongo: return Motion(action: .tail, cycle: 7, start: 2, duration: 1.6, rate: 4, hop: 0)
        case .chinesePondHeron: return Motion(action: .stalk, cycle: 25, start: 6, duration: 2.6, rate: 1.5, hop: 0)
        case .yellowRumpedFlycatcher: return Motion(action: .wing, cycle: 7.5, start: 1.5, duration: 1.4, rate: 5, hop: 1)
        case .yellowBrowedWarbler: return Motion(action: .glean, cycle: 5.5, start: 1, duration: 1.8, rate: 6, hop: 1.2)
        case .greatTit: return Motion(action: .hammer, cycle: 8.5, start: 2, duration: 2, rate: 5, hop: 1)
        case .commonMoorhen: return Motion(action: .tail, cycle: 10.5, start: 2, duration: 2, rate: 3, hop: 0)
        case .greatSpottedWoodpecker: return Motion(action: .hammer, cycle: 12, start: 4, duration: 1.6, rate: 12, hop: 0)
        case .vinousThroatedParrotbill: return Motion(action: .tail, cycle: 6.8, start: 1, duration: 2, rate: 4, hop: 2)
        case .blackWingedStilt: return Motion(action: .stalk, cycle: 18.5, start: 5, duration: 3, rate: 1.4, hop: 0)
        case .eurasianCoot: return Motion(action: .dabble, cycle: 20, start: 6, duration: 2.5, rate: 1.8, hop: 0)
        case .redBilledLeiothrix: return Motion(action: .glean, cycle: 7.8, start: 2, duration: 1.8, rate: 4, hop: 1.6)
        case .blackCollaredStarling: return Motion(action: .bow, cycle: 13.5, start: 3, duration: 2, rate: 2.4, hop: 0)
        case .commonKingfisher: return Motion(action: .watch, cycle: 18, start: 5, duration: 2, rate: 2, hop: 0)
        case .littleRingedPlover: return Motion(action: .peck, cycle: 8, start: 1, duration: 1.2, rate: 4, hop: 0)
        case .yellowBilledGrosbeak: return Motion(action: .crack, cycle: 15.5, start: 4, duration: 2.5, rate: 3, hop: 0)
        case .redFlankedBluetail: return Motion(action: .tail, cycle: 6.2, start: 1.8, duration: 1.4, rate: 4, hop: 0.8)
        case .redWhiskeredBulbul: return Motion(action: .call, cycle: 10, start: 2, duration: 2.2, rate: 3, hop: 1)
        case .treeSparrow: return Motion(action: .peck, cycle: 9, start: 1, duration: 1, rate: 6, hop: 3)
        case .lightVentedBulbul: return Motion(action: .scan, cycle: 11.5, start: 3, duration: 2, rate: 2.5, hop: 1)
        case .spottedDove: return Motion(action: .bow, cycle: 14.5, start: 2, duration: 2.6, rate: 2, hop: 0)
        case .chineseBlackbird: return Motion(action: .peck, cycle: 12.5, start: 2, duration: 1.8, rate: 3, hop: 0)
        case .magpieRobin: return Motion(action: .tail, cycle: 8.8, start: 1, duration: 2.6, rate: 3.5, hop: 1)
        case .longTailedShrike: return Motion(action: .scan, cycle: 16.5, start: 3, duration: 3, rate: 1.2, hop: 0)
        }
    }
    public static func hop(_ id: SpeciesID, age: Double) -> Double {
        let m = motion(id), t = max(0, age).truncatingRemainder(dividingBy: m.cycle) - m.start
        guard t > 0 && t < m.duration else { return 0 }
        // Whole arches meet the perch at both ends; no discontinuous vertical jump.
        return -m.hop * abs(sin(t / m.duration * Double.pi * 2))
    }
    public static func frame(_ id: SpeciesID, age: Double, side: Bool = false) -> String? {
        let age = max(0, age)
        if id == .eurasianNuthatch && side {
            let t = age.truncatingRemainder(dividingBy: 10)
            return t > 3 && t < 5 ? "peck\(Int(t * 4) % 2)" : "cling0"
        }
        if id == .greatSpottedWoodpecker && side {
            let t = age.truncatingRemainder(dividingBy: 12)
            return t > 4 && t < 5.6 ? "peck\(Int(t * 12) % 2)" : "cling0"
        }
        if id == .nightHeron {
            let t = age.truncatingRemainder(dividingBy: 53)
            if t > 31 && t < 32 { return "poop\(Int((t - 31) * 6) % 2)" }
            if t > 20 && t < 22 { return "stretch" }
            if t > 40 && t < 41 { return Int(t * 8) % 2 == 0 ? "shake" : "stand" }
            return t.truncatingRemainder(dividingBy: 7) > 6.8 ? "blink" : "stand"
        }
        let m = motion(id), t = age.truncatingRemainder(dividingBy: m.cycle)
        if t > m.start && t < m.start + m.duration {
            let pose = [0, 1, 2, 1][Int((t - m.start) * m.rate) % 4]
            return "idle\(pose)"
        }
        if t > m.cycle - 1.6 && t < m.cycle - 0.5 { return "preen\(Int(t * 3) % 2)" }
        if t < 0.12 { return "blink" }
        return Int(age * 1.2) % 2 == 0 ? "stand" : "breathe"
    }
}
