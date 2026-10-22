import Foundation
import CoreGraphics

public struct PopulationRange: Equatable {
    public let lower: Int
    public let upper: Int
    public init?(lower: Int, upper: Int) {
        guard lower >= 1, upper >= lower, upper <= 50 else { return nil }
        self.lower = lower; self.upper = upper
    }
    public static let standard = PopulationRange(lower: 3, upper: 5)!
}

public enum PopulationAction { case arrive, depart }

// One event at a time, with a simulation clock (pause/sleep cannot cause a burst).
public final class Population {
    public private(set) var range: PopulationRange
    public private(set) var remaining: Double = 0.8
    public init(range: PopulationRange = .standard) { self.range = range }
    public func setRange(_ value: PopulationRange) {
        range = value
        remaining = min(remaining, 1.5)
    }
    public func tick(_ dt: Double, residents: Int, total: Int,
                     random: () -> Double = { Double.random(in: 0..<1) }) -> PopulationAction? {
        remaining -= max(0, dt)
        guard remaining <= 0 else { return nil }
        let filling = residents < range.lower
        let reducing = residents > range.upper
        remaining = (filling || reducing) ? 2.5 + random()*3.5 : 24 + random()*24
        if filling { return total < range.upper ? .arrive : nil }
        if reducing { return .depart }
        if residents == range.lower && residents == range.upper { return nil }
        if residents <= range.lower { return total < range.upper ? .arrive : nil }
        if residents >= range.upper { return .depart }
        if random() < 0.5 && total < range.upper { return .arrive }
        return .depart
    }
}

public enum Migration {
    // Use an outer edge of the entire display arrangement, never a shared monitor edge.
    public static func outsidePoint(screens: [CGRect], right: Bool, fraction: CGFloat, margin: CGFloat) -> CGPoint? {
        guard let screen = (right ? screens.max(by: {$0.maxX < $1.maxX}) : screens.min(by: {$0.minX < $1.minX})) else { return nil }
        let y = screen.minY + screen.height * min(0.8, max(0.15, fraction))
        return CGPoint(x: right ? screen.maxX+margin : screen.minX-margin, y:y)
    }
}
