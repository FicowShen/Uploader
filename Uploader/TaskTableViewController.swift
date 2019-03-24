import UIKit

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

        tableView.allowsSelection = false
        tableView.register(UINib.init(nibName: TaskTableViewCell.ID, bundle: nil), forCellReuseIdentifier: TaskTableViewCell.ID)
        loadMockTasks()
    }
    
    func loadMockTasks() {
        
        switch scene {
        case .normalUpload:
            (0...10).forEach { (_) in
                currentTasks.append(UploadTask())
            }
        case .groupUpload1:
            (0...6).forEach { (_) in
                currentTasks.append(UploadTask(groupId: scene.rawValue))
            }
        case .groupUpload2:
            (0...20).forEach { (_) in
                currentTasks.append(UploadTask(groupId: scene.rawValue))
            }
        }
        
        UploadManager.shared.addTasks(currentTasks)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return currentTasks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.ID, for: indexPath) as? TaskTableViewCell else { fatalError() }
        cell.order = indexPath.row + 1
        cell.task = currentTasks[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TaskTableViewCell.Height
    }

}

