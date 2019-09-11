import Foundation

protocol GroupTaskCountObserverDelegate: class {
    func groupTaskDidFinish(observer: GroupTaskCountObserver, successCount: Int, failureCount: Int)
}

class GroupTaskCountObserver: GroupTaskProgressObserver {

    let scene: Scene
    let tasks: [Task]

    private weak var delegate: GroupTaskCountObserverDelegate?
    private var successCount = 0
    private var failureCount = 0

    init(scene: Scene, tasks: [Task], delegate: GroupTaskCountObserverDelegate?) {
        self.scene = scene
        self.tasks = tasks
        self.delegate = delegate
    }

    func groupTaskStateDidChange<Task>(_ task: Task, groupId: String) where Task : TaskProtocol {
        switch task.state.value {
        case .success:
            successCount += 1
        case .failure:
            failureCount += 1
        default: return
        }
        if successCount + failureCount == tasks.count {
            delegate?.groupTaskDidFinish(observer: self, successCount: successCount, failureCount: failureCount)
        }
    }
}
