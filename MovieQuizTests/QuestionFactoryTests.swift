import XCTest
@testable import MovieQuiz

@MainActor
private final class QuestionFactoryDelegateSpy: QuestionFactoryDelegate {
    let dataLoadedExpectation: XCTestExpectation
    let failureExpectation: XCTestExpectation
    let questionExpectation: XCTestExpectation
    private(set) var failureWasDeliveredOnMainThread = false

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
    func testImageLoadingFailureIsDeliveredOnMainThreadWithoutQuestion() async {
        let dataLoadedExpectation = expectation(description: "Movies loaded")
        let failureExpectation = expectation(description: "Image loading failed")
        let questionExpectation = expectation(description: "Question was not delivered")
        questionExpectation.isInverted = true

        let movie = MostPopularMovie(
            title: "Movie",
            rating: "8.0",
            imageURL: URL(fileURLWithPath: "/missing-poster.jpg")
        )
        let loader = MoviesLoaderStub(
            result: .success(MostPopularMovies(errorMessage: "", items: [movie]))
        )
        let delegate = QuestionFactoryDelegateSpy(
            dataLoadedExpectation: dataLoadedExpectation,
            failureExpectation: failureExpectation,
            questionExpectation: questionExpectation
        )
        let factory = QuestionFactory(moviesLoader: loader, delegate: delegate)

        factory.loadData()
        await fulfillment(of: [dataLoadedExpectation], timeout: 1)

        factory.requestNextQuestion()
        await fulfillment(of: [failureExpectation, questionExpectation], timeout: 1)

        XCTAssertTrue(delegate.failureWasDeliveredOnMainThread)
    }
}

private struct MoviesLoaderStub: MoviesLoading {
    let result: Result<MostPopularMovies, Error>

    func loadMovies(handler: @escaping (Result<MostPopularMovies, Error>) -> Void) {
        handler(result)
    }
}
