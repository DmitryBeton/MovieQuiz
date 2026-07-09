import Foundation

@MainActor
final class QuestionFactory: QuestionFactoryProtocol {
    
    private let moviesLoader: MoviesLoading
    private let imageLoader: ImageLoading
    private weak var delegate: QuestionFactoryDelegate?
    private var imageLoadingTask: ImageLoadingTask?
    private var imageRequestID = 0
    
    init(
        moviesLoader: MoviesLoading,
        imageLoader: ImageLoading = ImageLoader(),
        delegate: QuestionFactoryDelegate?
    ) {
        self.moviesLoader = moviesLoader
        self.imageLoader = imageLoader
        self.delegate = delegate
    }

    deinit {
        imageLoadingTask?.cancel()
    }
    
    private var movies: [MostPopularMovie] = []
    
    func loadData() {
        moviesLoader.loadMovies { [weak self] result in
            Task { @MainActor in
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
        let movies = movies

        guard !movies.isEmpty else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Internet error"])
            delegate?.didFailToLoadData(with: error)
            return
        }

        let index = (0..<movies.count).randomElement() ?? 0
        guard let movie = movies[safe: index] else { return }

        imageLoadingTask?.cancel()
        imageRequestID += 1
        let requestID = imageRequestID

        imageLoadingTask = imageLoader.loadImageData(from: movie.resizedImageURL) { [weak self, movie] result in
            Task { @MainActor in
                guard let self, self.imageRequestID == requestID else { return }

                switch result {
                case .success(let imageData):
                    let question = self.makeQuestion(from: movie, imageData: imageData)
                    self.delegate?.didReceiveNextQuestion(question: question)
                case .failure(let error):
                    if (error as? URLError)?.code == .cancelled {
                        return
                    }
                    self.delegate?.didFailToLoadData(with: error)
                }

                self.imageLoadingTask = nil
            }
        }
    }

    private func makeQuestion(from movie: MostPopularMovie, imageData: Data) -> QuizQuestion {
        // Выбор рандомного вопроса
        let rating = Float(movie.rating) ?? 0
        let randomNumber = Int.random(in: 7...9)
        let text: String
        let correctAnswer: Bool

        if Bool.random() {
            text = "Рейтинг этого фильма больше чем \(randomNumber)?"
            correctAnswer = rating > Float(randomNumber)
        } else {
            text = "Рейтинг этого фильма меньше чем \(randomNumber)?"
            correctAnswer = rating < Float(randomNumber)
        }

        return QuizQuestion(image: imageData,
                            text: text,
                            correctAnswer: correctAnswer)
    }
}
