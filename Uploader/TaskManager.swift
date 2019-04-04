import Foundation
import RxSwift

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
    let data: Data
    let request: URLRequest

    init(data: Data, request: URLRequest) {
        self.data = data
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
