import Foundation

protocol TaskProgressSubscriber: class {
    func taskStateDidChange<Task: TaskProtocol>(_ task: Task)
}

protocol GroupTaskProgressSubscriber: class {
    func groupTaskStateDidChange<Task: TaskProtocol>(_ tasks: [Task])
}

final class TaskManager<Task: TaskProtocol> {

    var maxWorkingTasksCount: Atomic<Int> = Atomic<Int>(3)

    private(set) var readyTasks = Atomic<[Task]>([])
    private(set) var workingTasks = Atomic<Set<Task>>(Set())
    private(set) var finishedTasks = Atomic<[Task]>([])

    private var subscription = Atomic<NSMapTable<AnyObject, NSMutableSet>>(.weakToStrongObjects())

    private let executeQueue: DispatchQueue
    private let callbackQueue: DispatchQueue

    var allTasks: [Task] {
        return workingTasks.value + readyTasks.value + finishedTasks.value
    }

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

    func subscribeTaskProgress(_ task: Task, subscriber: TaskProgressSubscriber) {
        executeQueue.async {
            if let subscribed = self.subscription.value.object(forKey: subscriber) {
                subscribed.add(task)
            } else {
                self.subscription.value.setObject(NSMutableSet(array: [task]), forKey: subscriber)
            }
        }
    }

    func unsubscribe(_ subscriber: TaskProgressSubscriber, task: Task?) {
        executeQueue.async {
            guard let task = task else {
                self.subscription.value.setObject(nil, forKey: subscriber)
                return
            }
            self.subscription.value.object(forKey: subscriber)?.remove(task)
        }
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
        guard let subscribers = subscription.value.keyEnumerator().allObjects as? [TaskProgressSubscriber]
            else { return }
        subscribers.forEach { (subscriber) in
            guard let taskSet = subscription.value.object(forKey: subscriber),
                taskSet.contains(task)
                else { return }
            callbackQueue.async {
                subscriber.taskStateDidChange(task)
            }
        }
    }

    private func startWork(_ task: Task) {
        workingTasks.value.insert(task)
        updateTaskState(task, state: .ready)
        task.delegate = self
        task.start()
    }

    private func taskDidFinish<Task: TaskProtocol>(_ task: Task) {
        guard let index = workingTasks.value.firstIndex(where: { $0.id == task.id })
            else { return }
        let finishedTask = workingTasks.value.remove(at: index)
        finishedTasks.value.append(finishedTask)
        putReadyTasksIntoWorkingQueue()
    }
}

extension TaskManager: TaskStateDelegate {
    func taskStateDidChange<Task: TaskProtocol>(_ task: Task) {
        switch task.state.value {
        case .success, .failure:
            executeQueue.async { [weak self] in
                guard let self = self else { return }
                self.taskDidFinish(task)
            }
        default: break
        }
        notifySubscribersForTask(task)
    }
}
