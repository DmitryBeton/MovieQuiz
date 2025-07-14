import Foundation

final class StatisticServiceImplementation: StatisticService, StatisticServiceProtocol {
    
    // MARK: - enum
    private enum Keys: String {
        case correct
        case bestGame
        case gamesCount
        case total
        case date
        case totalCorrect
        case totalQuestions
    }
    
    // MARK: - init
    override init() {
        if storage.object(forKey: Keys.totalCorrect.rawValue) == nil {
            storage.set(0, forKey: Keys.totalCorrect.rawValue)
            storage.set(0, forKey: Keys.totalQuestions.rawValue)
            storage.set(0, forKey: Keys.gamesCount.rawValue)
        }
    }
    
    // MARK: - private vars
    private var correctAnswers: Int = 0
    private let storage: UserDefaults = .standard
    
    // MARK: - properties
    var gamesCount: Int {
        get {
            storage.integer(forKey: Keys.gamesCount.rawValue)
        }
        set {
            storage.set(newValue, forKey: Keys.gamesCount.rawValue)
        }
    }
    var bestGame: GameResult {
        get {
            let correct = storage.integer(forKey: Keys.correct.rawValue)
            let total = storage.integer(forKey: Keys.total.rawValue)
            let date = storage.object(forKey: Keys.date.rawValue) as? Date ?? Date()
            
            return GameResult(correct: correct, total: total, date: date)
        }
        set {
            storage.set(newValue.correct, forKey: Keys.correct.rawValue)
            storage.set(newValue.total, forKey: Keys.total.rawValue)
            storage.set(newValue.date, forKey: Keys.date.rawValue)
        }
    }
    var totalAccuracy: Double {
        get {
            let totalCorrect = storage.integer(forKey: Keys.totalCorrect.rawValue)
            let totalQuestions = storage.integer(forKey: Keys.totalQuestions.rawValue)
            guard totalQuestions > 0 else { return 0 }
            
            return Double(totalCorrect) / Double(totalQuestions) * 100
        }
    }
    
    // MARK: - functions
    func store(correct count: Int, total amount: Int) {
        gamesCount += 1
        
        let newTotalCorrect = storage.integer(forKey: Keys.totalCorrect.rawValue) + count
        let newTotalQuestions = storage.integer(forKey: Keys.totalQuestions.rawValue) + amount
        
        storage.set(newTotalCorrect, forKey: Keys.totalCorrect.rawValue)
        storage.set(newTotalQuestions, forKey: Keys.totalQuestions.rawValue)
        
        let currentGame = GameResult(correct: count, total: amount, date: Date())
        if currentGame.isBetterThan(bestGame) {
            bestGame = currentGame
        }
    }
}
