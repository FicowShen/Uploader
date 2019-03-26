import Foundation

func myDebugPrint(_ items: Any...) {
//    print(items)
}

class UploadManager: NSObject {

    static let shared = UploadManager()
    
    struct GroupUploadingDidFinishNotification {
        static let Name = Notification.Name.init("UploadGroupTaskFinished")
        static let UserInfoKey = "GroupUploadingDidFinishNotificationUserInfoKey"
        static let GroupIDKey = "GroupIDKey"
        static let SucceededCountKey = "SucceededCountKey"
        static let FailedCountKey = "FailedCountKey"
    }

    var maxConcurrentTaskCount = 3

    private let readyDispatchQueue = DispatchQueue(label: "readyDispatchQueue")
    private let uploadingDispatchQueue = DispatchQueue(label: "uploadingDispatchQueue")
    private let finishedDispatchQueue = DispatchQueue(label: "finishedDispatchQueue")
    private let groupCountDispatchQueue = DispatchQueue(label: "groupCountDispatchQueue")
    
    private var _readyQueue = [UploadTask]()
    private var _uploadingQueue = [String: UploadTask]()
    private var _finishedQueue = [UploadTask: (success: Bool, error: Error?)]()
    private var _groupMemberCount = [String: Int]()
    
    private var readyQueue: [UploadTask] {
        get {
            return readyDispatchQueue.sync { self._readyQueue }
        }
        set {
            readyDispatchQueue.sync { self._readyQueue = newValue }
        }
    }
    private var uploadingQueue: [String: UploadTask]  {
        get {
            return uploadingDispatchQueue.sync { self._uploadingQueue }
        }
        set {
            uploadingDispatchQueue.sync {self._uploadingQueue = newValue}
        }
    }
    private var finishedQueue: [UploadTask: (success: Bool, error: Error?)] {
        get {
            return finishedDispatchQueue.sync { self._finishedQueue }
        }
        set {
            finishedDispatchQueue.sync { self._finishedQueue = newValue }
        }
    }
    private var groupMemberCount: [String: Int] {
        get {
            return groupCountDispatchQueue.sync { self._groupMemberCount }
        }
        set {
            groupCountDispatchQueue.sync { self._groupMemberCount = newValue }
        }
    }

    private var taskCount = 0

    private override init() { super.init() }

    func tasks(withIdList IdList: [String]) -> [UploadTask] {
        var tasks = [String: UploadTask]()
        readyQueue.forEach { tasks[$0.id] = $0 }
        uploadingQueue.map { $1 }.forEach { tasks[$0.id] = $0 }
        finishedQueue.map { $0.key }.forEach { tasks[$0.id] = $0 }
        return IdList.compactMap { tasks[$0] }
    }

//    func addTask(_ task: UploadTask) {
//        guard tasks(withIdList: [task.id]).isEmpty else {
//            assertionFailure()
//            return
//        }
//        if let groupId = task.groupId {
//            if let count = self.groupMemberCount[groupId] {
//                self.groupMemberCount[groupId] = count + 1
//            } else {
//                self.groupMemberCount[groupId] = 1
//            }
//        }
//        task.progressDelegate?.uploadTaskDidUpdateState(task)
//        self.readyQueue.append(task)
//        self.uploadIfPossible()
//    }

    func addTasks(_ tasks: [UploadTask]) {
        let idList = tasks.map { $0.id }
        guard self.tasks(withIdList: idList).isEmpty else {
            assertionFailure()
            return
        }
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
        
        uploadingQueue[task.id] = task
        self.mockUploadTask(task) { [unowned self] (task, data, response, error) in
            
//            myDebugPrint(data, response, error)
            dispatchPrecondition(condition: .onQueue(.main))
            self.finishedQueue[task] = (success: error == nil, error: error)
            self.uploadingQueue[task.id] = nil
            self.taskCount -= 1
            defer { self.uploadIfPossible() }

            if let error = error {
                task.state = .failed(error)
            } else {
                task.state = .succeeded
            }
            task.progressDelegate?.uploadTaskDidUpdateState(task)
            
            self.decreaseGroupCount(forTask: task)
        }
        
    }
    
    private func decreaseGroupCount(forTask task: UploadTask) {
        guard let groupId = task.groupId,
            let count = self.groupMemberCount[groupId]
            else { return }
        
        guard count == 1 else {
            self.groupMemberCount[groupId] = count - 1
            return
        }
        
        self.groupMemberCount[groupId] = nil
        self.sendGroupTaskCompletionNotification(forGroup: groupId)
    }
    
    private func sendGroupTaskCompletionNotification(forGroup id: String) {
        let finishedTasks = self.finishedQueue.keys.filter({ $0.groupId == id })
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
        let userInfo = [GroupUploadingDidFinishNotification.GroupIDKey: id,
                        GroupUploadingDidFinishNotification.SucceededCountKey: succeededCount,
                        GroupUploadingDidFinishNotification.FailedCountKey: failedCount] as [String: Any]
        NotificationCenter.default.post(name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil, userInfo: [UploadManager.GroupUploadingDidFinishNotification.UserInfoKey: userInfo])
    }

}

extension UploadManager {

    func mockUploadTask(_ task: UploadTask, completionHandler: @escaping (UploadTask, Data?, URLResponse?, Error?) -> Void) {
        
        let delay = Int.random(in: 0...5)
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(delay)) {
            
            var data: Data?
            var response: URLResponse?
            var error: Error?
            
            defer {
                DispatchQueue.main.async {
                    completionHandler(task, data, response, error)
                }
            }
            guard Int.random(in: 0...1) > 0 else {
                error = NSError(domain: "Mock Request Failed", code: -1, userInfo: nil)
                return
            }
            
            (1...100).forEach { (value) in
                Thread.sleep(forTimeInterval: 0.1)
                let currentValue = Int64(value)
                DispatchQueue.main.async {
                    task.progress.totalUnitCount = 100
                    task.progress.completedUnitCount = currentValue
                    task.progressDelegate?.uploadTaskDidUpdateProgress(task)
                }
            }
            
            data = "Mock Request Succeeded".data(using: .utf8)
            response = URLResponse()
        }
    }
}
