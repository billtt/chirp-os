import Foundation

public enum SpeciesID: String, Codable, CaseIterable {
    case silkyStarling, crestedMyna, greatCrestedGrebe, daurianRedstart, taiwanBarbet, groundTit, greatEgret, uplandBuzzard, littleGrebe, carrionCrow, plainLaughingthrush, orientalTurtleDove, easternSpotBilledDuck, eurasianNuthatch, rufousBreastedAccentor, eurasianMagpie, eurasianGreatTit, marshTit, ashyDrongo, eurasianCollaredDove, greyTreepie, whiteCheekedStarling, henricsLaughingthrush, indianWhiteEye, easternCattleEgret, commonPheasant, sootyHeadedBulbul, whiteBrowedLaughingthrush, whiteWagtail, blueWhistlingThrush, redBilledChough, redBilledBlueMagpie, blackThroatedBushtit, greenBackedTit, blueThroatedBarbet, blueFrontedRedstart, greaterCoucal, hornedLark, redThroatedThrush, ruddyShelduck, blackRedstart, daurianJackdaw, greyCappedGreenfinch, silverThroatedBushtit, commonTailorbird, collaredFinchbill, himalayanVulture, twite, yellowBilledBlueMagpie, ornateSunbird, brownBreastedBulbul, whiskeredYuhina, blackTailedGull, blackBulbul
    case collaredScopsOwl, asianBarredOwlet, littleOwl
    case nightHeron, plumbeousWaterRedstart, littleEgret, greyHeron, commonKestrel, peregrineFalcon, blackKite, commonBuzzard, orientalMagpie, azureWingedMagpie, largeBilledCrow, hoopoe, barnSwallow, mallard, asianKoel, swinhoesWhiteEye, blackHeadedGull, whimbrel, piedKingfisher, eurasianWoodcock, blackDrongo, chinesePondHeron, yellowRumpedFlycatcher, yellowBrowedWarbler, greatTit, commonMoorhen, greatSpottedWoodpecker, vinousThroatedParrotbill, blackWingedStilt, eurasianCoot, redBilledLeiothrix, blackCollaredStarling, commonKingfisher, littleRingedPlover, yellowBilledGrosbeak, redFlankedBluetail
    case redWhiskeredBulbul, treeSparrow, lightVentedBulbul, spottedDove, chineseBlackbird, magpieRobin, longTailedShrike
}
public struct SpeciesProfile: Codable, Equatable {
    public let id: SpeciesID
    public let name: String
    public var englishName: String? = nil
    public var scientificName: String? = nil
    public var appearanceNotes: String? = nil
    public var adultLengthCM: Double
    public let weight: Double
    public var flapFPS: Double
    public var speed: Double
    public var perchMin: Double
    public var perchMax: Double
    public let weightBasis: String
    // Compress adult-length ratios: 19 cm bulbul = 1×, 94 cm heron = 2.5×.
    public var relativeScale: Double { pow(adultLengthCM / 19, log(2.5) / log(94.0 / 19)) }
}
public struct SpeciesCatalog: Codable {
    public var species: [SpeciesProfile]
    public static let standard: SpeciesCatalog = {
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("Birding_BirdingCore.bundle/species.json")
        let url = packaged.flatMap { FileManager.default.fileExists(atPath:$0.path) ? $0 : nil }
            ?? Bundle.module.url(forResource: "species", withExtension: "json")!
        return try! decode(Data(contentsOf: url))
    }()
    public static func decode(_ data: Data) throws -> SpeciesCatalog {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard Set(value.species.map(\.id)) == Set(SpeciesID.allCases), value.species.count == SpeciesID.allCases.count,
              value.species.allSatisfy({ $0.adultLengthCM.isFinite && (8...110).contains($0.adultLengthCM) &&
                  $0.weight.isFinite && (0...1_000_000).contains($0.weight) &&
                  $0.flapFPS.isFinite && (4...60).contains($0.flapFPS) &&
                  $0.speed.isFinite && (0.5...2).contains($0.speed) &&
                  $0.perchMin.isFinite && $0.perchMax.isFinite && (2...300).contains($0.perchMin) &&
                  ($0.perchMin...600).contains($0.perchMax) }), value.species.contains(where: {$0.weight > 0}) else {
            throw NSError(domain: "Birding.Species", code: 1, userInfo: [NSLocalizedDescriptionKey: "鸟种配置无效：需要全部鸟种，正体长、合法动画参数和至少一个正权重。"])
        }
        return value
    }
    public func profile(_ id: SpeciesID) -> SpeciesProfile { species.first { $0.id == id }! }
    public func choose(unit: Double = Double.random(in: 0..<1)) -> SpeciesProfile {
        let enabled = species.filter { $0.weight > 0 }
        var ticket = min(1-Double.ulpOfOne, max(0, unit.isFinite ? unit : 0)) * enabled.reduce(0) { $0 + $1.weight }
        for profile in enabled {
            if ticket < profile.weight { return profile }
            ticket -= profile.weight
        }
        return enabled.last!
    }
}
