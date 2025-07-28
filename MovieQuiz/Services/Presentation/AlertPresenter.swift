import UIKit

final class AlertPresenter {
    private weak var viewController: AlertPresenterProtocol?
    
    init(viewController: AlertPresenterProtocol?) {
        self.viewController = viewController
    }
    
    func show(alert model: AlertModel) {
        guard let viewController else {
            return
        }
        
        let alert = UIAlertController(
            title: model.title,
            message: model.message,
            preferredStyle: .alert
        )
        
        let action = UIAlertAction(
            title: model.buttonText,
            style: .default) { _ in
                model.completion()
            }
        
        alert.addAction(action)
        viewController.present(alert: alert, animated: true)
    }
}

