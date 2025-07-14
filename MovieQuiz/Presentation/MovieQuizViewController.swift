import UIKit

final class MovieQuizViewController: UIViewController, QuestionFactoryDelegate, AlertPresenterProtocol   {

    // MARK: - Outlets
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var textLabel: UILabel!
    @IBOutlet private weak var counterLabel: UILabel!
    @IBOutlet private weak var questionLabel: UILabel!
    @IBOutlet private weak var yesButton: UIButton!
    @IBOutlet private weak var noButton: UIButton!

    // MARK: - Properties
    private var correctAnswers = 0

    private var currentQuestionIndex = 0
    private let questionsAmount: Int = 10
    private var currentQuestion: QuizQuestion?
    private var questionFactory: QuestionFactoryProtocol = QuestionFactory()
    private let statisticService = StatisticServiceImplementation()
    private var alertPresenter: AlertPresenter = AlertPresenter()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        let questionFactory = QuestionFactory()
        questionFactory.setup(delegate: self)
        self.questionFactory = questionFactory
        
        alertPresenter.setup(viewController: self)
        
        questionFactory.requestNextQuestion()
    }

    // MARK: - QuestionFactoryDelegate
    func didReceiveNextQuestion(question: QuizQuestion?) {
        guard let question = question else {
            return
        }

        currentQuestion = question
        let viewModel = convert(model: question)

        DispatchQueue.main.async { [weak self] in
            self?.show(quiz: viewModel)
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        textLabel.textColor = .ypWhite
        textLabel.font = UIFont(name: "YSDisplay-Bold", size: 23)

        questionLabel.textColor = .ypWhite
        questionLabel.font = UIFont(name: "YSDisplay-Medium", size: 20)

        counterLabel.textColor = .ypWhite
    }

    //MARK: - AlertPresenterProtocol
    func present(alert: UIAlertController, animated: Bool) {
        self.present(alert, animated: animated)
    }

    // MARK: - Private Methods
    private func show(quiz step: QuizStepViewModel) {
        textLabel.text = step.question
        counterLabel.text = step.questionNumber
        imageView.image = step.image

        imageView.layer.borderWidth = 0
        self.yesButton.isEnabled = true
        self.noButton.isEnabled = true
    }

    private func show(quiz result: QuizResultsViewModel) {
        statisticService.store(correct: correctAnswers, total: questionsAmount)
        let alertModel = AlertModel(title: result.title,
                                    message: "\(result.text)\n Количество сыгранных квизов: \(statisticService.gamesCount) \n Рекорд: \(statisticService.bestGame.correct)/\(statisticService.bestGame.total) (\(statisticService.bestGame.date.dateTimeString))\n Средняя точность: \(String(format: "%.2f", statisticService.totalAccuracy))%",
                                    buttonText: result.buttonText,
                                    completion: { [weak self] in guard let self = self else { return }
                                        self.currentQuestionIndex = 0
                                        self.correctAnswers = 0
                                        self.questionFactory.requestNextQuestion()
                                    })
        alertPresenter.show(alert: alertModel)
    }
    
    private func convert(model: QuizQuestion) -> QuizStepViewModel {
        return QuizStepViewModel(image: UIImage(named: model.image) ?? UIImage(),
                                 question: model.text,
                                 questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)")
    }

    private func showAnswerResult(isCorrect: Bool) {
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 8
        imageView.layer.borderColor = isCorrect ? UIColor.ypGreen.cgColor : UIColor.ypRed.cgColor
        if isCorrect {
            correctAnswers += 1
        }
        // -------------------
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.showNextQuestionOrResults()
        }
    }

    private func showNextQuestionOrResults() {
        if currentQuestionIndex == questionsAmount - 1 {
            // идём в состояние "Результат квиза"
            let quizResults = QuizResultsViewModel(title: "Этот раунд окончен!",
                                                   text: "Ваш результат: \(correctAnswers)/\(questionsAmount)",
                                                   buttonText: "Сыграть еще раз")
            self.show(quiz: quizResults)
        } else {
            currentQuestionIndex += 1
            questionFactory.requestNextQuestion()
        }
    }

    private func handleAnswer(_ answer: Bool) {
        guard let currentQuestion = currentQuestion else {
            return
        }
        self.yesButton.isEnabled = false
        self.noButton.isEnabled = false
        showAnswerResult(isCorrect: answer == currentQuestion.correctAnswer) // 3

    }

    // MARK: - Actions
    @IBAction private func yesButtonClicked(_ sender: Any) {
        handleAnswer(true)
    }
    @IBAction private func noButtonClicked(_ sender: Any) {
        handleAnswer(false)
    }
}
