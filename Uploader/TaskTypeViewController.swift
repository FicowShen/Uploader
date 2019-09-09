import UIKit

enum Scene: String {
    case normalTask = "Normal Task"
    case downloadTask = "Download Task"
    case uploadTask = "Upload Task"
}

var groupTaskObservers = [Scene: GroupTaskCountObserver]()

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

        let observer: GroupTaskCountObserver
        if let oldObserver = groupTaskObservers[scene] {
            observer = oldObserver
        } else {
            let newObserver = GroupTaskCountObserver(scene: scene, delegate: self)
            groupTaskObservers[scene] = newObserver
            observer = newObserver
        }
        mockTaskManagers[scene]?.observeGroupTasks(vc.currentTasks, observer: observer)
        navigationController?.pushViewController(vc, animated: true)
    }


    private func groupTaskDidFinish(_ info: (successCount: Int, failureCount: Int), forScene scene: Scene) {
        showGroupTaskNotification(groupID: scene.rawValue, successCount: info.successCount, failureCount: info.failureCount)
    }

}

extension TaskTypeViewController: GroupTaskCountObserverDelegate {
    func groupTaskDidFinish(observer: GroupTaskCountObserver, successCount: Int, failureCount: Int) {
        groupTaskDidFinish((successCount: successCount, failureCount: failureCount), forScene: observer.scene)
    }
}
