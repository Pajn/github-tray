import Foundation

class GitHubTrayEventHandler: EventHandler {
    weak var controller: StatusBarController?
    
    init(controller: StatusBarController) {
        self.controller = controller
    }
    
    func onStateChanged(state: AppState) {
        DispatchQueue.main.async { [weak self] in
            self?.controller?.updateState(state)
        }
    }
    
    func onError(error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.controller?.showError(error)
        }
    }
}
