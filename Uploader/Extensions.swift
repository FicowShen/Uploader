import UIKit

extension NSError {
    static func makeError(message: String, domain: String = "com.ficow.uploader") -> NSError {
        return NSError(domain: domain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension UIViewController {

    func showGroupTaskNotification(groupID: String, successCount: Int, failureCount: Int) {
        guard let _ = self.view.window else { return }
        let msg = """
        \(groupID) finished！
        Success count：\(successCount),
        Failure count：\(failureCount).
        """
        UIViewController.showAlert(msg: msg, fromViewController: self)
        DLog(msg)
    }

    static func showAlert(msg: String, fromViewController viewController: UIViewController? = nil) {

        let rootVC = (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController
        if let _ = rootVC?.presentedViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
                self.showAlert(msg: msg)
            })
            return
        }

        let alert = UIAlertController(title: "Notice", message: msg, preferredStyle: .alert)

        rootVC?.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                alert.dismiss(animated: true, completion: nil)
            })
        }
    }
}
