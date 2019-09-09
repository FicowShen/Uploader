import Foundation

final class MockTask: Task {

    let stateUpdateDuration: TimeInterval
    let failureError: NSError?
    let progressUpdateDurationMaker: (() -> TimeInterval)

    init(delay: TimeInterval, failureError: NSError?, progressUpdateDurationMaker: @escaping (() -> TimeInterval)) {
        self.stateUpdateDuration = delay
        self.failureError = failureError
        self.progressUpdateDurationMaker = progressUpdateDurationMaker
    }

    override func start() {
        let queue = DispatchQueue(label: "MockTaskQueue-" + UUID().uuidString)
        updateState(.ready)
        queue.asyncAfter(deadline: .now() + stateUpdateDuration) {
            (0...100).forEach { (progress) in
                self.updateState(.working(TaskProgress(completedUnitCount: Int64(progress), totalUnitCount: 100)))
                Thread.sleep(forTimeInterval: self.progressUpdateDurationMaker())
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
        delegate?.taskStateDidChange(self)
    }
}
