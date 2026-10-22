import Foundation

// Integer hundredths of a percent keep displayed and stored totals exactly 100.00%.
public struct ProbabilityEntry: Codable, Equatable {
    public let id: SpeciesID
    public var points: Int
    public var locked: Bool
}
public struct ProbabilityDistribution: Codable, Equatable {
    public private(set) var entries: [ProbabilityEntry]
    public init(catalog: SpeciesCatalog) {
        let values = Self.apportion(10_000, amounts:catalog.species.map(\.weight))
        entries = zip(catalog.species,values).map { ProbabilityEntry(id:$0.0.id,points:$0.1,locked:false) }
    }
    // Existing percentages and locks remain exact. New species start disabled in
    // an existing profile until the user adjusts them or restores defaults.
    public mutating func includeNewSpecies() throws {
        guard !entries.isEmpty, Set(entries.map(\.id)).count == entries.count,
              entries.allSatisfy({ (0...10_000).contains($0.points) }),
              entries.reduce(0, { $0 + $1.points }) == 10_000 else {
            throw NSError(domain:"BirdSettings",code:2)
        }
        let present = Set(entries.map(\.id))
        entries += SpeciesCatalog.standard.species.filter { !present.contains($0.id) }
            .map { ProbabilityEntry(id:$0.id,points:0,locked:false) }
    }
    public mutating func allocateNewSpecies(_ ids:[SpeciesID], catalog:SpeciesCatalog) {
        let fresh=Set(ids)
        let added=entries.indices.filter{fresh.contains(entries[$0].id)}
        let old=entries.indices.filter{!fresh.contains(entries[$0].id)}
        guard !added.isEmpty else {return}
        let budget=Int((10000*Double(added.count)/Double(entries.count)).rounded())
        let newPoints=Self.apportion(budget,amounts:added.map{catalog.profile(entries[$0].id).weight})
        let oldPoints=Self.apportion(10000-budget,amounts:old.map{Double(entries[$0].points)})
        for (i,n) in zip(added,newPoints) {entries[i].points=n}
        for (i,n) in zip(old,oldPoints) {entries[i].points=n}
    }
    public var isValid: Bool {
        entries.count == SpeciesID.allCases.count && Set(entries.map(\.id)) == Set(SpeciesID.allCases) &&
        entries.allSatisfy { (0...10_000).contains($0.points) } && entries.reduce(0) { $0+$1.points } == 10_000
    }
    public mutating func setLocked(_ locked:Bool, at index:Int) { entries[index].locked = locked }
    public func maximum(at index:Int) -> Int {
        10_000 - entries.enumerated().filter { $0.offset != index && $0.element.locked }.reduce(0) { $0+$1.element.points }
    }
    public func canAdjust(_ index:Int) -> Bool {
        !entries[index].locked && entries.indices.contains { $0 != index && !entries[$0].locked }
    }
    @discardableResult public mutating func adjust(at index:Int, to requested:Int) -> Int {
        guard canAdjust(index) else { return entries[index].points }
        let value = min(maximum(at:index),max(0,requested))
        let peers = entries.indices.filter { $0 != index && !entries[$0].locked }
        let remainder = maximum(at:index)-value
        let amounts = Self.apportion(remainder,amounts:peers.map { Double(entries[$0].points) })
        entries[index].points = value
        for (peer,amount) in zip(peers,amounts) { entries[peer].points = amount }
        return value
    }
    // Preserve proportions; distribute equally when every eligible peer is zero.
    // Largest remainders receive rounding units, with stable index tie breaking.
    private static func apportion(_ total:Int, amounts:[Double]) -> [Int] {
        guard !amounts.isEmpty else { return [] }
        let sum = amounts.reduce(0,+)
        let exact = amounts.map { sum > 0 ? Double(total)*$0/sum : Double(total)/Double(amounts.count) }
        var result = exact.map { Int($0.rounded(.down)) }
        let order = exact.indices.sorted {
            let a = exact[$0]-Double(result[$0]), b = exact[$1]-Double(result[$1])
            return a == b ? $0 < $1 : a > b
        }
        for i in order.prefix(max(0,total-result.reduce(0,+))) { result[i] += 1 }
        return result
    }
    public func choose(unit:Double = Double.random(in:0..<1)) -> SpeciesID {
        var ticket = Int(min(1-Double.ulpOfOne,max(0,unit.isFinite ? unit : 0))*10_000)
        for entry in entries where entry.points > 0 {
            if ticket < entry.points { return entry.id }; ticket -= entry.points
        }
        return entries.last(where: { $0.points > 0 })!.id
    }
}
public struct BirdSettings: Codable {
    public var catalog: SpeciesCatalog
    public var probabilities: ProbabilityDistribution
    public var perchDefaultsVersion: Int? = nil
    public var pendingSpecies: [SpeciesID]? = nil
    public init(catalog:SpeciesCatalog = .standard) {
        self.catalog = catalog; probabilities = ProbabilityDistribution(catalog:catalog); perchDefaultsVersion=1
    }
    public static func decode(_ data:Data) throws -> BirdSettings {
        var value = try JSONDecoder().decode(Self.self,from:data)
        guard Set(value.catalog.species.map(\.id)).count == value.catalog.species.count else { throw NSError(domain:"BirdSettings",code:3) }
        let present = Set(value.catalog.species.map(\.id))
        guard present == Set(value.probabilities.entries.map(\.id)) else {throw NSError(domain:"BirdSettings",code:4)}
        let added=SpeciesCatalog.standard.species.filter { !present.contains($0.id) }
        let pending=Set(value.pendingSpecies ?? []).union(added.map(\.id))
        value.pendingSpecies=SpeciesCatalog.standard.species.map(\.id).filter{pending.contains($0)}
        // Upgrade only old default wingbeat values. User-adjusted rates survive.
        for i in value.catalog.species.indices {
            let id=value.catalog.species[i].id, current=SpeciesCatalog.standard.profile(value.catalog.species[i].id).flapFPS
            let old=current / FlightBehavior.motion(id).rate
            if abs(value.catalog.species[i].flapFPS-old) < 0.0001 { value.catalog.species[i].flapFPS=current }
        }
        if (value.perchDefaultsVersion ?? 0)<1 {
            for i in value.catalog.species.indices {
                let current=SpeciesCatalog.standard.profile(value.catalog.species[i].id)
                // Only migrate the complete former default range, never a custom endpoint.
                if value.catalog.species[i].perchMin == current.perchMin/2 && value.catalog.species[i].perchMax == current.perchMax/2 {
                    value.catalog.species[i].perchMin=current.perchMin
                    value.catalog.species[i].perchMax=current.perchMax
                }
            }
        }
        value.perchDefaultsVersion=1
        value.catalog.species += added
        try value.probabilities.includeNewSpecies()
        _ = try SpeciesCatalog.decode(JSONEncoder().encode(value.catalog))
        guard value.probabilities.isValid else { throw NSError(domain:"BirdSettings",code:1) }
        return value
    }
    public func save(to url:URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let data = try encoder.encode(self)
        _ = try Self.decode(data)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:url,options:.atomic)
    }
    public static func load(from url:URL, legacyURL:URL) throws -> BirdSettings {
        if FileManager.default.fileExists(atPath:url.path) { return try decode(Data(contentsOf:url)) }
        if FileManager.default.fileExists(atPath:legacyURL.path) {
            var catalog=try JSONDecoder().decode(SpeciesCatalog.self,from:Data(contentsOf:legacyURL))
            let original=catalog
            let ids=Set(catalog.species.map(\.id))
            catalog.species += SpeciesCatalog.standard.species.filter{!ids.contains($0.id)}
            var result=BirdSettings(catalog:try SpeciesCatalog.decode(JSONEncoder().encode(catalog)))
            result.probabilities=ProbabilityDistribution(catalog:original)
            try result.probabilities.includeNewSpecies()
            result.pendingSpecies=catalog.species.map(\.id).filter{!ids.contains($0)}
            result.perchDefaultsVersion=nil
            return try decode(JSONEncoder().encode(result))
        }
        return BirdSettings()
    }
}
