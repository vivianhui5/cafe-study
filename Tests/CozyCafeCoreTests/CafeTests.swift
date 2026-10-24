import XCTest
@testable import CozyCafeCore
final class CafeTests: XCTestCase {
    func testCompletionRewardsExactlyOnce() {
        var cafe = Cafe(); cafe.configure(minutes: 2); cafe.start(at: 10)
        XCTAssertFalse(cafe.tick(at: 129)); XCTAssertEqual(cafe.fraction(at: 70), 0.5)
        XCTAssertTrue(cafe.tick(at: 130)); XCTAssertFalse(cafe.tick(at: 200))
        XCTAssertEqual(cafe.progress.coins, 2); XCTAssertEqual(cafe.progress.brewed["matcha"], 1)
    }
    func testCancellationNeverRewardsEvenAfterDeadline() {
        var cafe = Cafe(); cafe.start(at: 0); cafe.cancel()
        XCTAssertFalse(cafe.tick(at: 10000)); XCTAssertEqual(cafe.progress.coins, 0)
    }
    func testUnlockAndPersistence() throws {
        var cafe = Cafe(); cafe.configure(minutes: 30); cafe.start(at: 0); cafe.tick(at: 1800)
        XCTAssertTrue(cafe.unlock(Drink.menu[1])); XCTAssertFalse(cafe.unlock(Drink.menu[1]))
        XCTAssertFalse(cafe.unlock(Drink.menu[2])); cafe.select(Drink.menu[1])
        let restored = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(cafe.progress))
        XCTAssertEqual(restored, cafe.progress); XCTAssertFalse(Cafe(progress: restored).running)
    }
    func testSessionSettingsCannotChangeWhileRunning() {
        var cafe = Cafe(); cafe.configure(minutes: 0); XCTAssertEqual(cafe.progress.duration, 1)
        cafe.start(at: 0); cafe.configure(minutes: 120); XCTAssertEqual(cafe.sessionMinutes, 1)
        cafe.select(Drink.menu[1]); XCTAssertEqual(cafe.progress.selected, "matcha")
    }
    func testSuspendedBrewRestoresAndRewardsOnce() throws {
        var cafe = Cafe(); cafe.configure(minutes: 2); cafe.start(at: 1000)
        let data = try JSONEncoder().encode(cafe.progress)
        var reopened = Cafe(progress: try JSONDecoder().decode(Progress.self, from: data))
        XCTAssertTrue(reopened.running)
        XCTAssertEqual(reopened.remaining(at: 1060), 60)
        XCTAssertTrue(reopened.tick(at: 5000))
        let finished = try JSONEncoder().encode(reopened.progress)
        var relaunched = Cafe(progress: try JSONDecoder().decode(Progress.self, from: finished))
        XCTAssertFalse(relaunched.tick(at: 6000))
        XCTAssertEqual(relaunched.progress.coins, 2)
        XCTAssertEqual(relaunched.progress.cups, 1)
    }
    func testLegacyProgressLoadsWithoutSession() throws {
        let data = try JSONEncoder().encode(Progress())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "session")
        let restored = try JSONDecoder().decode(Progress.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.session)
        XCTAssertEqual(restored.unlocked, ["matcha"])
    }
}
