import Foundation

protocol NetworkRouting {
    func fetch(url: URL, handler: @escaping @Sendable (Result<Data, Error>) -> Void)
}

protocol NetworkSessionTask: Sendable {
    func resume()
}

extension URLSessionDataTask: NetworkSessionTask { }

protocol NetworkSession: Sendable {
    func makeDataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkSessionTask
}

extension URLSession: NetworkSession {
    func makeDataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkSessionTask {
        dataTask(with: request, completionHandler: completionHandler)
    }
}

/// Отвечает за загрузку данных по URL
struct NetworkClient: NetworkRouting {
    
    private enum NetworkError: Error {
        case codeError
        case emptyData
    }

    private let session: NetworkSession

    init(session: NetworkSession = URLSession.shared) {
        self.session = session
    }
    
    func fetch(url: URL, handler: @escaping @Sendable (Result<Data, Error>) -> Void) {
        let request = URLRequest(url: url)
        
        let task = session.makeDataTask(with: request) { data, response, error in
            // Проверяем, пришла ли ошибка
            if let error = error {
                handler(.failure(error))
                return
            }
            
            // Проверяем, что нам пришёл успешный код ответа
            if let response = response as? HTTPURLResponse,
               response.statusCode < 200 || response.statusCode >= 300 {
                handler(.failure(NetworkError.codeError))
                return
            }
            
            // Возвращаем данные
            guard let data else {
                handler(.failure(NetworkError.emptyData))
                return
            }
            handler(.success(data))
        }
        
        task.resume()
    }
}
