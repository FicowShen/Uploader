import Foundation
import RxSwift

class TaskManager {

    var subscribeScheduler: SchedulerType = SerialDispatchQueueScheduler.init(qos: .userInitiated)
    var observeScheduler: SchedulerType = MainScheduler.instance

    var maxWorkingTasksCount = 3

    private var taskObservers = [Task: AnyObserver<TaskStateInfo>]()
    private var readyTasks = [Task]()
    private var workingTasks = [Task: DisposeBag]()
    private var finishedTasks = [Task]()

    var currentTasks: [Task] {
        return workingTasks.keys + readyTasks + finishedTasks
    }

    func addTask(_ task: Task) {
        let publishSubject = PublishSubject<TaskStateInfo>()
        saveTask(task, observer: publishSubject.asObserver())
        task.observable = publishSubject.asObservable().share()
    }

    func addTasks(_ tasks: [Task]) {
        tasks.forEach { addTask($0) }
    }

    private func saveTask(_ task: Task, observer: AnyObserver<TaskStateInfo>) {
        readyTasks.append(task)
        taskObservers[task] = observer
        putReadyTasksIntoWorkingQueue()
    }

    private func putReadyTasksIntoWorkingQueue() {
        guard !readyTasks.isEmpty,
            workingTasks.count < maxWorkingTasksCount else { return }

        let toWorkCount = maxWorkingTasksCount - workingTasks.count
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

        task.work()
            .subscribeOn(subscribeScheduler)
            .observeOn(observeScheduler)
            .subscribe(onNext: { (progress) in
                task.state = .working(progress)
                observer.onNext((task, .working(progress)))
            }, onError: { [weak self] (error) in
                task.state = .fail(NSError.makeError(message: "upload failed"))
                observer.onNext((task, .fail(NSError.makeError(message: "upload failed"))))
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
