import UIKit

final class MovieQuizViewController: UIViewController, AlertPresenterProtocol, MovieQuizViewControllerProtocol   {
    
    // MARK: - Outlets
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var textLabel: UILabel!
    @IBOutlet private weak var counterLabel: UILabel!
    @IBOutlet private weak var questionLabel: UILabel!
    @IBOutlet private weak var yesButton: UIButton!
    @IBOutlet private weak var noButton: UIButton!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    private var alertPresenter: AlertPresenter?
    private var presenter: MovieQuizPresenter!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let networkStub = UITestNetworkStub()
            presenter = MovieQuizPresenter(
                viewController: self,
                questionFactoryBuilder: { delegate in
                    QuestionFactory(
                        moviesLoader: networkStub,
                        imageLoader: networkStub,
                        delegate: delegate
                    )
                }
            )
        } else {
            presenter = MovieQuizPresenter(viewController: self)
        }
        #else
        presenter = MovieQuizPresenter(viewController: self)
        #endif
        alertPresenter = AlertPresenter(viewController: self)
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
    
    // MARK: - Methods
    func show(quiz step: QuizStepViewModel) {
        textLabel.text = step.question
        counterLabel.text = step.questionNumber
        imageView.image = step.image
        
        imageView.layer.borderWidth = 0
    }
    
    func show(quiz result: QuizResultsViewModel) {
        let message = presenter.makeResultsMessage()
        
        let alert = UIAlertController(
            title: result.title,
            message: message,
            preferredStyle: .alert)
        
        let action = UIAlertAction(title: result.buttonText, style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            self.presenter.restartGame()
        }
        
        alert.addAction(action)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func showNetworkError(message: String) {
        let model = AlertModel(title: "Ошибка",
                               message: message,
                               buttonText: "Попробовать еще раз") { [weak self] in
            guard let self = self else { return }
            
            presenter.retryLoading()
            
        }
        
        alertPresenter?.show(alert: model)
    }
    
    func showLoadingIndicator() {
        activityIndicator.isHidden = false // говорим, что индикатор загрузки не скрыт
        activityIndicator.startAnimating() // включаем анимацию
    }
    
    func hideLoadingIndicator() {
        activityIndicator.isHidden = true // говорим, что индикатор загрузки скрыт
        activityIndicator.stopAnimating()
    }
    
    func setAnswerButtonsEnabled(_ isEnabled: Bool) {
        self.yesButton.isEnabled = isEnabled
        self.noButton.isEnabled = isEnabled
    }
    
    func highlightImageBorder(isCorrectAnswer: Bool) {
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 8
        imageView.layer.borderColor = isCorrectAnswer ? UIColor.ypGreen.cgColor : UIColor.ypRed.cgColor
    }
    
    // MARK: - Actions
    @IBAction private func yesButtonClicked(_ sender: Any) {
        presenter.yesButtonClicked(true)
    }
    @IBAction private func noButtonClicked(_ sender: Any) {
        presenter.noButtonClicked(false)
    }
}
