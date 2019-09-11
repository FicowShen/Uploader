import Foundation

protocol GroupTaskCountObserverDelegate: class {
    func groupTaskDidFinish(observer: GroupTaskCountObserver, successCount: Int, failureCount: Int)
}

class GroupTaskCountObserver: GroupTaskCompletionObserver {

    let groupId: String
    let tasks: [Task]

    private weak var delegate: GroupTaskCountObserverDelegate?

    private var successCount = 0
    private var failureCount = 0

    init(groupId: String, tasks: [Task], delegate: GroupTaskCountObserverDelegate?) {
        self.groupId = groupId
        self.tasks = tasks
        self.delegate = delegate
    }

    func groupTaskDidComplete<Task>(_ task: Task) where Task : TaskProtocol {
        switch task.state.value {
        case .ready, .working: return
        case .success:
            successCount += 1
        case .failure:
            failureCount += 1
        }
        if successCount + failureCount == tasks.count {
            delegate?.groupTaskDidFinish(observer: self, successCount: successCount, failureCount: failureCount)
        }
    }
}
