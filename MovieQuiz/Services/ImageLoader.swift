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
    private let cache = NSCache<NSURL, NSData>()

    init(
        session: URLSession = .shared,
        cacheCountLimit: Int = 100,
        cacheTotalCostLimit: Int = 50 * 1024 * 1024
    ) {
        self.session = session
        cache.countLimit = cacheCountLimit
        cache.totalCostLimit = cacheTotalCostLimit
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
        cache.object(forKey: url as NSURL) as Data?
    }

    private func cache(_ data: Data, for url: URL) {
        guard data.count <= cache.totalCostLimit else { return }
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
    }
}

private enum ImageLoaderError: Error {
    case invalidStatusCode
    case emptyData
}

private struct CompletedImageLoadingTask: ImageLoadingTask {
    func cancel() { }
}
