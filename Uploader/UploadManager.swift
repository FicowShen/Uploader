import Foundation


protocol UploadTaskProgressDelegate {
    func uploadTaskDidUpdateState(_ task: UploadTask)
    func uploadTaskDidUpdateProgress(_ task: UploadTask)
}

protocol UploadTaskProtocol {
    var id: String { get }
    var groupId: String? { get }
    var timeStamp: TimeInterval { get }

    var progressDelegate: UploadTaskProgressDelegate? { get set }
}

func myDebugPrint(_ items: Any...) {
//    print(items)
}

class UploadTask: Hashable, UploadTaskProtocol {

    enum State {
        case ready
        case uploading
        case succeeded
        case failed(Error)
        
        var description: String {
            switch self {
            case .ready:
                return "等待开始"
            case .uploading:
                return "进行中"
            case .succeeded:
                return "已成功"
            case .failed(let error):
                return "已失败, \(error)"
            }
        }
    }
    
    static func == (lhs: UploadTask, rhs: UploadTask) -> Bool {
        return lhs.id == rhs.id
    }

    var hashValue: Int { return id.hashValue }

    let id: String
    let groupId: String?
    let timeStamp: TimeInterval
    
    var state: State = .ready
    let progress = Progress()

    var progressDelegate: UploadTaskProgressDelegate?

    init(id: String = UUID().uuidString, groupId: String? = nil, timeStamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.groupId = groupId
        self.timeStamp = timeStamp
    }
}

class UploadManager: NSObject {

    static let shared = UploadManager()
    
    struct GroupUploadingDidFinishNotification {
        static let Name = Notification.Name.init("UploadGroupTaskFinished")
        static let UserInfoKey = Notification.Name.init("GroupUploadingDidFinishNotificationUserInfoKey")
    }

    var maxConcurrentTaskCount = 3

    private(set) var readyQueue = [UploadTask]()
    private(set) var uploadingQueue = [URLSessionTask: UploadTask]()
    private(set) var finishedQueue = [UploadTask: (success: Bool, error: Error?)]()
    private(set) var groupMemberCount = [String: Int]()

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
            myDebugPrint(data, response, error)
            
            self?.finishedQueue[task] = (success: error == nil, error: error)
            
            task.state = error == nil ? .succeeded : .failed(error!)
            task.progressDelegate?.uploadTaskDidUpdateState(task)
            
            guard let groupId = task.groupId,
                let count = self?.groupMemberCount[groupId]
                else { return }
            
            guard count == 1 else {
                self?.groupMemberCount[groupId] = count - 1
                return
            }
            
            self?.groupMemberCount[groupId] = nil
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil, userInfo: [NSLocalizedDescriptionKey : [UploadManager.GroupUploadingDidFinishNotification.UserInfoKey: groupId]])
            }
        }
        uploadingQueue[sessionTask] = task
    }


}

extension UploadManager: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        myDebugPrint(task)
        myDebugPrint(bytesSent)
        myDebugPrint(totalBytesSent)
        myDebugPrint(totalBytesExpectedToSend)

        DispatchQueue.main.async {
            guard let uploadTask = self.uploadingQueue[task] else { return }
            uploadTask.progress.totalUnitCount = totalBytesExpectedToSend
            uploadTask.progress.completedUnitCount = totalBytesSent
            uploadTask.progressDelegate?.uploadTaskDidUpdateProgress(uploadTask)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        self.uploadingQueue[task] = nil
        self.taskCount -= 1
        self.uploadIfPossible()

        myDebugPrint(task)
        myDebugPrint(error)
    }
}

extension URLSession {

    func uploadTask(_ task: UploadTaskProtocol, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {

        let dataTask = URLSessionUploadTask.init()

        let previousQueue = OperationQueue.current ?? OperationQueue()

        if previousQueue.operationCount == 0
            && previousQueue.underlyingQueue == nil {
            previousQueue.underlyingQueue = DispatchQueue.global()
        }

        let delay = Int.random(in: 0...5)
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(delay)) {

            var data: Data?
            var response: URLResponse?
            var error: Error?

            defer {
                previousQueue.underlyingQueue?.async {
                    UploadManager.shared.urlSession(UploadManager.shared.urlSession, task: dataTask, didCompleteWithError: error)
                    DispatchQueue.main.async {
                        completionHandler(data, response, error)
                    }
                }
            }

            guard Int.random(in: 0...1) > 0 else {
                error = NSError(domain: "Mock Request Failed", code: -1, userInfo: nil)
                return
            }

            let queue = DispatchQueue.init(label: "mock_data_upload_queue")
            (1...100).forEach({ (value) in
                queue.sync {
                    Thread.sleep(forTimeInterval: 0.1)
                    previousQueue.underlyingQueue?.async {
                        UploadManager.shared.urlSession(UploadManager.shared.urlSession, task: dataTask, didSendBodyData: Int64(value), totalBytesSent: Int64(value), totalBytesExpectedToSend: 100)
                    }
                }
            })

            data = "Mock Request Succeeded".data(using: .utf8)
            response = URLResponse()
        }
        return dataTask
    }

}
