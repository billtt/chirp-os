import XCTest
import CryptoKit
@testable import BirdingCore

final class UpdateTests: XCTestCase {
    func fixture(version:String="v1.10.0",platform:String="macOS-arm64",digest:String?="sha256:"+String(repeating:"a",count:64),url:String?=nil,draft:Bool=false,prerelease:Bool=false) throws -> Data {
        let number=version.hasPrefix("v") ? String(version.dropFirst()):version
        let name="ChirpOS-\(number)-\(platform).zip"
        var asset:[String:Any]=["name":name,"browser_download_url":url ?? "https://github.com/billtt/chirp-os/releases/download/\(version)/\(name)","size":100,"state":"uploaded"]
        if let digest { asset["digest"]=digest }
        return try JSONSerialization.data(withJSONObject:["tag_name":version,"draft":draft,"prerelease":prerelease,"body":"## Changes\n- A fix","assets":[asset]])
    }
    func testNumericVersionsRejectNonStableInput() {
        XCTAssertGreaterThan(UpdateVersion("1.10.0")!,UpdateVersion("1.9.99")!)
        XCTAssertEqual(UpdateVersion("v1.2.3"),UpdateVersion("1.2.3"))
        for value in ["1.2","1.2.3-beta","1.2.3+debug","-1.2.3","1.2.３","1.2.3/evil","1.2.99999999999999999"] { XCTAssertNil(UpdateVersion(value),value) }
    }
    func testReleaseSelectionNeverDowngradesOrCrossesArchitecture() throws {
        let release=try UpdateRelease.select(fixture(),current:"1.9.0",platform:"macOS-arm64")
        XCTAssertEqual(release?.version,"1.10.0");XCTAssertTrue(release!.notes.contains("A fix"))
        XCTAssertNil(try UpdateRelease.select(fixture(),current:"1.10.0",platform:"macOS-arm64"))
        XCTAssertNil(try UpdateRelease.select(fixture(),current:"2.0.0",platform:"macOS-arm64"))
        XCTAssertNil(try UpdateRelease.select(fixture(),current:"1.0.0",platform:"macOS-x86_64"))
        XCTAssertNil(try UpdateRelease.select(fixture(draft:true),current:"1.0.0",platform:"macOS-arm64"))
        XCTAssertNil(try UpdateRelease.select(fixture(prerelease:true),current:"1.0.0",platform:"macOS-arm64"))
    }
    func testMissingDigestAndUntrustedDownloadsFailClosed() throws {
        for digest in [nil,"sha256:abc","md5:"+String(repeating:"a",count:64),"sha256:"+String(repeating:"g",count:64)] {
            XCTAssertThrowsError(try UpdateRelease.select(fixture(digest:digest),current:"1.0.0",platform:"macOS-arm64"))
        }
        for url in ["http://github.com/billtt/chirp-os/evil.zip","https://example.com/ChirpOS.zip","https://github.com/other/repo/releases/download/v1.10.0/ChirpOS-1.10.0-macOS-arm64.zip"] {
            XCTAssertThrowsError(try UpdateRelease.select(fixture(url:url),current:"1.0.0",platform:"macOS-arm64"))
        }
    }
    func folder() throws -> URL {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("chirpos-updater-tests-"+UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:root) };return root
    }
    func testHashDetectsSameSizeCorruptionAndTruncation() throws {
        let file=try folder().appendingPathComponent("archive.zip"),data=Data("hello".utf8)
        try data.write(to:file)
        let digest=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
        let release=UpdateRelease(version:"1.0.0",notes:"",assetName:"test",downloadURL:"",sha256:digest,size:5)
        XCTAssertNoThrow(try release.verify(file))
        try Data("jello".utf8).write(to:file);XCTAssertThrowsError(try release.verify(file))
        try Data("hi".utf8).write(to:file);XCTAssertThrowsError(try release.verify(file))
    }
    func testHourlySchedulingBackoffAndNotificationAcrossRestarts() throws {
        var state=UpdateJournal();let now=Date(timeIntervalSince1970:1000)
        state.finishCheck(now:now,success:true);XCTAssertEqual(state.nextCheck.timeIntervalSince(now),3600)
        for delay in [300.0,900,3600,3600] { state.finishCheck(now:now,success:false);XCTAssertEqual(state.nextCheck.timeIntervalSince(now),delay) }
        XCTAssertTrue(state.announce("1.0.0"))
        var restored=try JSONDecoder().decode(UpdateJournal.self,from:JSONEncoder().encode(state))
        XCTAssertFalse(restored.announce("1.0.0"));XCTAssertTrue(restored.announce("1.0.1"))
        restored.finishCheck(now:now,success:true);XCTAssertEqual(restored.failures,0)
    }
    func makeApp(_ root:URL,_ name:String,_ contents:String) throws -> URL {
        let app=root.appendingPathComponent(name);try FileManager.default.createDirectory(at:app,withIntermediateDirectories:true)
        try Data(contents.utf8).write(to:app.appendingPathComponent("version"));return app
    }
    func testReplacementRetainsOldVersionUntilHealthAcknowledgement() throws {
        let root=try folder(),app=try makeApp(root,"ChirpOS.app","old"),source=try makeApp(root,"download.app","new")
        let transaction=try UpdateReplacement(target:app,token:UUID().uuidString)
        try transaction.prepare(from:source)
        XCTAssertEqual(try String(contentsOf:app.appendingPathComponent("version")),"old")
        try transaction.replace()
        XCTAssertEqual(try String(contentsOf:app.appendingPathComponent("version")),"new")
        XCTAssertEqual(try String(contentsOf:transaction.backup.appendingPathComponent("version")),"old")
        try transaction.complete()
        XCTAssertFalse(FileManager.default.fileExists(atPath:transaction.backup.path))
        XCTAssertEqual(try String(contentsOf:app.appendingPathComponent("version")),"new")
    }
    func testFailedStartupRestoresOldAppAndFailedPrepareDoesNotTouchIt() throws {
        let root=try folder(),app=try makeApp(root,"ChirpOS.app","old"),source=try makeApp(root,"download.app","new")
        let transaction=try UpdateReplacement(target:app,token:UUID().uuidString)
        XCTAssertThrowsError(try transaction.prepare(from:root.appendingPathComponent("missing")))
        XCTAssertEqual(try String(contentsOf:app.appendingPathComponent("version")),"old")
        try transaction.prepare(from:source);try transaction.replace();try transaction.rollback()
        XCTAssertEqual(try String(contentsOf:app.appendingPathComponent("version")),"old")
        XCTAssertFalse(FileManager.default.fileExists(atPath:transaction.backup.path))
        XCTAssertThrowsError(try UpdateReplacement(target:app,token:"../arbitrary"))
        let link=root.appendingPathComponent("link/ChirpOS.app");try FileManager.default.createDirectory(at:link.deletingLastPathComponent(),withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:app)
        XCTAssertThrowsError(try UpdateReplacement(target:link,token:UUID().uuidString))
    }
    /// Minimal uncompressed ZIP fixture with independently configurable local names.
    func zip(_ name:String, localName:String?=nil, mode:UInt32=0o100644, size:UInt32=1, extra:Data=Data()) -> Data {
        var d=Data()
        func n(_ value:UInt32,_ count:Int) { for i in 0..<count { d.append(UInt8(truncatingIfNeeded:value >> (8*i))) } }
        let local=Data((localName ?? name).utf8),central=Data(name.utf8)
        n(0x04034b50,4);n(20,2);n(0,2);n(0,2);n(0,2);n(0,2);n(0,4);n(1,4);n(size,4);n(UInt32(local.count),2);n(UInt32(extra.count),2);d.append(local);d.append(extra);d.append(1)
        let start=UInt32(d.count)
        n(0x02014b50,4);n(0x0314,2);n(20,2);n(0,2);n(0,2);n(0,2);n(0,2);n(0,4);n(1,4);n(size,4);n(UInt32(central.count),2);n(UInt32(extra.count),2);n(0,2);n(0,2);n(0,2);n(mode << 16,4);n(0,4);d.append(central);d.append(extra)
        let length=UInt32(d.count)-start
        n(0x06054b50,4);n(0,2);n(0,2);n(1,2);n(1,2);n(length,4);n(start,4);n(0,2)
        return d
    }
    func testArchiveRejectsTraversalSymlinksBombsAndConflictingHeaders() throws {
        XCTAssertNoThrow(try UpdateArchive.validate(zip("ChirpOS.app/Contents/MacOS/Birding")))
        for name in ["../evil","/ChirpOS.app/file","ChirpOS.app/../evil","ChirpOS.app/a/../../evil","ChirpOS.app/a\\evil","other.app/file"] {
            XCTAssertThrowsError(try UpdateArchive.validate(zip(name)),name)
        }
        XCTAssertThrowsError(try UpdateArchive.validate(zip("ChirpOS.app/link",mode:0o120777)))
        XCTAssertThrowsError(try UpdateArchive.validate(zip("ChirpOS.app/file",localName:"ChirpOS.app/evil")))
        XCTAssertThrowsError(try UpdateArchive.validate(zip("ChirpOS.app/bomb",size:UInt32(1024*1024*1024+1))))
        XCTAssertThrowsError(try UpdateArchive.validate(Data([0,1,2])))
        for extra in [Data([0x75,0x70,0,0]),Data([1,0,0,0]),Data([0x55,0x54,20,0])] {
            XCTAssertThrowsError(try UpdateArchive.validate(zip("ChirpOS.app/file",extra:extra)))
        }
        XCTAssertNoThrow(try UpdateArchive.validate(zip("ChirpOS.app/file",extra:Data([0x55,0x54,1,0,0]))))
    }
}
