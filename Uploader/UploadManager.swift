import Foundation

class UploadManager: NSObject {

    static let shared = UploadManager()
    
    struct GroupUploadingDidFinishNotification {
        static let Name = Notification.Name.init("GroupUploadingDidFinishNotification")
        static let UserInfoKey = "GroupUploadingDidFinishNotification-UserInfoKey"
        static let GroupIDKey = "GroupUploadingDidFinishNotification-GroupIDKey"
        static let SucceededCountKey = "GroupUploadingDidFinishNotification-SucceededCountKey"
        static let FailedCountKey = "GroupUploadingDidFinishNotification-FailedCountKey"
    }

    var maxConcurrentTaskCount = 3

    private var readyQueue = [UploadTask]()
    private var uploadingQueue = [String: UploadTask]()
    private var finishedQueue = [UploadTask: (success: Bool, error: Error?)]()
    private var groupMemberCount = [String: Int]()

    private var taskCount = 0

    private override init() { super.init() }

    func tasks(forIdList IdList: [String]) -> [UploadTask] {
        var tasks = [String: UploadTask]()
        readyQueue.forEach { tasks[$0.id] = $0 }
        uploadingQueue.map { $1 }.forEach { tasks[$0.id] = $0 }
        finishedQueue.map { $0.key }.forEach { tasks[$0.id] = $0 }
        return IdList.compactMap { tasks[$0] }
    }

    func addTask(_ task: UploadTask) {
        guard tasks(forIdList: [task.id]).isEmpty else {
            assertionFailure()
            return
        }
        increaseGroupCount(forTask: task)
        task.progressDelegate?.uploadTaskDidUpdateState(task)
        readyQueue.append(task)
        uploadIfPossible()
    }

    func addTasks(_ tasks: [UploadTask]) {
        let idList = tasks.map { $0.id }
        guard self.tasks(forIdList: idList).isEmpty else {
            assertionFailure()
            return
        }
        tasks.forEach {
            increaseGroupCount(forTask: $0)
            $0.progressDelegate?.uploadTaskDidUpdateState($0)
            readyQueue.append($0)
        }
        uploadIfPossible()
    }

    private func uploadIfPossible() {

        guard !readyQueue.isEmpty,
            taskCount < maxConcurrentTaskCount
            else { return }

        let toUploadCount = maxConcurrentTaskCount - taskCount
        let toUploadTasks = [UploadTask](readyQueue.prefix(toUploadCount))

        guard !toUploadTasks.isEmpty else { return }

        readyQueue.removeFirst(min(readyQueue.count, toUploadTasks.count))
        toUploadTasks.forEach { uploadTask($0) }
        taskCount += toUploadTasks.count

        if taskCount < maxConcurrentTaskCount {
            uploadIfPossible()
        }
    }

    private func uploadTask(_ task: UploadTask) {

        task.state = .uploading
        task.progressDelegate?.uploadTaskDidUpdateState(task)
        uploadingQueue[task.id] = task

        mockUploadTask(task) { [unowned self] (task, error) in
            self.processFinishedTask(task, error: error)
        }
    }

    private func processFinishedTask(_ task: UploadTask, error: Error?) {

        assert(Thread.current.isMainThread)
        defer { self.uploadIfPossible() }

        finishedQueue[task] = (success: error == nil, error: error)
        uploadingQueue[task.id] = nil
        taskCount -= 1

        if let error = error {
            task.state = .failed(error)
        } else {
            task.state = .succeeded
        }
        task.progressDelegate?.uploadTaskDidUpdateState(task)
        decreaseGroupCount(forTask: task)
    }

    private func increaseGroupCount(forTask task: UploadTask) {
        guard let groupId = task.groupId else { return }
        guard let count = groupMemberCount[groupId] else {
            groupMemberCount[groupId] = 1
            return
        }
        groupMemberCount[groupId] = count + 1
    }
    
    private func decreaseGroupCount(forTask task: UploadTask) {
        guard let groupId = task.groupId,
            let count = groupMemberCount[groupId]
            else { return }
        guard count == 1 else {
            groupMemberCount[groupId] = count - 1
            return
        }
        groupMemberCount[groupId] = nil
        sendGroupTaskCompletionNotification(forGroup: groupId)
    }

    private func sendGroupTaskCompletionNotification(forGroup id: String) {
        let finishedTasks = finishedQueue.keys.filter({ $0.groupId == id })
        let succeededCount = finishedTasks.reduce(0, { (result: Int, task: UploadTask) -> Int in
            switch task.state {
            case .succeeded: return result + 1
            default: return result
            }
        })
        let failedCount = finishedTasks.count - succeededCount
        finishedTasks.forEach { $0.removeGroupId() }
        let userInfo = [GroupUploadingDidFinishNotification.GroupIDKey: id,
                        GroupUploadingDidFinishNotification.SucceededCountKey: succeededCount,
                        GroupUploadingDidFinishNotification.FailedCountKey: failedCount] as [String: Any]
        NotificationCenter.default.post(name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil, userInfo: [UploadManager.GroupUploadingDidFinishNotification.UserInfoKey: userInfo])
    }

}

extension UploadManager {

    func mockUploadTask(_ task: UploadTask, completionHandler: @escaping (UploadTask, Error?) -> Void) {
        
        let delay = Int.random(in: 0...5)
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(delay)) {
            var error: Error?
            defer {
                DispatchQueue.main.async {
                    completionHandler(task, error)
                }
            }
            guard Int.random(in: 0...2) > 0 else {
                error = NSError(domain: "Mock Request Failed", code: -1, userInfo: nil)
                return
            }
            (1...50).forEach { (value) in
                let interval = TimeInterval(Int.random(in: 0...8)) * 0.01
                Thread.sleep(forTimeInterval: interval)
                let currentValue = Int64(value * 2)
                DispatchQueue.main.async {
                    task.progress.totalUnitCount = 100
                    task.progress.completedUnitCount = currentValue
                    task.progressDelegate?.uploadTaskDidUpdateProgress(task)
                }
            }
        }
    }
}
