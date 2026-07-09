import Foundation

protocol ImageLoadingTask: Sendable {
    func cancel()
}

protocol ImageLoading {
    func loadImageData(
        from url: URL,
        handler: @escaping @Sendable (Result<Data, Error>) -> Void
    ) -> ImageLoadingTask
}

extension URLSessionDataTask: ImageLoadingTask { }

final class ImageLoader: ImageLoading, @unchecked Sendable {
    private let session: URLSession
    private let lock = NSLock()
    private var cache: [URL: Data] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadImageData(
        from url: URL,
        handler: @escaping @Sendable (Result<Data, Error>) -> Void
    ) -> ImageLoadingTask {
        if let cachedData = cachedData(for: url) {
            handler(.success(cachedData))
            return CompletedImageLoadingTask()
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let error {
                handler(.failure(error))
                return
            }

            if let response = response as? HTTPURLResponse,
               response.statusCode < 200 || response.statusCode >= 300 {
                handler(.failure(ImageLoaderError.invalidStatusCode))
                return
            }

            guard let data else {
                handler(.failure(ImageLoaderError.emptyData))
                return
            }

            self?.cache(data, for: url)
            handler(.success(data))
        }

        task.resume()
        return task
    }

    private func cachedData(for url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }

    private func cache(_ data: Data, for url: URL) {
        lock.lock()
        cache[url] = data
        lock.unlock()
    }
}

private enum ImageLoaderError: Error {
    case invalidStatusCode
    case emptyData
}

private struct CompletedImageLoadingTask: ImageLoadingTask {
    func cancel() { }
}
