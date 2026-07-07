import UIKit

@MainActor
protocol AlertPresenterProtocol: AnyObject {
    func present(alert: UIAlertController, animated: Bool)
}
