import UIKit
import RxSwift

var mockTaskManagers = [Scene: TaskManager<Task>]()
let mockImageURLs = ["https://cdn.dribbble.com/users/4859/screenshots/6425163/story-1-1600-1200.png", "https://cdn.dribbble.com/users/14268/screenshots/6426256/cpin2.png", "https://img.zcool.cn/community/0107a55cb46cc2a801208f8b40ac5a.jpg@1280w_1l_2o_100sh.jpg", "https://img.zcool.cn/community/0176625cb46cc2a801214168eee26a.jpg@1280w_1l_2o_100sh.jpg", "https://img.zcool.cn/community/0139865cb46cc2a801208f8b3977da.jpg@1280w_1l_2o_100sh.jpg", "https://img.zcool.cn/community/0115875cb46cc2a8012141682c955a.jpg@1280w_1l_2o_100sh.jpg"]

let mockUploadURL = "http://172.26.10.89:8000/TestUpload/"

class TaskTableViewController: UITableViewController {

    var workingTasks: Observable<[Task]> {
        return _workingTasks.asObservable()
    }

    private var _workingTasks = PublishSubject<[Task]>()
    private let scene: Scene
    private let disposeBag = DisposeBag()
    private var currentTasks = [Task]()

    private let picker = UIImagePickerController()

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
        tableView.estimatedRowHeight = 86
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
        tableView.register(UINib.init(nibName: TaskTableViewCell.ID, bundle: nil), forCellReuseIdentifier: TaskTableViewCell.ID)

//        loadMockTasks()
        delay(seconds: 0.5) {
            self.test()
        }
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
            (0..<taskCount).forEach { (index) in
                guard let url = URL(string: mockImageURLs[index % mockImageURLs.count]) else { return }
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringCacheData
                let task = DownloadTask(request: request)
                currentTasks.append(task)
            }
            let taskManager = TaskManager<Task>()
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

}

extension TaskTableViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        defer { picker.dismiss(animated: true, completion: nil) }
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        self.upload(image: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func test() {
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }

    func upload(image: UIImage) {
        guard let url = URL.init(string: mockUploadURL), let data = image.jpegData(compressionQuality: 1) else { return }
        var request = URLRequest.init(url: url)
        request.httpMethod = "POST"
        let task = UploadTask(request: request, data: data)
        currentTasks.append(task)
        self.tableView.reloadData()
        let taskManager = TaskManager<Task>()
        mockTaskManagers[scene] = taskManager
        taskManager.addTasks(currentTasks)
    }
}

