import Foundation

final class QuestionFactory: QuestionFactoryProtocol {
    
    private let moviesLoader: MoviesLoading
    private weak var delegate: QuestionFactoryDelegate?
    
    init(moviesLoader: MoviesLoading, delegate: QuestionFactoryDelegate?) {
        self.moviesLoader = moviesLoader
        self.delegate = delegate
    }
    
    private var movies: [MostPopularMovie] = []
    
    func loadData() {
        moviesLoader.loadMovies { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let mostPopularMovies):
                    self.movies = mostPopularMovies.items
                    self.delegate?.didLoadDataFromServer()
                case .failure(let error):
                    self.delegate?.didFailToLoadData(with: error)
                    
                }
            }
        }
    }
    
    func requestNextQuestion() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let index = (0..<self.movies.count).randomElement() ?? 0
            guard !self.movies.isEmpty else {
                DispatchQueue.main.async {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Internet error"])
                    self.delegate?.didFailToLoadData(with: error)
                }
                return
            }
            
            guard let movie = self.movies[safe: index] else { return }
            
            var imageData = Data()
            do {
                imageData = try Data(contentsOf: movie.resizedImageURL)
            } catch {
                self.delegate?.didFailToLoadData(with: error)
            }
            
            // Выбор рандомного вопроса
            let rating = Float(movie.rating) ?? 0
            let randomNumber = Int.random(in: 7...9)
            var text: String = ""
            var correctAnswer: Bool = false
            
            if Bool.random() {
                text = "Рейтинг этого фильма больше чем \(randomNumber)?"
                correctAnswer = rating > Float(randomNumber)
            }
            else {
                text = "Рейтинг этого фильма меньше чем \(randomNumber)?"
                correctAnswer = rating < Float(randomNumber)
            }
            
            let question = QuizQuestion(image: imageData,
                                        text: text,
                                        correctAnswer: correctAnswer)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.didReceiveNextQuestion(question: question)
            }
        }
    }
}
