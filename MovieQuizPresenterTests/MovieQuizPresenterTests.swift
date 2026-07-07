import XCTest
@testable import MovieQuiz

@MainActor
final class MovieQuizViewControllerMock: MovieQuizViewControllerProtocol {
    private(set) var showLoadingIndicatorCallCount = 0
    private(set) var offButtonsCallCount = 0

    func show(quiz step: QuizStepViewModel) {
        
    }
    
    func show(quiz result: QuizResultsViewModel) {
        
    }
    
    func highlightImageBorder(isCorrectAnswer: Bool) {
        
    }
    
    func showLoadingIndicator() {
        showLoadingIndicatorCallCount += 1
    }
    
    func hideLoadingIndicator() {
        
    }
    
    func offButtons() {
        offButtonsCallCount += 1
    }
    
    func showNetworkError(message: String) {
        
    }
}

final class MovieQuizPresenterTests: XCTestCase {
    @MainActor
    func testPresenterConvertModel() throws {
        // Given
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock
        )
        let emptyData = Data()
        let question = QuizQuestion(image: emptyData, text: "Question Text", correctAnswer: true)
        
        // When
        let viewModel = sut.convert(model: question)
        
        // Then
        XCTAssertNotNil(viewModel.image)
        XCTAssertEqual(viewModel.question, "Question Text")
        XCTAssertEqual(viewModel.questionNumber, "1/10")
    }

    @MainActor
    func testRestartGameRequestsQuestionWithoutReloadingData() {
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock
        )

        sut.switchToNextQuestion()
        sut.restartGame()

        let question = QuizQuestion(image: Data(), text: "Question", correctAnswer: true)
        XCTAssertEqual(sut.convert(model: question).questionNumber, "1/10")
        XCTAssertEqual(questionFactoryMock.loadDataCallCount, 1)
        XCTAssertEqual(questionFactoryMock.requestNextQuestionCallCount, 1)
    }

    @MainActor
    func testRetryLoadingReloadsDataWithoutResettingGame() {
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock
        )
        sut.switchToNextQuestion()
        sut.didFailToLoadData(with: TestError.loadingFailed)

        sut.retryLoading()

        let question = QuizQuestion(image: Data(), text: "Question", correctAnswer: true)
        XCTAssertEqual(sut.convert(model: question).questionNumber, "2/10")
        XCTAssertEqual(questionFactoryMock.loadDataCallCount, 2)
        XCTAssertEqual(questionFactoryMock.requestNextQuestionCallCount, 0)
        XCTAssertEqual(viewControllerMock.showLoadingIndicatorCallCount, 2)
        XCTAssertEqual(viewControllerMock.offButtonsCallCount, 2)
    }

    @MainActor
    func testRetryLoadingDoesNotStartParallelRequest() {
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock
        )

        sut.retryLoading()

        XCTAssertEqual(questionFactoryMock.loadDataCallCount, 1)
        XCTAssertEqual(viewControllerMock.showLoadingIndicatorCallCount, 1)
        XCTAssertEqual(viewControllerMock.offButtonsCallCount, 1)
    }
}

private final class QuestionFactoryMock: QuestionFactoryProtocol {
    private(set) var requestNextQuestionCallCount = 0
    private(set) var loadDataCallCount = 0

    func requestNextQuestion() {
        requestNextQuestionCallCount += 1
    }

    func loadData() {
        loadDataCallCount += 1
    }
}

private enum TestError: Error {
    case loadingFailed
}
