import XCTest
@testable import BirdingCore

final class LifeListTests: XCTestCase {
    func testFirstDateSurvivesLaterVisitsAndToggle() throws {
        var list=LifeList(); let first=Date(timeIntervalSince1970:1000)
        XCTAssertTrue(list.record(.treeSparrow,at:first))
        XCTAssertFalse(list.record(.treeSparrow,at:Date(timeIntervalSince1970:2000)))
        list.enabled=true;list.enabled=false
        XCTAssertEqual(list.records["treeSparrow"],LifeRecord(count:2,firstRecordedAt:first))
        XCTAssertTrue(list.record(.nightHeron,at:first))
        XCTAssertEqual(list.records.count,2)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let url=folder.appendingPathComponent("life-list.json")
        try list.save(to:url)
        let restored=try LifeList.load(from:url)
        XCTAssertEqual(restored.records,list.records);XCTAssertFalse(restored.enabled)
    }
    func testIntroductionMigratesOnceAndRespectsLaterOptOut() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let url=folder.appendingPathComponent("life-list.json")
        var fresh=try LifeList.load(from:url)
        XCTAssertTrue(fresh.prepareIntroduction());XCTAssertTrue(fresh.enabled)
        // Earlier builds had no introduction marker and could be disabled.
        var legacy=LifeList();legacy.record(.treeSparrow,at:Date(timeIntervalSince1970:1000));try legacy.save(to:url)
        var upgraded=try LifeList.load(from:url)
        XCTAssertTrue(upgraded.prepareIntroduction());XCTAssertTrue(upgraded.enabled)
        XCTAssertEqual(upgraded.records,legacy.records)
        upgraded.enabled=false;try upgraded.save(to:url)
        var restarted=try LifeList.load(from:url)
        XCTAssertFalse(restarted.prepareIntroduction());XCTAssertFalse(restarted.enabled)
        XCTAssertEqual(restarted.records,legacy.records)
    }
    func testOldBirdsAreIneligibleAndSameVisitStaysRecorded() {
        let visits=ObservationVisits<Int>()
        visits.arrive(1);visits.commit(1)
        XCTAssertTrue(visits.wasRecorded(1));visits.retain([1,2])
        XCTAssertTrue(visits.wasRecorded(1));XCTAssertFalse(visits.contains(2))
        visits.reset() // Mode switch invalidates even still-visible birds.
        XCTAssertFalse(visits.contains(1));visits.commit(1);XCTAssertFalse(visits.wasRecorded(1))
        visits.arrive(2);XCTAssertFalse(visits.wasRecorded(2))
        visits.retain([]);visits.arrive(2);XCTAssertFalse(visits.wasRecorded(2))
    }
    func testDamagedFileIsNotSilentlyReset() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:url)}
        let original=Data("not json".utf8);try original.write(to:url)
        XCTAssertThrowsError(try LifeList.load(from:url))
        XCTAssertEqual(try Data(contentsOf:url),original)
    }
}
