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
