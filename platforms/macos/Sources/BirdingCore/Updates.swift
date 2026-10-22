import Foundation
import CryptoKit
import Darwin

public struct UpdateVersion: Comparable, Equatable {
    public let parts: [Int]
    public init?(_ text: String) {
        let s = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let fields = s.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count == 3, fields.allSatisfy({ !$0.isEmpty && $0.count <= 6 && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              fields.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = fields.map { Int($0)! }
    }
    public static func < (a: Self, b: Self) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
    public var description: String { parts.map(String.init).joined(separator: ".") }
}

public enum UpdateFailure: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil }
}

public struct UpdateRelease: Codable, Equatable {
    public let version, notes, assetName, downloadURL, sha256: String
    public let size: Int64
    public init(version:String,notes:String,assetName:String,downloadURL:String,sha256:String,size:Int64) {
        self.version=version;self.notes=notes;self.assetName=assetName;self.downloadURL=downloadURL;self.sha256=sha256;self.size=size
    }
    public static let endpoint = URL(string: "https://api.github.com/repos/billtt/chirp-os/releases/latest")!
    public static let maxDownload: Int64 = 512 * 1024 * 1024
    public static func select(_ data: Data, current: String, platform: String) throws -> Self? {
        struct Asset: Decodable { let name, browser_download_url, state: String; let digest: String?; let size: Int64 }
        struct Release: Decodable { let tag_name: String; let body: String?; let draft, prerelease: Bool; let assets: [Asset] }
        guard data.count <= 2_000_000, let installed = UpdateVersion(current) else { throw UpdateFailure.invalid("Invalid update metadata") }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard !release.draft, !release.prerelease, let version = UpdateVersion(release.tag_name), version > installed else { return nil }
        let name = "ChirpOS-\(version.description)-\(platform).zip"
        let matching = release.assets.filter { $0.name == name && $0.state == "uploaded" }
        guard matching.count == 1 else { return nil } // A release may not yet contain this platform.
        let asset = matching[0]
        let expectedURL = "https://github.com/billtt/chirp-os/releases/download/\(release.tag_name)/\(name)"
        guard asset.browser_download_url == expectedURL, asset.size > 0, asset.size <= maxDownload,
              let digest = asset.digest, digest.hasPrefix("sha256:"), validHash(String(digest.dropFirst(7))) else {
            throw UpdateFailure.invalid("Update package has no valid SHA-256 digest or download URL")
        }
        return Self(version: version.description, notes: String((release.body ?? "").prefix(20000)), assetName: name,
                    downloadURL: expectedURL, sha256: String(digest.dropFirst(7)).lowercased(), size: asset.size)
    }
    public static func validHash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { $0.isASCII && $0.isHexDigit } }
    public func verify(_ file: URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
        guard (attrs[.size] as? NSNumber)?.int64Value == size else { throw UpdateFailure.invalid("Update package size mismatch") }
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == sha256 else { throw UpdateFailure.invalid("Update package checksum mismatch") }
    }
}

public struct UpdateJournal: Codable {
    public var nextCheck = Date.distantPast
    public var announced: Set<String> = []
    public var failures = 0
    public init() {}
    public mutating func finishCheck(now: Date, success: Bool) {
        failures = success ? 0 : min(3, failures + 1)
        nextCheck = now.addingTimeInterval(success ? 3600 : [300.0, 900, 3600][failures - 1])
    }
    public mutating func announce(_ version: String) -> Bool { announced.insert(version).inserted }
}

