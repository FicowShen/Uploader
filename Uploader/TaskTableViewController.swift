import UIKit

var normalTaskIDs = [String]()
var groupTaskIDs1 = [String]()
var groupTaskIDs2 = [String]()

class TaskTableViewController: UITableViewController {

    private let scene: Scene
    
    private var currentTasks = [UploadTask]() {
        didSet {
            currentTasks.enumerated().forEach { taskRowIndice[$1] = $0 }
        }
    }

    private var taskRowIndice = [UploadTask: Int]()
    
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

        tableView.allowsSelection = false
        tableView.register(UINib.init(nibName: TaskTableViewCell.ID, bundle: nil), forCellReuseIdentifier: TaskTableViewCell.ID)
        loadMockTasks()
    }
    
    func loadMockTasks() {

        if scene != .normalUpload {
            NotificationCenter.default.addObserver(self, selector: #selector(groupUploadDidFinish(_:)), name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil)
        }

        switch scene {
        case .normalUpload:
            if normalTaskIDs.isEmpty {
                (0...3).forEach { (_) in
                    let task = UploadTask()
                    normalTaskIDs.append(task.id)
                    currentTasks.append(task)
                    UploadManager.shared.addTasks(currentTasks)
                }
            } else {
                currentTasks = UploadManager.shared.tasks(withIdList: normalTaskIDs)
            }
        case .groupUpload1:
            if groupTaskIDs1.isEmpty {
                (0...7).forEach { (_) in
                    let task = UploadTask(groupId: scene.rawValue)
                    groupTaskIDs1.append(task.id)
                    currentTasks.append(task)
                    UploadManager.shared.addTasks(currentTasks)
                }
            } else {
                currentTasks = UploadManager.shared.tasks(withIdList: groupTaskIDs1)
            }
        case .groupUpload2:
            if groupTaskIDs2.isEmpty {
                (0...10).forEach { (_) in
                    let task = UploadTask(groupId: scene.rawValue)
                    groupTaskIDs2.append(task.id)
                    currentTasks.append(task)
                    UploadManager.shared.addTasks(currentTasks)
                }
            } else {
                currentTasks = UploadManager.shared.tasks(withIdList: groupTaskIDs2)
            }
        }
    }

    @objc
    private func groupUploadDidFinish(_ notification: Notification){

        self.showGroupTaskNotification(notification)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTasks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.ID, for: indexPath) as? TaskTableViewCell else { fatalError() }
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        guard let cell = cell as? TaskTableViewCell else { fatalError() }
        cell.order = indexPath.row + 1
        cell.task = currentTasks[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TaskTableViewCell.Height
    }

}

