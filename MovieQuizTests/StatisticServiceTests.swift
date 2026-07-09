import XCTest
@testable import MovieQuiz

final class StatisticServiceTests: XCTestCase {
    private var storage: UserDefaults!
    private var storageSuiteName = ""

    override func setUp() {
        super.setUp()
        storageSuiteName = "StatisticServiceTests-\(UUID().uuidString)"
        storage = UserDefaults(suiteName: storageSuiteName)
    }

    override func tearDown() {
        storage.removePersistentDomain(forName: storageSuiteName)
        storage = nil
        storageSuiteName = ""
        super.tearDown()
    }

    func testFirstZeroResultBecomesBestGame() {
        let sut = StatisticServiceImplementation(storage: storage)

        sut.store(correct: 0, total: 10)

        XCTAssertEqual(sut.gamesCount, 1)
        XCTAssertEqual(sut.bestGame.correct, 0)
        XCTAssertEqual(sut.bestGame.total, 10)
    }
}