/// Inspect both central and local ZIP names before using the system extractor.
/// Reject traversal, symbolic links, encrypted/ZIP64 archives and decompression bombs.
public enum UpdateArchive {
    @discardableResult public static func validate(_ data: Data) throws -> Int64 {
        func fail() throws -> Never { throw UpdateFailure.invalid("Unsafe or unsupported update archive") }
        func number(_ offset: Int, _ count: Int) -> UInt64 {
            guard offset >= 0, offset + count <= data.count else { return UInt64.max }
            return (0..<count).reduce(0) { $0 | UInt64(data[offset+$1]) << ($1*8) }
        }
        func checkExtra(_ start: Int, _ length: Int) throws {
            var cursor=start
            while cursor<start+length {
                guard cursor+4<=start+length else { try fail() }
                let kind=number(cursor,2), size=Int(number(cursor+2,2))
                // Alternate Unicode paths can override the names we inspected.
                guard kind != 0x7075, kind != 0x0001, cursor+4+size<=start+length else { try fail() }
                cursor += 4+size
            }
        }
        guard data.count >= 22 else { try fail() }
        var end: Int?
        for i in stride(from: data.count-22, through: max(0,data.count-65557), by: -1) {
            if number(i,4) == 0x06054b50 && i+22+Int(number(i+20,2)) == data.count { end=i; break }
        }
        guard let end, number(end+4,2) == 0, number(end+6,2) == 0 else { try fail() }
        let count=Int(number(end+10,2)), start=Int(number(end+16,4)), length=Int(number(end+12,4))
        guard count > 0, count < 10000, number(end+8,2) == UInt64(count), start >= 0, start+length == end else { try fail() }
        var offset=start, total:UInt64=0, names=Set<String>()
        for _ in 0..<count {
            guard offset+46 <= end, number(offset,4) == 0x02014b50 else { try fail() }
            let flags=number(offset+8,2), method=number(offset+10,2), size=number(offset+24,4), compressed=number(offset+20,4)
            let n=Int(number(offset+28,2)), extra=Int(number(offset+30,2)), comment=Int(number(offset+32,2)), local=Int(number(offset+42,4))
            guard n>0, offset+46+n+extra+comment <= end, local>=0, local+30 <= start,
                  flags & 1 == 0, method == 0 || method == 8, size != 0xffffffff,
                  (number(offset+38,4) >> 16) & 0xf000 != 0xa000,
                  number(local,4) == 0x04034b50, number(local+26,2) == UInt64(n), local+30+n <= start else { try fail() }
            let localExtra=Int(number(local+28,2))
            guard number(local+6,2)==flags, number(local+8,2)==method,
                  local+30+n+localExtra+Int(compressed)<=start else { try fail() }
            try checkExtra(offset+46+n,extra)
            try checkExtra(local+30+n,localExtra)
            let bytes=data.subdata(in:offset+46..<offset+46+n)
            guard bytes == data.subdata(in:local+30..<local+30+n), let name=String(data:bytes,encoding:.utf8),
                  !name.contains("\\"), !name.contains(":"), !name.contains("\0"), !name.hasPrefix("/"),
                  !name.split(separator:"/",omittingEmptySubsequences:false).contains(where:{$0 == ".." || $0 == "."}),
                  name == "ChirpOS.app/" || name.hasPrefix("ChirpOS.app/") || name.hasPrefix("__MACOSX/"),
                  names.insert(name).inserted else { try fail() }
            total += size
            guard total <= 1024*1024*1024 else { try fail() }
            offset += 46+n+extra+comment
        }
        guard offset == end else { try fail() }
        return Int64(total)
    }
}

/// Replacement paths are derived from the target and a UUID, never from ZIP entries.
public struct UpdateReplacement {
    public let target, candidate, backup: URL
    public init(target: URL, token: String) throws {
        guard UUID(uuidString:token) != nil, target.isFileURL, target.lastPathComponent == "ChirpOS.app",
              target.standardizedFileURL == target.resolvingSymlinksInPath() else { throw UpdateFailure.invalid("Invalid update destination") }
        self.target=target
        candidate=target.deletingLastPathComponent().appendingPathComponent(".ChirpOS-\(token).new.app")
        backup=target.deletingLastPathComponent().appendingPathComponent(".ChirpOS-\(token).old.app")
    }
    public func prepare(from source: URL) throws {
        guard !FileManager.default.fileExists(atPath:candidate.path), !FileManager.default.fileExists(atPath:backup.path) else { throw UpdateFailure.invalid("An update transaction already exists") }
        do { try FileManager.default.copyItem(at:source,to:candidate) }
        catch { try? FileManager.default.removeItem(at:candidate);throw error }
    }
    public func replace() throws {
        let fm=FileManager.default
        // Atomic directory exchange keeps the launch path valid across power loss.
        guard renameatx_np(AT_FDCWD,target.path,AT_FDCWD,candidate.path,UInt32(RENAME_SWAP)) == 0 else { throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno)) }
        do { try fm.moveItem(at:candidate,to:backup) }
        catch {
            _ = renameatx_np(AT_FDCWD,target.path,AT_FDCWD,candidate.path,UInt32(RENAME_SWAP))
            throw error
        }
    }
    public func rollback() throws {
        let fm=FileManager.default
        guard fm.fileExists(atPath:backup.path) else { return }
        if fm.fileExists(atPath:target.path) {
            guard renameatx_np(AT_FDCWD,target.path,AT_FDCWD,backup.path,UInt32(RENAME_SWAP)) == 0 else { throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno)) }
            try? fm.removeItem(at:backup)
        } else { try fm.moveItem(at:backup,to:target) }
    }
    public func complete() throws {
        if FileManager.default.fileExists(atPath:backup.path) { try FileManager.default.removeItem(at:backup) }
        if FileManager.default.fileExists(atPath:candidate.path) { try FileManager.default.removeItem(at:candidate) }
    }
}
