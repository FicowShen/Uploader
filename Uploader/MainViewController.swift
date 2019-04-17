import UIKit

enum Scene: String {
    case normalUpload = "Normal Upload Scene"
    case groupUpload1 = "Group Upload Scene 1"
    case groupUpload2 = "Group Upload Scene 2"
}

class MainViewController: UIViewController {

    @IBOutlet var tasksButton: [UIButton]!

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(groupUploadDidFinish(_:)), name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @IBAction func buttonTapped(_ sender: UIButton) {

        guard let scene = Scene.init(rawValue: sender.currentTitle ?? "")
            else { fatalError() }
        let vc = TaskTableViewController.init(scene: scene)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    private func groupUploadDidFinish(_ notification: Notification) {
        showGroupTaskNotification(notification)
    }

}

extension UIViewController {

    func showGroupTaskNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let info = userInfo[UploadManager.GroupUploadingDidFinishNotification.UserInfoKey] as? [String: Any],
            let groupID = info[UploadManager.GroupUploadingDidFinishNotification.GroupIDKey] as? String,
            let succeededCount = info[UploadManager.GroupUploadingDidFinishNotification.SucceededCountKey] as? Int,
            let failedCount = info[UploadManager.GroupUploadingDidFinishNotification.FailedCountKey] as? Int else { return }

        guard let _ = self.view.window else { return }
        let msg = """
        \(groupID) 已完成！
        成功：\(succeededCount) 个任务，
        失败：\(failedCount) 个任务。
        """
        UIViewController.showAlert(msg: msg)
        DLog(msg)
    }

    static func showAlert(msg: String) {
        let topMostVC = topMostViewController()
        if let _ = topMostVC.presentedViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
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

