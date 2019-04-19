import UIKit
import RxSwift

var mockTaskManagers = [Scene: TaskManager]()

class TaskTableViewController: UITableViewController {

    var workingTasks: Observable<[Task]> {
        return _workingTasks.asObservable()
    }

    private var _workingTasks = PublishSubject<[Task]>()
    private let scene: Scene
    private let disposeBag = DisposeBag()
    private var currentTasks = [Task]()

    init(scene: Scene) {
        self.scene = scene
        super.init(style: .plain)
        self.title = scene.rawValue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
        tableView.allowsSelection = false
        tableView.register(UINib.init(nibName: TaskTableViewCell.ID, bundle: nil), forCellReuseIdentifier: TaskTableViewCell.ID)

        loadMockTasks()
    }

    private func loadMockTasks() {
        defer {
            currentTasks.sort { (lhs, rhs) -> Bool in
                return lhs.timeStamp < rhs.timeStamp
            }
            if scene != .normalUpload {
                observeGroupProgress()
                _workingTasks.onNext(currentTasks)
            }
        }
        guard let taskManager = mockTaskManagers[scene] else {
            let taskCount: Int
            switch scene {
            case .normalUpload:
                taskCount = 5
            case .groupUpload1:
                taskCount = 8
            case .groupUpload2:
                taskCount = 16
            }
            (1...taskCount).forEach { (_) in
                let task = Task(request: URLRequest(url: URL(string: "xxx")!))
                currentTasks.append(task)
            }
            let taskManager = TaskManager()
            mockTaskManagers[scene] = taskManager
            taskManager.addTasks(currentTasks)
            return
        }
        currentTasks = taskManager.currentTasks
    }

    private func observeGroupProgress() {
        currentTasks
            .groupObservable
            .subscribe { [weak self] (event) in
                switch event {
                case .next(let element):
                    self?.groupUploadDidFinish(element)
                default:
                    break
                }
            }.disposed(by: disposeBag)
    }

    private func groupUploadDidFinish(_ info: (successCount: Int, failureCount: Int)) {
        showGroupTaskNotification(groupID: scene.rawValue, successCount: info.successCount, failureCount: info.failureCount)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTasks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.ID, for: indexPath) as? TaskTableViewCell
            else { fatalError() }
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        guard let cell = cell as? TaskTableViewCell
            else { fatalError() }
        cell.order = indexPath.row + 1
        cell.task = currentTasks[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TaskTableViewCell.Height
    }

}

