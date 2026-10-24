import Foundation

public struct Drink: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let note: String
    public let price: Int
    public let color: UInt32
    public static let menu: [Drink] = [
        .init(id: "matcha", name: "Matcha latte", note: "A little everyday calm", price: 0, color: 0x95AA7D),
        .init(id: "hojicha", name: "Hojicha latte", note: "Roasted & mellow", price: 30, color: 0xAD9178),
        .init(id: "strawberry", name: "Strawberry matcha", note: "A soft berry moment", price: 60, color: 0xC89D98),
        .init(id: "black-sesame", name: "Black sesame", note: "Quietly comforting", price: 90, color: 0x8C8B80),
        .init(id: "yuzu", name: "Yuzu matcha", note: "A small ray of sunshine", price: 120, color: 0xC4BA7F),
        .init(id: "ceremonial", name: "Ceremonial matcha", note: "Simply, beautifully green", price: 180, color: 0x718864)
    ]
}

public struct BrewSession: Codable, Equatable {
    public let started: TimeInterval
    public let minutes: Int
    public let drink: String
}

public struct Progress: Codable, Equatable {
    public var session: BrewSession?
    public var coins = 0
    public var minutes = 0
    public var cups = 0
    public var unlocked: Set<String> = ["matcha"]
    public var selected = "matcha"
    public var duration = 25
    public var brewed: [String: Int] = [:]
    public init() {}
}

/// Persisted start dates allow a brew to finish while iOS suspends the app.
public struct Cafe {
    public private(set) var progress: Progress
    public var started: TimeInterval? { progress.session?.started }
    public var sessionMinutes: Int { progress.session?.minutes ?? progress.duration }
    public var sessionDrink: String { progress.session?.drink ?? progress.selected }
    public init(progress: Progress = Progress()) { self.progress = progress }
    public var running: Bool { started != nil }
    public mutating func configure(minutes: Int) { guard !running else { return }; progress.duration = min(120, max(1, minutes)) }
    public mutating func select(_ drink: Drink) { guard !running, progress.unlocked.contains(drink.id) else { return }; progress.selected = drink.id }
    @discardableResult public mutating func unlock(_ drink: Drink) -> Bool {
        guard !progress.unlocked.contains(drink.id), progress.coins >= drink.price else { return false }
        progress.coins -= drink.price
        progress.unlocked.insert(drink.id)
        return true
    }
    public mutating func start(at time: TimeInterval) {
        guard !running else { return }
        progress.session = BrewSession(started: time, minutes: progress.duration, drink: progress.selected)
    }
    public func fraction(at time: TimeInterval) -> Double {
        guard let started else { return 0 }
        return min(1, max(0, (time - started) / Double(sessionMinutes * 60)))
    }
    public func remaining(at time: TimeInterval) -> Int {
        guard let started else { return progress.duration * 60 }
        return max(0, Int(ceil(Double(sessionMinutes * 60) - (time - started))))
    }
    /// Reconcile on launch/foreground; no background execution is required.
    @discardableResult public mutating func tick(at time: TimeInterval) -> Bool {
        guard running, fraction(at: time) >= 1 else { return false }
        progress.coins += sessionMinutes; progress.minutes += sessionMinutes; progress.cups += 1
        progress.brewed[sessionDrink, default: 0] += 1
        progress.session = nil
        return true
    }
    public mutating func cancel() { progress.session = nil }
}
