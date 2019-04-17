import Foundation
import RxSwift

class TaskManager {

    var maxWorkingTasksCount = 3

    private(set) var taskObservers = [Task: AnyObserver<TaskStateInfo>]()
    private(set) var readyTasks = [Task]()
    private(set) var workingTasks = [Task: DisposeBag]()
    private(set) var finishedTasks = [Task]()

    func addTask(_ task: Task) {
        let observable = Observable<TaskStateInfo>.create({ [weak self] (observer) -> Disposable in
            self?.saveTask(task, observer: observer)
            return Disposables.create()
        }).share()
        task.observable = observable
    }

    func addTasks(_ tasks: [Task]) {
        tasks.forEach { task in
            let publishSubject = PublishSubject<TaskStateInfo>()
            self.saveTask(task, observer: publishSubject.asObserver())
            task.observable = publishSubject.asObservable().share()
        }
    }

    private func saveTask(_ task: Task, observer: AnyObserver<TaskStateInfo>) {
        readyTasks.append(task)
        self.taskObservers[task] = observer
        putReadyTasksIntoWorkingQueue()
    }

    private func putReadyTasksIntoWorkingQueue() {
        guard !readyTasks.isEmpty,
            readyTasks.count <= maxWorkingTasksCount else { return }

        let toWorkCount = maxWorkingTasksCount - readyTasks.count
        let toWorkTasks = [Task](readyTasks.prefix(toWorkCount))

        guard !toWorkTasks.isEmpty else { return }
        readyTasks.removeFirst(min(readyTasks.count, toWorkTasks.count))
        toWorkTasks.forEach { startWork($0) }

        if workingTasks.count < maxWorkingTasksCount {
            putReadyTasksIntoWorkingQueue()
        }
    }

    private func startWork(_ task: Task) {
        guard let observer = taskObservers[task] else { return }

        let disposeBag = DisposeBag()
        workingTasks[task] = disposeBag

        task.state = .ready
        observer.onNext((task, .ready))
        task.work().subscribe(onNext: { (progress) in
            task.state = .working(progress: progress)
            observer.onNext((task, .working(progress: progress)))
        }, onError: { [weak self] (error) in
            task.state = .fail(error: NSError.makeError(message: "upload failed"))
            observer.onNext((task, .fail(error: NSError.makeError(message: "upload failed"))))
            observer.onCompleted()
            task.observable = nil
            self?.taskFinished(task)
        }, onCompleted: { [weak self] in
            task.state = .success
            observer.onNext((task, .success))
            task.observable = nil
            observer.onCompleted()
            self?.taskFinished(task)
        }).disposed(by: disposeBag)
    }

    private func taskFinished(_ task: Task) {
        workingTasks[task] = nil
        taskObservers[task] = nil
        finishedTasks.append(task)
        putReadyTasksIntoWorkingQueue()
    }
}
