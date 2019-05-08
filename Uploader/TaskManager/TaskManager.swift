import Foundation
import RxSwift

class TaskManager<T: Task> {

    var subscribeScheduler: SchedulerType = SerialDispatchQueueScheduler.init(qos: .userInitiated)
    var observeScheduler: SchedulerType = MainScheduler.instance
    var maxWorkingTasksCount = 3

    private var taskObservers = [T: AnyObserver<TaskStateInfo>]()
    private var readyTasks = [T]()
    private var workingTasks = [T: DisposeBag]()
    private var finishedTasks = [T]()

    var currentTasks: [T] {
        return workingTasks.keys + readyTasks + finishedTasks
    }

    func addTask(_ task: T) {
        let publishSubject = PublishSubject<TaskStateInfo>()
        saveTask(task, observer: publishSubject.asObserver())
        task.observable = publishSubject.asObservable().share()
    }

    func addTasks(_ tasks: [T]) {
        tasks.forEach { addTask($0) }
    }

    private func saveTask(_ task: T, observer: AnyObserver<TaskStateInfo>) {
        readyTasks.append(task)
        taskObservers[task] = observer
        putReadyTasksIntoWorkingQueue()
    }

    private func putReadyTasksIntoWorkingQueue() {
        guard !readyTasks.isEmpty,
            workingTasks.count < maxWorkingTasksCount else { return }

        let toWorkCount = maxWorkingTasksCount - workingTasks.count
        let toWorkTasks = [T](readyTasks.prefix(toWorkCount))

        guard !toWorkTasks.isEmpty else { return }
        readyTasks.removeFirst(min(readyTasks.count, toWorkTasks.count))
        toWorkTasks.forEach { startWork($0) }

        if workingTasks.count < maxWorkingTasksCount {
            putReadyTasksIntoWorkingQueue()
        }
    }

    private func startWork(_ task: T) {
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
                task.state = .failure(NSError.makeError(message: "upload failed"))
                observer.onNext((task, .failure(NSError.makeError(message: "upload failed"))))
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

    private func taskFinished(_ task: T) {
        workingTasks[task] = nil
        taskObservers[task] = nil
        finishedTasks.append(task)
        putReadyTasksIntoWorkingQueue()
    }
}
