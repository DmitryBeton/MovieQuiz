//
//  MoviesLoader.swift
//  MovieQuiz
//

import Foundation

protocol MoviesLoading {
    func loadMovies(handler: @escaping @Sendable (Result<MostPopularMovies, Error>) -> Void)
}

struct MoviesLoader: MoviesLoading {
    // MARK: - NetworkClient
    private let networkClient: NetworkRouting
    
    init(networkClient: NetworkRouting = NetworkClient()) {
        self.networkClient = networkClient
    }
    
    // MARK: - URL
    private var mostPopularMoviesUrl: URL {
        // Если мы не смогли преобразовать строку в URL, то приложение упадёт с ошибкой
        guard let url = URL(string: "https://tv-api.com/en/API/Top250Movies/k_zcuw1ytf") else {
            preconditionFailure("Unable to construct mostPopularMoviesUrl")
        }
        return url
    }
    
    func loadMovies(handler: @escaping @Sendable (Result<MostPopularMovies, Error>) -> Void) {
        networkClient.fetch(url: mostPopularMoviesUrl) { result in
            switch result {
            case .success(let data):
                do {
                    let mostPopularMovies = try JSONDecoder().decode(MostPopularMovies.self, from: data)
                    handler(.success(mostPopularMovies))
                } catch {
                    handler(.failure(error))
                }
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
}

#if DEBUG
/// Локальная замена сетевого слоя, которая включается только launch-аргументом UI-тестов.
final class UITestNetworkStub: MoviesLoading, ImageLoading, @unchecked Sendable {
    private let imageData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    ) ?? Data()

    func loadMovies(handler: @escaping @Sendable (Result<MostPopularMovies, Error>) -> Void) {
        let movies = (1...10).compactMap { index -> MostPopularMovie? in
            guard let url = URL(string: "https://ui-test.local/poster-\(index).jpg") else {
                return nil
            }
            return MostPopularMovie(
                title: "UI Test Movie \(index)",
                rating: "8.0",
                imageURL: url
            )
        }
        handler(.success(MostPopularMovies(errorMessage: "", items: movies)))
    }

    func loadImageData(
        from url: URL,
        handler: @escaping @Sendable (Result<Data, Error>) -> Void
    ) -> ImageLoadingTask {
        handler(.success(imageData))
        return UITestImageLoadingTask()
    }
}

private struct UITestImageLoadingTask: ImageLoadingTask {
    func cancel() { }
}
#endif
