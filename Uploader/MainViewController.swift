import UIKit
import RxSwift

enum Scene: String {
    case normalUpload = "Normal Upload Scene"
    case groupUpload1 = "Group Upload Scene 1"
    case groupUpload2 = "Group Upload Scene 2"
}

class MainViewController: UIViewController {

    @IBOutlet var tasksButton: [UIButton]!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

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
        vc.workingTasks.subscribe { [weak self] (event) in
            switch event {
            case .next(let tasks):
                self?.observeWorkingTasks(tasks, forScene: scene)
            default:
                break
            }
        }.disposed(by: disposeBag)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func observeWorkingTasks(_ tasks: [Task], forScene scene: Scene) {
        tasks
            .groupObservable
            .subscribe { [weak self] (event) in
                switch event {
                case .next(let info):
                    self?.groupUploadDidFinish(info, forScene: scene)
                default:
                    break
                }
            }.disposed(by: disposeBag)
    }

    private func groupUploadDidFinish(_ info: (successCount: Int, failureCount: Int), forScene scene: Scene) {
        showGroupTaskNotification(groupID: scene.rawValue, successCount: info.successCount, failureCount: info.failureCount)
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
        UIViewController.showAlert(msg: msg)
        DLog(msg)
    }

    static func showAlert(msg: String) {
        let topMostVC = topMostViewController()
        if let _ = topMostVC.presentedViewController {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
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

