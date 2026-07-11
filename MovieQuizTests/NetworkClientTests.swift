import XCTest
@testable import MovieQuiz

final class NetworkClientTests: XCTestCase {
    func testFetchCompletesOnceForTransportError() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/movies"))
        let session = NetworkSessionStub(
            data: Data("unexpected".utf8),
            response: makeResponse(url: url, statusCode: 500),
            error: URLError(.notConnectedToInternet)
        )
        let sut = NetworkClient(session: session)

        assertSingleCompletion(from: sut, url: url) { result in
            if case .success = result {
                XCTFail("Expected transport error")
            }
        }
    }

    func testFetchCompletesOnceForHTTPError() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/movies"))
        let session = NetworkSessionStub(
            data: Data("error".utf8),
            response: makeResponse(url: url, statusCode: 500),
            error: nil
        )
        let sut = NetworkClient(session: session)

        assertSingleCompletion(from: sut, url: url) { result in
            if case .success = result {
                XCTFail("Expected HTTP error")
            }
        }
    }

    func testFetchCompletesOnceForEmptyData() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/movies"))
        let session = NetworkSessionStub(
            data: nil,
            response: makeResponse(url: url, statusCode: 200),
            error: nil
        )
        let sut = NetworkClient(session: session)

        assertSingleCompletion(from: sut, url: url) { result in
            if case .success = result {
                XCTFail("Expected empty data error")
            }
        }
    }

    func testFetchCompletesOnceForSuccess() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/movies"))
        let expectedData = Data("movies".utf8)
        let session = NetworkSessionStub(
            data: expectedData,
            response: makeResponse(url: url, statusCode: 200),
            error: nil
        )
        let sut = NetworkClient(session: session)

        assertSingleCompletion(from: sut, url: url) { result in
            XCTAssertEqual(try? result.get(), expectedData)
        }
    }

    private func assertSingleCompletion(
        from client: NetworkClient,
        url: URL,
        assertions: @escaping @Sendable (Result<Data, Error>) -> Void
    ) {
        let completionExpectation = expectation(description: "Completion called once")
        completionExpectation.assertForOverFulfill = true
        let completionCounter = InvocationCounter()

        client.fetch(url: url) { result in
            completionCounter.increment()
            assertions(result)
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 1)
        XCTAssertEqual(completionCounter.value, 1)
    }

    private func makeResponse(url: URL, statusCode: Int) -> HTTPURLResponse? {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
    }
}

private final class InvocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private final class NetworkSessionStub: NetworkSession, @unchecked Sendable {
    private let data: Data?
    private let response: URLResponse?
    private let error: Error?

    init(data: Data?, response: URLResponse?, error: Error?) {
        self.data = data
        self.response = response
        self.error = error
    }

    func makeDataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkSessionTask {
        NetworkSessionTaskStub {
            completionHandler(self.data, self.response, self.error)
        }
    }
}

private final class NetworkSessionTaskStub: NetworkSessionTask, @unchecked Sendable {
    private let action: @Sendable () -> Void

    init(action: @escaping @Sendable () -> Void) {
        self.action = action
    }

    func resume() {
        action()
    }
}
