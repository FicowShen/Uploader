import UIKit
import RxSwift

var mockTaskManagers = [Scene: TaskManager<Task>]()
let mockImageURLs = ["https://cdn.dribbble.com/users/4859/screenshots/6425163/story-1-1600-1200.png", "https://cdn.dribbble.com/users/14268/screenshots/6426256/cpin2.png", "https://img.zcool.cn/community/0107a55cb46cc2a801208f8b40ac5a.jpg@1280w_1l_2o_100sh.jpg", "https://img.zcool.cn/community/0176625cb46cc2a801214168eee26a.jpg@1280w_1l_2o_100sh.jpg", "https://img.zcool.cn/community/0139865cb46cc2a801208f8b3977da.jpg@1280w_1l_2o_100sh.jpg", "https://img.zcool.cn/community/0115875cb46cc2a8012141682c955a.jpg@1280w_1l_2o_100sh.jpg"]

let mockUploadURL = "https://www.googleapis.com/upload/drive/v2/files?uploadType=multipart"

final class TaskTableViewController: UITableViewController {

    var workingTasks: Observable<[Task]> {
        return _workingTasks.asObservable()
    }

    private var _workingTasks = PublishSubject<[Task]>()
    private let scene: Scene
    private let disposeBag = DisposeBag()

    private var taskManager: TaskManager<Task>?
    private var currentTasks = [Task]()

    private lazy var picker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        return picker
    }()

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

        if scene == .uploadTask {
            let uploadButton = UIButton.init(type: .system)
            uploadButton.setTitle("Upload Photo", for: .normal)
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: uploadButton)
            uploadButton.rx.tap.asDriver().drive(onNext: { [weak self] (_) in
                self?.presentImagePicker()
            }).disposed(by: disposeBag)
        }

        loadMockTasks()
    }



    private func loadMockTasks() {
        defer {
            if !currentTasks.isEmpty {
                currentTasks.sort { $0.timeStamp < $1.timeStamp }
                observeGroupProgress()
                _workingTasks.onNext(currentTasks)
            }
        }
        guard let taskManager = mockTaskManagers[scene] else {
            switch scene {
            case .normalTask:
                (0..<6).forEach { (index) in
                    let task = MockTask()
                    currentTasks.append(task)
                }
            case .downloadTask:
                mockImageURLs.forEach { (urlString) in
                    guard let url = URL(string: urlString) else { return }
                    var request = URLRequest(url: url)
                    request.cachePolicy = .reloadIgnoringCacheData
                    let task = DownloadTask(request: request)
                    currentTasks.append(task)
                }
            case .uploadTask:
                break
            }

            let queue = DispatchQueue(label: UUID().uuidString, qos: .background, attributes: .concurrent)
            let taskManager = TaskManager<Task>.init(subscribeScheduler: ConcurrentDispatchQueueScheduler(queue: queue), observeScheduler: MainScheduler.instance)
            self.taskManager = taskManager
            mockTaskManagers[scene] = taskManager
            taskManager.addTasks(currentTasks)
            return
        }
        self.taskManager = taskManager
        currentTasks = taskManager.currentTasks
    }

    private func presentImagePicker() {
        present(picker, animated: true, completion: nil)
    }

    private func observeGroupProgress() {
        currentTasks
            .groupObservable
            .subscribe { [weak self] (event) in
                switch event {
                case .next(let element):
                    self?.groupTaskDidFinish(element)
                default:
                    break
                }
            }.disposed(by: disposeBag)
    }

    private func groupTaskDidFinish(_ info: (successCount: Int, failureCount: Int)) {
        showGroupTaskNotification(groupID: scene.rawValue, successCount: info.successCount, failureCount: info.failureCount)
    }

    private func upload(image: UIImage) {
        guard let url = URL.init(string: mockUploadURL) else { return }
        Observable.just(image.jpegData(compressionQuality: 1))
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] (data) in
                guard let data = data else { return }
                var request = URLRequest.init(url: url)
                request.httpMethod = "POST"
                let task = UploadTask(request: request, data: data)
                self.currentTasks.append(task)
                self.tableView.reloadData()
                self.taskManager?.addTask(task)
            }).disposed(by: disposeBag)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTasks.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskTableViewCell.ID, for: indexPath) as? TaskTableViewCell
            else { fatalError() }
        cell.scene = self.scene
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
}

