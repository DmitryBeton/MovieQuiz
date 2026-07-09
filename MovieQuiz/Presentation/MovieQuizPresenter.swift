import UIKit

@MainActor
final class MovieQuizPresenter: QuestionFactoryDelegate {
    
    // MARK: - Properties
    private enum QuizState {
        case loading
        case ready
        case answering
        case error
    }

    private let questionsAmount: Int = 10
    private var currentQuestionIndex = 0
    
    private var currentQuestion: QuizQuestion?
    private var correctAnswers = 0
    
    private let statisticService: StatisticServiceProtocol
    private var questionFactory: QuestionFactoryProtocol?
    private weak var viewController: MovieQuizViewControllerProtocol?
    private var isLoadingData = false
    private var state: QuizState?

    init(
        viewController: MovieQuizViewControllerProtocol,
        questionFactory: QuestionFactoryProtocol? = nil,
        statisticService: StatisticServiceProtocol = StatisticServiceImplementation()
    ) {
        self.viewController = viewController
        self.statisticService = statisticService

        if let questionFactory {
            self.questionFactory = questionFactory
        } else {
            self.questionFactory = QuestionFactory(
                moviesLoader: MoviesLoader(),
                delegate: self
            )
        }

        startLoadingData()
    }
    
    // MARK: - QuestionFactoryDelegate
    
    func didLoadDataFromServer() {
        isLoadingData = false
        questionFactory?.requestNextQuestion()
    }
    
    func didFailToLoadData(with error: Error) {
        isLoadingData = false
        setState(.error)
        viewController?.showNetworkError(message: error.localizedDescription) // возьмём в качестве сообщения описание ошибки
    }
    
    func didReceiveNextQuestion(question: QuizQuestion) {
        
        currentQuestion = question
        let viewModel = convert(model: question)
        
        viewController?.show(quiz: viewModel)
        setState(.ready)
    }
    
    // MARK: - Methods
    func isLastQuestion() -> Bool {
        currentQuestionIndex == questionsAmount - 1
    }
    
    func restartGame() {
        currentQuestionIndex = 0
        correctAnswers = 0
        currentQuestion = nil
        setState(.loading)
        questionFactory?.requestNextQuestion()
    }

    func retryLoading() {
        startLoadingData()
    }
    
    func switchToNextQuestion() {
        currentQuestionIndex += 1
    }
    
    func convert(model: QuizQuestion) -> QuizStepViewModel {
        return QuizStepViewModel(
            image: UIImage(data: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)")
    }
    
    func yesButtonClicked(_ sender: Any) {
        handleAnswer(true)
    }
    
    func noButtonClicked(_ sender: Any) {
        handleAnswer(false)
    }
    
    func showNextQuestionOrResults() {
        if self.isLastQuestion() {
            // идём в состояние "Результат квиза"
            let quizResults = QuizResultsViewModel(title: "Этот раунд окончен!",
                                                   text: "Ваш результат: \(self.correctAnswers)/\(self.questionsAmount)",
                                                   buttonText: "Сыграть ещё раз")
            self.viewController?.show(quiz: quizResults)
        } else {
            self.switchToNextQuestion()
            questionFactory?.requestNextQuestion()
        }
    }
    
    func showAnswerResult(isCorrect: Bool) {
        if isCorrect {
            correctAnswers += 1
        }
        
        viewController?.highlightImageBorder(isCorrectAnswer: isCorrect)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.showNextQuestionOrResults()
        }
    }
    
    func makeResultsMessage() -> String {
        statisticService.store(correct: correctAnswers, total: questionsAmount)
        
        let bestGame = statisticService.bestGame
        
        let totalPlaysCountLine = "Количество сыгранных квизов: \(statisticService.gamesCount)"
        let currentGameResultLine = "Ваш результат: \(correctAnswers)/\(questionsAmount)"
        let bestGameInfoLine = "Рекорд: \(bestGame.correct)/\(bestGame.total)"
        + " (\(bestGame.date.dateTimeString))"
        let averageAccuracyLine = "Средняя точность: \(String(format: "%.2f", statisticService.totalAccuracy))%"
        
        let resultMessage = [
            currentGameResultLine, totalPlaysCountLine, bestGameInfoLine, averageAccuracyLine
        ].joined(separator: "\n")
        
        return resultMessage
    }
    
    // MARK: - Private methods
    private func handleAnswer(_ answer: Bool) {
        guard state == .ready, let currentQuestion = currentQuestion else {
            return
        }

        setState(.answering)
        self.showAnswerResult(isCorrect: answer == currentQuestion.correctAnswer) // 3
    }

    private func startLoadingData() {
        guard !isLoadingData else { return }

        isLoadingData = true
        setState(.loading)
        questionFactory?.loadData()
    }

    private func setState(_ state: QuizState) {
        self.state = state
        applyState(state)
    }

    private func applyState(_ state: QuizState) {
        switch state {
        case .loading:
            viewController?.setAnswerButtonsEnabled(false)
            viewController?.showLoadingIndicator()
        case .ready:
            viewController?.hideLoadingIndicator()
            viewController?.setAnswerButtonsEnabled(true)
        case .answering:
            viewController?.hideLoadingIndicator()
            viewController?.setAnswerButtonsEnabled(false)
        case .error:
            viewController?.hideLoadingIndicator()
            viewController?.setAnswerButtonsEnabled(false)
        }
    }
    
}
