import Foundation
import RxSwift
import RxCocoa

enum MockImageURL: String {
    case size573kb = "https://pixabay.com/get/e036b60f2cfd1c3e955b4704e44b429fe76ae3d01cb5164094f7c771/fox-937049.jpg?attachment"
    case size2mb = "https://pixabay.com/get/ea36b70b2ef11c3e955b4704e44b429fe76ae3d01cb5164094f7c87a/fields-336465.jpg?attachment"
    case size6mb = "https://pixabay.com/get/ed35b40a21f6073ecd1f4407e74e4192ea73ffd41cb4154694f2c17fa7/apple-4055926.jpg?attachment"
    case size10mb = "https://pixabay.com/get/eb35b5072ff0033ecd1f4407e74e4192ea73ffd41cb4154694f1c97fa5/forest-2048742.jpg?attachment"
}

enum TaskState {
    case ready
    case working(progress: Double)
    case success
    case fail(error: Error)
}

class Task: Hashable {
    static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    var hashValue: Int {
        return id.hashValue
    }

    let id = UUID().uuidString
    let request: URLRequest

    init(request: URLRequest) {
        self.request = request
    }
}

class TaskManager {

    var maxWorkingTasksCount = 3

    private var taskObservers = [Task: AnyObserver<(Task, TaskState)>]()
    private var readyQueue = [Task]()
    private var workingQueue = [Task]()
    private var finishedQueue = [Task]()

    func addTask(_ task: Task) -> Observable<(Task, TaskState)> {
        let observable = Observable<(Task, TaskState)>.create({ [weak self] (observer) -> Disposable in
            self?.saveTask(task, observer: observer)
            return Disposables.create()
        })
        return observable
    }

    func addTasks(_ tasks: [Task]) -> Observable<(Task, TaskState)> {
        let observable = Observable<(Task, TaskState)>.create({ [weak self] (observer) -> Disposable in
            tasks.forEach { self?.saveTask($0, observer: observer) }
            return Disposables.create()
        })
        return observable
    }

    private func saveTask(_ task: Task, observer: AnyObserver<(Task, TaskState)>) {
        readyQueue.append(task)
        self.taskObservers[task] = observer
        putReadyTasksIntoWorkingQueue()
    }

    private func putReadyTasksIntoWorkingQueue() {

        guard !readyQueue.isEmpty,
            readyQueue.count <= maxWorkingTasksCount else { return }

        let toUploadCount = maxWorkingTasksCount - readyQueue.count
        let toUploadTasks = [Task](readyQueue.prefix(toUploadCount))

        guard !toUploadTasks.isEmpty else { return }

        readyQueue.removeFirst(min(readyQueue.count, toUploadTasks.count))
        toUploadTasks.forEach { updateTaskState($0) }

        if workingQueue.count < maxWorkingTasksCount {
            putReadyTasksIntoWorkingQueue()
        }
    }

    private func updateTaskState(_ task: Task) {
        guard let observer = taskObservers[task] else { return }
        workingQueue.append(task)

        observer.onNext((task, .ready))
        DispatchQueue.global().async {
            let tryToFail = Bool.random()
            let failNow = { Int.random(in: 0...10) < 3 }
            for i in 0...100 {
                observer.onNext((task, .working(progress: Double(i))))
                if tryToFail && failNow() {
                    observer.onNext((task, .fail(error: NSError.makeError(message: "upload failed"))))
                    self.taskFinished(task)
                    return
                }
            }
            observer.onNext((task, .success))
            self.taskFinished(task)
        }
    }

    private func taskFinished(_ task: Task) {
        guard let index = workingQueue.firstIndex(of: task) else { return }
        workingQueue.remove(at: index)
        finishedQueue.append(task)
        putReadyTasksIntoWorkingQueue()
    }
}
