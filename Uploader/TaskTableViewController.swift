import UIKit

var normalTaskIDs = [String]()
var group1TaskIDs = [String]()
var group2TaskIDs = [String]()

class TaskTableViewController: UITableViewController {

    private let scene: Scene
    private var currentTasks = [UploadTask]()

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

        NotificationCenter.default.addObserver(self, selector: #selector(groupUploadDidFinish(_:)), name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil)

        tableView.allowsSelection = false
        tableView.register(UINib.init(nibName: TaskTableViewCell.ID, bundle: nil), forCellReuseIdentifier: TaskTableViewCell.ID)

        loadMockTasks()
    }
    
    private func loadMockTasks() {
        switch scene {
        case .normalUpload:
            if normalTaskIDs.isEmpty {
                (0...4).forEach { (_) in
                    let task = UploadTask()
                    normalTaskIDs.append(task.id)
                    currentTasks.append(task)
                }
                UploadManager.shared.addTasks(currentTasks)
            } else {
                currentTasks = UploadManager.shared.tasks(forIdList: normalTaskIDs)
            }
        case .groupUpload1:
            if group1TaskIDs.isEmpty {
                (0...6).forEach { (_) in
                    let task = UploadTask(groupId: scene.rawValue)
                    group1TaskIDs.append(task.id)
                    currentTasks.append(task)
                }
                UploadManager.shared.addTasks(currentTasks)
            } else {
                currentTasks = UploadManager.shared.tasks(forIdList: group1TaskIDs)
            }
        case .groupUpload2:
            if group2TaskIDs.isEmpty {
                (0...11).forEach { (_) in
                    let task = UploadTask(groupId: scene.rawValue)
                    group2TaskIDs.append(task.id)
                    currentTasks.append(task)
                }
                UploadManager.shared.addTasks(currentTasks)
            } else {
                currentTasks = UploadManager.shared.tasks(forIdList: group2TaskIDs)
            }
        }
    }

    @objc
    private func groupUploadDidFinish(_ notification: Notification) {
        showGroupTaskNotification(notification)
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

