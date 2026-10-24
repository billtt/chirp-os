import Foundation

public struct LifeRecord: Codable, Equatable {
    public var count: Int
    public let firstRecordedAt: Date
}

/// Separate from preferences: restoring bird settings never removes observations.
public struct LifeList: Codable {
    public var enabled = false
    public var introductionVersion: Int? = nil
    /// Run once for new installs and pre-introduction files, preserving every record.
    @discardableResult public mutating func prepareIntroduction() -> Bool {
        guard (introductionVersion ?? 0) < 1 else { return false }
        enabled = true; introductionVersion = 1; return true
    }
    public private(set) var records: [String: LifeRecord] = [:]
    public init() {}
    @discardableResult public mutating func record(_ species: SpeciesID, at date: Date = Date()) -> Bool {
        let key = species.rawValue
        if var previous = records[key] {
            previous.count += 1; records[key] = previous; return false
        }
        records[key] = LifeRecord(count: 1, firstRecordedAt: date); return true
    }
    public static func load(from url: URL) throws -> LifeList {
        guard FileManager.default.fileExists(atPath: url.path) else { return LifeList() }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(Self.self, from: Data(contentsOf: url))
        guard value.records.values.allSatisfy({ $0.count > 0 }) else {
            throw NSError(domain: "LifeList", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid observation counts"])
        }
        return value
    }
    public func save(to url: URL) throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

/// An object may move between windows/screens without becoming a new visit.
public final class ObservationVisits<Visit: Hashable> {
    private var eligible: Set<Visit> = []
    private var recorded: Set<Visit> = []
    public init() {}
    public func reset() { eligible.removeAll(); recorded.removeAll() }
    public func arrive(_ visit: Visit) { eligible.insert(visit) }
    public func contains(_ visit: Visit) -> Bool { eligible.contains(visit) }
    public func wasRecorded(_ visit: Visit) -> Bool { recorded.contains(visit) }
    public func commit(_ visit: Visit) { if eligible.contains(visit) { recorded.insert(visit) } }
    public func retain(_ visits: Set<Visit>) { eligible.formIntersection(visits); recorded.formIntersection(visits) }
}
