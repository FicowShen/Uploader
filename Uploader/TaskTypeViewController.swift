import UIKit

enum Scene: String {
    case normalTask = "Normal Task"
    case downloadTask = "Download Task"
    case uploadTask = "Upload Task"
}

final class TaskTypeViewController: UIViewController {

    @IBOutlet var tasksButton: [UIButton]!

    override func viewDidLoad() {
        super.viewDidLoad()

        tasksButton.forEach { [unowned self] (button) in
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        guard let scene = Scene.init(rawValue: sender.currentTitle ?? "")
            else { fatalError() }
        let vc = TaskTableViewController.init(scene: scene)
//        vc.workingTasks.subscribe { [unowned self] (event) in
//            switch event {
//            case .next(let tasks):
//                self.observeWorkingTasks(tasks, forScene: scene)
//            default: break
//            }
//        }.disposed(by: disposeBag)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func observeWorkingTasks(_ tasks: [Task], forScene scene: Scene) {
//        tasks
//            .groupObservable
//            .subscribe { [weak self] (event) in
//                switch event {
//                case .next(let info):
//                    self?.groupTaskDidFinish(info, forScene: scene)
//                default: break
//                }
//            }.disposed(by: disposeBag)
    }

    private func groupTaskDidFinish(_ info: (successCount: Int, failureCount: Int), forScene scene: Scene) {
        showGroupTaskNotification(groupID: scene.rawValue, successCount: info.successCount, failureCount: info.failureCount)
    }

}
