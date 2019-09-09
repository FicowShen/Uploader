import Foundation

final class MockTask: Task {

    let stateUpdateDuration: TimeInterval
    let failureError: NSError?
    let progressUpdateDurationMaker: (() -> TimeInterval)

    private weak var scheduler: TaskStateObserver?

    init(delay: TimeInterval, failureError: NSError?, progressUpdateDurationMaker: @escaping (() -> TimeInterval)) {
        self.stateUpdateDuration = delay
        self.failureError = failureError
        self.progressUpdateDurationMaker = progressUpdateDurationMaker
        super.init()
    }

    override func start(scheduler: TaskStateObserver) {
        self.scheduler = scheduler
        let queue = DispatchQueue(label: "MockTaskQueue-" + UUID().uuidString)
        updateState(.ready)
        queue.asyncAfter(deadline: .now() + stateUpdateDuration) {
            var progress: Int64 = 0
            while true {
                self.updateState(.working(TaskProgress(completedUnitCount: progress, totalUnitCount: 100)))
                progress += Int64.random(in: 1...10)
                Thread.sleep(forTimeInterval: self.progressUpdateDurationMaker())
                if progress > 100 {
                    self.updateState(.working(TaskProgress(completedUnitCount: 100, totalUnitCount: 100)))
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + self.stateUpdateDuration) {
                let state: TaskState
                if let error = self.failureError {
                    state = .failure(error)
                } else {
                    state = .success
                }
                self.updateState(state)
            }
        }
    }

    private func updateState(_ state: TaskState) {
        self.state.value = state
        self.scheduler?.taskStateDidChange(self, state: state)
    }
}
