import Foundation
import RxSwift

final class TaskManager<T: TaskProtocol> {

    var maxWorkingTasksCount = 3

    private let subscribeScheduler: SchedulerType
    private let observeScheduler: SchedulerType

    private var taskObservers = [T: AnyObserver<TaskState>]()
    private var readyTasks = [T]()
    private var workingTasks = [T: DisposeBag]()
    private var finishedTasks = [T]()

    var currentTasks: [T] {
        return workingTasks.keys + readyTasks + finishedTasks
    }

    init(subscribeScheduler: SchedulerType = ConcurrentDispatchQueueScheduler(qos: .background), observeScheduler: SchedulerType = MainScheduler.instance) {
        self.subscribeScheduler = subscribeScheduler
        self.observeScheduler = observeScheduler
    }

    func addTask(_ task: T) {
        let publishSubject = PublishSubject<TaskState>()
        saveTask(task, observer: publishSubject.asObserver())
        task.observable = publishSubject.asObservable().share()
    }

    func addTasks(_ tasks: [T]) {
        tasks.forEach { addTask($0) }
    }

    private func saveTask(_ task: T, observer: AnyObserver<TaskState>) {
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
        observer.onNext(.ready)

        task.start()
            .subscribeOn(subscribeScheduler)
            .observeOn(observeScheduler)
            .subscribe(onNext: { (progress) in
                task.state = .working(progress)
                observer.onNext(.working(progress))
            }, onError: { [weak self] (error) in
                task.state = .failure(error)
                observer.onNext(.failure(error))
                observer.onCompleted()
                task.observable = nil
                self?.taskFinished(task)
            }, onCompleted: { [weak self] in
                task.state = .success
                observer.onNext(.success)
                task.observable = nil
                observer.onCompleted()
                self?.taskFinished(task)
            })
            .disposed(by: disposeBag)
    }

    private func taskFinished(_ task: T) {
        workingTasks[task] = nil
        taskObservers[task] = nil
        finishedTasks.append(task)
        putReadyTasksIntoWorkingQueue()
    }
}
