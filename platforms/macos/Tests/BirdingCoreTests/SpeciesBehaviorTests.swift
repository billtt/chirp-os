import XCTest
@testable import BirdingCore

final class SpeciesBehaviorTests: XCTestCase {
    func testEverySpeciesHasReachableActionAndQuietRecovery() {
        for id in SpeciesID.allCases {
            let m = SpeciesBehavior.motion(id)
            XCTAssertGreaterThan(m.start, 0)
            XCTAssertLessThan(m.start + m.duration, m.cycle - 1.6)
            let frames = Set((0..<Int(m.cycle * 60)).compactMap {
                SpeciesBehavior.frame(id, age: Double($0) / 60)
            })
            XCTAssertTrue(frames.contains("stand"), id.rawValue)
            if id == .nightHeron { continue }
            for pose in ["idle0", "idle1", "idle2", "preen0", "preen1", "blink"] {
                XCTAssertTrue(frames.contains(pose), "\(id): \(pose)")
            }
            XCTAssertEqual(SpeciesBehavior.hop(id, age: m.start), 0, accuracy: 0.000001)
            XCTAssertEqual(SpeciesBehavior.hop(id, age: m.start + m.duration), 0, accuracy: 0.000001)
            for fraction in [0.1, 0.3, 0.6, 0.9] {
                let h = SpeciesBehavior.hop(id, age: m.start + m.duration * fraction)
                XCTAssertTrue(h >= -m.hop && h <= 0)
            }
        }
    }
    func testSimilarPlumageDoesNotMeanIdenticalBehavior() {
        let groups: [[SpeciesID]] = [
            [.collaredScopsOwl, .asianBarredOwlet, .littleOwl],
            [.largeBilledCrow, .asianKoel, .blackDrongo, .chineseBlackbird],
            [.swinhoesWhiteEye, .yellowBrowedWarbler, .redBilledLeiothrix],
            [.commonKestrel, .peregrineFalcon, .blackKite, .commonBuzzard],
            [.nightHeron, .littleEgret, .greyHeron, .chinesePondHeron]
        ]
        for group in groups {
            let signatures = group.map { id in (0..<1800).map { SpeciesBehavior.frame(id, age: Double($0) / 30)! }.joined(separator: ",") }
            XCTAssertEqual(Set(signatures).count, group.count)
        }
    }
    func testHopsOnlyOnHorizontalPerches() {
        let bird = Bird(position: .zero, fraction: 0.5, profile: SpeciesCatalog.standard.profile(.treeSparrow))
        bird.perch(on: Surface(id: 1, rect: CGRect(x: 100, y: 100, width: 500, height: 500)))
        bird.tick(1.25)
        XCTAssertLessThan(bird.hopOffset, 0)
        bird.edge = .left
        XCTAssertEqual(bird.hopOffset, 0)
    }
}
