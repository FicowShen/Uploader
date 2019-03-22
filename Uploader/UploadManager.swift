import Foundation


protocol UploadTaskProgressDelegate {
    func uploadTask(_ task: UploadTask, didUpdate progress: Progress)
}

protocol UploadTaskProtocol {
    var id: String { get }
    var timeStamp: TimeInterval { get }

    var progressDelegate: UploadTaskProgressDelegate? { get set }
}

func myDebugPrint(_ items: Any...) {
    print(items)
}

class UploadTask: Hashable, UploadTaskProtocol {

    static func == (lhs: UploadTask, rhs: UploadTask) -> Bool {
        return lhs.id == rhs.id
    }

    var hashValue: Int { return id.hashValue }

    let id: String
    let timeStamp: TimeInterval

    var progressDelegate: UploadTaskProgressDelegate?

    init(id: String = UUID().uuidString, timeStamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.timeStamp = timeStamp
    }
}

class UploadManager: NSObject {

    static let shared = UploadManager()

    var maxConcurrentTaskCount = 3

//    var uploadTasks: [UploadTask] {
//        var tasks = waitingQueue.values.reduce([UploadTask]()) { $0 + $1 }
//        uploadingQueue.values.forEach { tasks.append($0) }
//        return tasks
//    }

    private(set) var waitingQueue = [UploadTask]()
    private(set) var uploadingQueue = [URLSessionTask: UploadTask]()
    private(set) var finishedQueue = [UploadTask: (success: Bool, error: Error?)]()

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
        DispatchQueue.global().async {
            self.waitingQueue.append(task)
            self.uploadIfPossible()
        }
    }

    func addTasks(_ tasks: [UploadTask]) {
        DispatchQueue.global().async {
            tasks.forEach { self.waitingQueue.append($0) }
            self.uploadIfPossible()
        }
    }

    private func uploadIfPossible() {

        guard !waitingQueue.isEmpty,
            taskCount < maxConcurrentTaskCount
            else { return }

        let toUploadCount = maxConcurrentTaskCount - taskCount
        let toUploadTasks = [UploadTask](waitingQueue.prefix(toUploadCount))

        guard !toUploadTasks.isEmpty else { return }

        waitingQueue.removeFirst(min(waitingQueue.count, toUploadTasks.count))
        toUploadTasks.forEach { uploadTask($0) }
        taskCount += toUploadTasks.count

        if taskCount < maxConcurrentTaskCount {
            self.uploadIfPossible()
        }
    }

    private func uploadTask(_ task: UploadTask) {

        let sessionTask = urlSession.uploadTask(task) { [weak self] (data, response, error) in
            myDebugPrint(data, response, error)
            self?.finishedQueue[task] = (success: error == nil, error: error)
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

        DispatchQueue.global().async {
            guard let uploadTask = self.uploadingQueue[task] else { return }
            let progress = Progress()
            progress.totalUnitCount = totalBytesExpectedToSend
            progress.completedUnitCount = totalBytesSent
            DispatchQueue.main.async {
                uploadTask.progressDelegate?.uploadTask(uploadTask, didUpdate: progress)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        DispatchQueue.global().async {
            self.uploadingQueue[task] = nil
            self.taskCount -= 1
            self.uploadIfPossible()
        }

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
                    completionHandler(data, response, error)
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
