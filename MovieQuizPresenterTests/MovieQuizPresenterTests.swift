import XCTest
@testable import MovieQuiz

@MainActor
final class MovieQuizViewControllerMock: MovieQuizViewControllerProtocol {
    private(set) var showLoadingIndicatorCallCount = 0
    private(set) var hideLoadingIndicatorCallCount = 0
    private(set) var answerButtonsEnabledStates: [Bool] = []
    private(set) var showStepCallCount = 0
    private(set) var highlightImageBorderCallCount = 0

    func show(quiz step: QuizStepViewModel) {
        showStepCallCount += 1
    }
    
    func show(quiz result: QuizResultsViewModel) {
        
    }
    
    func highlightImageBorder(isCorrectAnswer: Bool) {
        highlightImageBorderCallCount += 1
    }
    
    func showLoadingIndicator() {
        showLoadingIndicatorCallCount += 1
    }
    
    func hideLoadingIndicator() {
        hideLoadingIndicatorCallCount += 1
    }
    
    func setAnswerButtonsEnabled(_ isEnabled: Bool) {
        answerButtonsEnabledStates.append(isEnabled)
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
        XCTAssertEqual(viewControllerMock.answerButtonsEnabledStates, [false, false, false])
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
        XCTAssertEqual(viewControllerMock.answerButtonsEnabledStates, [false])
    }

    @MainActor
    func testReceivingQuestionSwitchesToReadyAndEnablesButtons() {
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock
        )
        let question = QuizQuestion(image: Data(), text: "Question", correctAnswer: true)

        sut.didReceiveNextQuestion(question: question)

        XCTAssertEqual(viewControllerMock.showStepCallCount, 1)
        XCTAssertEqual(viewControllerMock.hideLoadingIndicatorCallCount, 1)
        XCTAssertEqual(viewControllerMock.answerButtonsEnabledStates, [false, true])
    }

    @MainActor
    func testAnswerSwitchesToAnsweringAndIgnoresSecondTap() {
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock
        )
        let question = QuizQuestion(image: Data(), text: "Question", correctAnswer: true)

        sut.didReceiveNextQuestion(question: question)
        sut.yesButtonClicked(true)
        sut.noButtonClicked(false)

        XCTAssertEqual(viewControllerMock.highlightImageBorderCallCount, 1)
        XCTAssertEqual(viewControllerMock.answerButtonsEnabledStates, [false, true, false])
    }

    @MainActor
    func testResultsMessageUsesSlashFormat() {
        let viewControllerMock = MovieQuizViewControllerMock()
        let questionFactoryMock = QuestionFactoryMock()
        let statisticServiceMock = StatisticServiceMock()
        let sut = MovieQuizPresenter(
            viewController: viewControllerMock,
            questionFactory: questionFactoryMock,
            statisticService: statisticServiceMock
        )

        let message = sut.makeResultsMessage()

        XCTAssertTrue(message.contains("Ваш результат: 0/10"))
        XCTAssertTrue(message.contains("Рекорд: 8/10"))
        XCTAssertFalse(message.contains("\\"))
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

private final class StatisticServiceMock: StatisticServiceProtocol {
    var gamesCount = 3
    var bestGame = GameResult(
        correct: 8,
        total: 10,
        date: Date(timeIntervalSince1970: 0)
    )
    var totalAccuracy = 70.0

    func store(correct count: Int, total amount: Int) {

    }
}
