import Foundation

protocol GroupTaskCompletionObserver: class {
    func groupTaskDidComplete<Task: TaskProtocol>(_ task: Task)
}

final class TaskScheduler<Task: TaskProtocol> {

    var maxWorkingTasksCount: Atomic<Int> = Atomic<Int>(3)

    private(set) var readyTasks = Atomic<[Task]>([])
    private(set) var workingTasks = Atomic<Set<Task>>(Set())
    private(set) var finishedTasks = Atomic<[Task]>([])

    var allTasks: [Task] {
        return workingTasks.value + readyTasks.value + finishedTasks.value
    }

    private var groupTaskSubscription = Atomic<NSMapTable<AnyObject, NSString>>(.weakToStrongObjects())

    private let executeQueue: DispatchQueue
    private let callbackQueue: DispatchQueue

    init(executeQueue: DispatchQueue = DispatchQueue(label: "TaskManagerQueue-" + UUID().uuidString), callbackQueue: DispatchQueue = .main) {
        self.executeQueue = executeQueue
        self.callbackQueue = callbackQueue
    }

    func addTask(_ task: Task) {
        executeQueue.async { [weak self] in
            guard let self = self else { return }
            self.readyTasks.value.append(task)
            self.runTaskIfNeeded()
        }
    }

    func addTasks(_ tasks: [Task]) {
        tasks.forEach { addTask($0) }
    }

    func observeGroupTaskCompletion(groupId: String, observer: GroupTaskCompletionObserver) {
        groupTaskSubscription.value.setObject(groupId as NSString, forKey: observer)
    }

    func removeGroupTaskObserver(_ observer: GroupTaskCompletionObserver) {
        groupTaskSubscription.value.setObject(nil, forKey: observer)
    }

    private func runTaskIfNeeded() {
        executeQueue.async { [weak self] in
            guard let self = self else { return }
            self.putReadyTasksIntoWorkingQueue()
        }
    }

    private func putReadyTasksIntoWorkingQueue() {
        guard !readyTasks.value.isEmpty,
            workingTasks.value.count < maxWorkingTasksCount.value
            else { return }

        let toWorkCount = maxWorkingTasksCount.value - workingTasks.value.count
        let toWorkTasks = [Task](readyTasks.value.prefix(toWorkCount))

        guard !toWorkTasks.isEmpty else { return }
        readyTasks.value.removeFirst(min(readyTasks.value.count, toWorkTasks.count))
        toWorkTasks.forEach { startWork($0) }

        if workingTasks.value.count < maxWorkingTasksCount.value {
            putReadyTasksIntoWorkingQueue()
        }
    }

    private func updateTaskState(_ task: Task, state: TaskState) {
        task.state.value = state
        notifySubscribersForTask(task)
    }

    private func notifySubscribersForTask<Task: TaskProtocol>(_ task: Task) {
        callbackQueue.async {
            task.delegate?.taskStateDidChange(task)
        }

        notifyGroupTaskCompletion(task)
    }

    private func notifyGroupTaskCompletion<Task: TaskProtocol>(_ task: Task) {

        switch task.state.value {
        case .ready, .working: return
        default: break
        }

        guard let taskGroupId = task.groupId as NSString?,
            let groupIds = groupTaskSubscription.value.objectEnumerator()?.allObjects as? [NSString],
            groupIds.contains(taskGroupId) else {
                return
        }

        let groupTasksObserver = groupTaskSubscription.value.keyEnumerator().allObjects as? [GroupTaskCompletionObserver]
        groupTasksObserver?.forEach { (observer) in
            guard let groupId = groupTaskSubscription.value.object(forKey: observer),
                groupId == taskGroupId
                else { return }
            callbackQueue.async {
                observer.groupTaskDidComplete(task)
            }
        }
    }


    private func startWork(_ task: Task) {
        workingTasks.value.insert(task)
        updateTaskState(task, state: .ready)
        task.start(scheduler: self)
    }

    private func taskDidFinish<Task: TaskProtocol>(_ task: Task) {
        guard let index = workingTasks.value.firstIndex(where: { $0.id == task.id })
            else { return }
        let finishedTask = workingTasks.value.remove(at: index)
        finishedTasks.value.append(finishedTask)
        putReadyTasksIntoWorkingQueue()
    }
}

extension TaskScheduler: TaskStateObserver {
    func taskStateDidChange<Task: TaskProtocol>(_ task: Task, state: TaskState) {
        executeQueue.async { [weak self] in
            switch state {
            case .success, .failure:
                self?.taskDidFinish(task)
            default: break
            }
            self?.notifySubscribersForTask(task)
        }
    }
}
