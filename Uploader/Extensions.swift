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
        \(groupID) 已完成！
        成功：\(successCount) 个任务，
        失败：\(failureCount) 个任务。
        """
        UIViewController.showAlert(msg: msg, fromViewController: self)
        DLog(msg)
    }

    static func showAlert(msg: String, fromViewController viewController: UIViewController? = nil) {
        let topMostVC = viewController ?? topMostViewController()
        if let _ = topMostVC.presentedViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
                self.showAlert(msg: msg)
            })
            return
        }

        let alert = UIAlertController(title: "提示", message: msg, preferredStyle: .alert)

        topMostVC.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                alert.dismiss(animated: true, completion: nil)
            })
        }
    }

    private static func topMostViewController(_ rootViewController: UIViewController = UIApplication.shared.delegate!.window!!.rootViewController!) -> UIViewController {

        if let presented = rootViewController.presentedViewController {
            return topMostViewController(presented)
        }

        switch rootViewController {
        case let navigationController as UINavigationController:
            if let topViewController = navigationController.topViewController {
                return topMostViewController(topViewController)
            }
        case let tabBarController as UITabBarController:
            if let selectedViewController = tabBarController.selectedViewController {
                return topMostViewController(selectedViewController)
            }
        default:
            break
        }
        return rootViewController
    }
}
