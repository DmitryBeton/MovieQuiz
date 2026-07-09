import Foundation

struct QuizQuestion: Sendable {
    // постер фильма
    let image: Data
    // вопрос о рейтинге фильма
    let text: String
    // правильный ответ
    let correctAnswer: Bool
}
