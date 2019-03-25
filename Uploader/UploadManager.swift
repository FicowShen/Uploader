import Foundation

func myDebugPrint(_ items: Any...) {
//    print(items)
}

class UploadManager: NSObject {

    static let shared = UploadManager()
    
    struct GroupUploadingDidFinishNotification {
        static let Name = Notification.Name.init("UploadGroupTaskFinished")
        static let UserInfoKey = Notification.Name.init("GroupUploadingDidFinishNotificationUserInfoKey")
        static let GroupIDKey = "GroupIDKey"
        static let SucceededCountKey = "SucceededCountKey"
        static let FailedCountKey = "FailedCountKey"
    }

    var maxConcurrentTaskCount = 3

    private var readyQueue = [UploadTask]()
    private var uploadingQueue = [URLSessionTask: UploadTask]()
    private var finishedQueue = [UploadTask: (success: Bool, error: Error?)]()
    private var groupMemberCount = [String: Int]()

    private var taskCount = 0

    private lazy var delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "UploadManager.delegateQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    lazy var urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: delegateQueue)

    private override init() {
        super.init()
    }

    func tasks(withIdList IdList: [String]) -> [UploadTask] {
        var tasks = [String: UploadTask]()
        readyQueue.forEach { tasks[$0.id] = $0 }
        uploadingQueue.map { $1 }.forEach { tasks[$0.id] = $0 }
        finishedQueue.map { $0.key }.forEach { tasks[$0.id] = $0 }
        var filterdTasks = [UploadTask]()
        IdList.forEach {
            guard let task = tasks[$0] else { return }
            filterdTasks.append(task)
        }
        return filterdTasks
    }

    func addTask(_ task: UploadTask) {
        if let groupId = task.groupId {
            if let count = self.groupMemberCount[groupId] {
                self.groupMemberCount[groupId] = count + 1
            } else {
                self.groupMemberCount[groupId] = 1
            }
        }
        task.progressDelegate?.uploadTaskDidUpdateState(task)
        self.readyQueue.append(task)
        self.uploadIfPossible()
    }

    func addTasks(_ tasks: [UploadTask]) {
        tasks.forEach {
            $0.progressDelegate?.uploadTaskDidUpdateState($0)
            if let groupId = $0.groupId {
                if let count = self.groupMemberCount[groupId] {
                    self.groupMemberCount[groupId] = count + 1
                } else {
                    self.groupMemberCount[groupId] = 1
                }
            }
            self.readyQueue.append($0)
        }
        self.uploadIfPossible()
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
            self.uploadIfPossible()
        }
    }

    private func uploadTask(_ task: UploadTask) {

        task.state = .uploading
        task.progressDelegate?.uploadTaskDidUpdateState(task)
        
        let sessionTask = urlSession.uploadTask(task) { [weak self] (data, response, error) in
//            myDebugPrint(data, response, error)

            self?.finishedQueue[task] = (success: error == nil, error: error)

            if let error = error {
                task.state = .failed(error)
            } else {
                task.state = .succeeded
            }
            task.progressDelegate?.uploadTaskDidUpdateState(task)
            
            guard let groupId = task.groupId,
                let count = self?.groupMemberCount[groupId]
                else { return }
            
            guard count == 1 else {
                self?.groupMemberCount[groupId] = count - 1
                return
            }
            
            self?.groupMemberCount[groupId] = nil

            guard let finishedTasks = self?.finishedQueue.keys.filter({ $0.groupId == groupId })
                else { return }
            let succeededCount = finishedTasks.reduce(0, { (result: Int, task: UploadTask) -> Int in
                switch task.state {
                case .succeeded:
                    return result + 1
                default:
                    return result
                }
            })
            let failedCount = finishedTasks.count - succeededCount
            finishedTasks.forEach { $0.removeGroupId() }
            let userInfo = [GroupUploadingDidFinishNotification.GroupIDKey: groupId,
                            GroupUploadingDidFinishNotification.SucceededCountKey: succeededCount,
                            GroupUploadingDidFinishNotification.FailedCountKey: failedCount] as [String: Any]
            NotificationCenter.default.post(name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil, userInfo: [UploadManager.GroupUploadingDidFinishNotification.UserInfoKey: userInfo])
        }
        uploadingQueue[sessionTask] = task
    }

}

extension UploadManager: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
//        myDebugPrint(task)
//        myDebugPrint(bytesSent)
//        myDebugPrint(totalBytesSent)
//        myDebugPrint(totalBytesExpectedToSend)

        DispatchQueue.main.async {
            guard let uploadTask = self.uploadingQueue[task] else { return }
            uploadTask.progress.totalUnitCount = totalBytesExpectedToSend
            uploadTask.progress.completedUnitCount = totalBytesSent
            uploadTask.progressDelegate?.uploadTaskDidUpdateProgress(uploadTask)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        DispatchQueue.main.async {
            self.uploadingQueue[task] = nil
            self.taskCount -= 1
            self.uploadIfPossible()
        }

//        myDebugPrint(task)
//        myDebugPrint(error)
    }
}
