import XCTest
@testable import MovieQuiz

@MainActor
private final class QuestionFactoryDelegateSpy: QuestionFactoryDelegate {
    let dataLoadedExpectation: XCTestExpectation
    let failureExpectation: XCTestExpectation
    let questionExpectation: XCTestExpectation
    private(set) var failureWasDeliveredOnMainThread = false
    private(set) var receivedQuestion: QuizQuestion?

    init(
        dataLoadedExpectation: XCTestExpectation,
        failureExpectation: XCTestExpectation,
        questionExpectation: XCTestExpectation
    ) {
        self.dataLoadedExpectation = dataLoadedExpectation
        self.failureExpectation = failureExpectation
        self.questionExpectation = questionExpectation
    }

    func didReceiveNextQuestion(question: QuizQuestion) {
        receivedQuestion = question
        questionExpectation.fulfill()
    }

    func didLoadDataFromServer() {
        dataLoadedExpectation.fulfill()
    }

    func didFailToLoadData(with error: Error) {
        failureWasDeliveredOnMainThread = Thread.isMainThread
        failureExpectation.fulfill()
    }
}

final class QuestionFactoryTests: XCTestCase {
    @MainActor
    func testImageLoadingFailureIsDeliveredOnMainThreadWithoutQuestion() async throws {
        let dataLoadedExpectation = expectation(description: "Movies loaded")
        let failureExpectation = expectation(description: "Image loading failed")
        let questionExpectation = expectation(description: "Question was not delivered")
        questionExpectation.isInverted = true

        let movie = MostPopularMovie(
            title: "Movie",
            rating: "8.0",
            imageURL: try XCTUnwrap(URL(string: "https://example.com/poster.jpg"))
        )
        let loader = MoviesLoaderStub(
            result: .success(MostPopularMovies(errorMessage: "", items: [movie]))
        )
        let imageLoader = ImageLoaderStub(result: .failure(TestError.imageLoadingFailed))
        let delegate = QuestionFactoryDelegateSpy(
            dataLoadedExpectation: dataLoadedExpectation,
            failureExpectation: failureExpectation,
            questionExpectation: questionExpectation
        )
        let factory = QuestionFactory(moviesLoader: loader, imageLoader: imageLoader, delegate: delegate)

        factory.loadData()
        await fulfillment(of: [dataLoadedExpectation], timeout: 1)

        factory.requestNextQuestion()
        await fulfillment(of: [failureExpectation, questionExpectation], timeout: 1)

        XCTAssertTrue(delegate.failureWasDeliveredOnMainThread)
    }

    @MainActor
    func testImageLoadingSuccessDeliversQuestionWithLoadedImageData() async throws {
        let dataLoadedExpectation = expectation(description: "Movies loaded")
        let failureExpectation = expectation(description: "Image loading did not fail")
        failureExpectation.isInverted = true
        let questionExpectation = expectation(description: "Question delivered")
        let imageData = Data("image-data".utf8)

        let movie = MostPopularMovie(
            title: "Movie",
            rating: "8.0",
            imageURL: try XCTUnwrap(URL(string: "https://example.com/poster.jpg"))
        )
        let loader = MoviesLoaderStub(
            result: .success(MostPopularMovies(errorMessage: "", items: [movie]))
        )
        let imageLoader = ImageLoaderStub(result: .success(imageData))
        let delegate = QuestionFactoryDelegateSpy(
            dataLoadedExpectation: dataLoadedExpectation,
            failureExpectation: failureExpectation,
            questionExpectation: questionExpectation
        )
        let factory = QuestionFactory(moviesLoader: loader, imageLoader: imageLoader, delegate: delegate)

        factory.loadData()
        await fulfillment(of: [dataLoadedExpectation], timeout: 1)

        factory.requestNextQuestion()
        await fulfillment(of: [questionExpectation, failureExpectation], timeout: 1)

        XCTAssertEqual(delegate.receivedQuestion?.image, imageData)
    }

    @MainActor
    func testRequestNextQuestionCancelsPreviousImageLoading() async throws {
        let dataLoadedExpectation = expectation(description: "Movies loaded")
        let failureExpectation = expectation(description: "Image loading did not fail")
        failureExpectation.isInverted = true
        let questionExpectation = expectation(description: "Question was not delivered")
        questionExpectation.isInverted = true

        let movie = MostPopularMovie(
            title: "Movie",
            rating: "8.0",
            imageURL: try XCTUnwrap(URL(string: "https://example.com/poster.jpg"))
        )
        let loader = MoviesLoaderStub(
            result: .success(MostPopularMovies(errorMessage: "", items: [movie]))
        )
        let imageLoader = ImageLoaderStub(result: .success(Data()), completesImmediately: false)
        let delegate = QuestionFactoryDelegateSpy(
            dataLoadedExpectation: dataLoadedExpectation,
            failureExpectation: failureExpectation,
            questionExpectation: questionExpectation
        )
        let factory = QuestionFactory(moviesLoader: loader, imageLoader: imageLoader, delegate: delegate)

        factory.loadData()
        await fulfillment(of: [dataLoadedExpectation], timeout: 1)

        factory.requestNextQuestion()
        factory.requestNextQuestion()
        await fulfillment(of: [failureExpectation, questionExpectation], timeout: 0.2)

        XCTAssertEqual(imageLoader.loadCallCount, 2)
        XCTAssertEqual(imageLoader.tasks.first?.cancelCallCount, 1)
    }
}

private struct MoviesLoaderStub: MoviesLoading {
    let result: Result<MostPopularMovies, Error>

    func loadMovies(handler: @escaping @Sendable (Result<MostPopularMovies, Error>) -> Void) {
        handler(result)
    }
}

private final class ImageLoaderStub: ImageLoading, @unchecked Sendable {
    private let result: Result<Data, Error>
    private let completesImmediately: Bool
    private let lock = NSLock()
    private var _tasks: [ImageLoadingTaskSpy] = []
    private var _loadCallCount = 0

    init(result: Result<Data, Error>, completesImmediately: Bool = true) {
        self.result = result
        self.completesImmediately = completesImmediately
    }

    var tasks: [ImageLoadingTaskSpy] {
        lock.lock()
        defer { lock.unlock() }
        return _tasks
    }

    var loadCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _loadCallCount
    }

    func loadImageData(
        from url: URL,
        handler: @escaping @Sendable (Result<Data, Error>) -> Void
    ) -> ImageLoadingTask {
        let task = ImageLoadingTaskSpy()
        lock.lock()
        _loadCallCount += 1
        _tasks.append(task)
        lock.unlock()

        if completesImmediately {
            handler(result)
        }

        return task
    }
}

private final class ImageLoadingTaskSpy: ImageLoadingTask, @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelCallCount = 0

    var cancelCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _cancelCallCount
    }

    func cancel() {
        lock.lock()
        _cancelCallCount += 1
        lock.unlock()
    }
}

private enum TestError: Error {
    case imageLoadingFailed
}
