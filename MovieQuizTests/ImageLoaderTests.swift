import XCTest
@testable import MovieQuiz

@MainActor
final class ImageLoaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testLoadImageDataCachesSuccessfulResponse() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/image.jpg"))
        let expectedData = Data("image-data".utf8)
        let sut = ImageLoader(session: makeSession())
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }
            return (response, expectedData)
        }

        let firstExpectation = expectation(description: "First image loading")
        _ = sut.loadImageData(from: url) { result in
            XCTAssertEqual(try? result.get(), expectedData)
            firstExpectation.fulfill()
        }
        wait(for: [firstExpectation], timeout: 1)

        let secondExpectation = expectation(description: "Second image loading")
        _ = sut.loadImageData(from: url) { result in
            XCTAssertEqual(try? result.get(), expectedData)
            secondExpectation.fulfill()
        }
        wait(for: [secondExpectation], timeout: 1)

        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testLoadImageDataDoesNotCacheItemLargerThanTotalCostLimit() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/large-image.jpg"))
        let expectedData = Data("large-image".utf8)
        let sut = ImageLoader(
            session: makeSession(),
            cacheTotalCostLimit: expectedData.count - 1
        )
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }
            return (response, expectedData)
        }

        let firstExpectation = expectation(description: "First image loading")
        _ = sut.loadImageData(from: url) { result in
            XCTAssertEqual(try? result.get(), expectedData)
            firstExpectation.fulfill()
        }
        wait(for: [firstExpectation], timeout: 1)

        let secondExpectation = expectation(description: "Second image loading")
        _ = sut.loadImageData(from: url) { result in
            XCTAssertEqual(try? result.get(), expectedData)
            secondExpectation.fulfill()
        }
        wait(for: [secondExpectation], timeout: 1)

        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    static func reset() {
        requestHandler = nil
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestCount += 1

        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
