import UIKit

var mockTaskManagers = [Scene: TaskManager]()

class TaskTableViewController: UITableViewController {

    private let scene: Scene
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
        switch scene {
        case .normalUpload:
            guard let taskManager = mockTaskManagers[scene] else {
                (0...4).forEach { (_) in
                    let task = Task(request: URLRequest(url: URL(string: "xxx")!))
                    currentTasks.append(task)
                }
                let taskManager = TaskManager()
                mockTaskManagers[scene] = taskManager
                taskManager.addTasks(currentTasks)
                return
            }
            currentTasks.append(contentsOf: taskManager.workingTasks.keys)
            currentTasks.append(contentsOf: taskManager.readyTasks)
            currentTasks.append(contentsOf: taskManager.finishedTasks)
        case .groupUpload1:
            break
        case .groupUpload2:
            break
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

