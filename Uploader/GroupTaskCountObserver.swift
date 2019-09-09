import Foundation

protocol GroupTaskCountObserverDelegate: class {
    func groupTaskDidFinish(observer: GroupTaskCountObserver, successCount: Int, failureCount: Int)
}

class GroupTaskCountObserver: GroupTaskProgressObserver {

    let scene: Scene

    private weak var delegate: GroupTaskCountObserverDelegate?
    private var successCount = 0
    private var failureCount = 0

    init(scene: Scene, delegate: GroupTaskCountObserverDelegate?) {
        self.scene = scene
        self.delegate = delegate
    }

    func groupTaskStateDidChange<Task>(_ tasks: [Task]) where Task : TaskProtocol {
        tasks.forEach { (task) in
            switch task.state.value {
            case .success:
                successCount += 1
            case .failure:
                failureCount += 1
            default: break
            }
        }
        if successCount + failureCount == tasks.count {
            delegate?.groupTaskDidFinish(observer: self, successCount: successCount, failureCount: failureCount)
        }
    }
}
