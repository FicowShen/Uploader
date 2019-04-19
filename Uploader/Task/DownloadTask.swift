import Foundation
import RxSwift

final class DownloadTask: Task {

    static var taskObservers = [URLSessionTask: PublishSubject<TaskProgress>]()

    private static var _dataSession: URLSession!
    private static var dataSession: URLSession {
        if _dataSession != nil { return _dataSession }
        _dataSession = loadURLSession()
        return _dataSession
    }

    private static func loadURLSession() -> URLSession {
        let config = URLSessionConfiguration()
        let delegate = SessionDataDelegate()
        let queue = OperationQueue.init()
        queue.maxConcurrentOperationCount = 3
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: queue)
        return session
    }

    override func work() -> Observable<TaskProgress> {
        let subject = PublishSubject<TaskProgress>()
        let downloadTask = DownloadTask.dataSession.downloadTask(with: request)
        downloadTask.resume()
        DownloadTask.taskObservers[downloadTask] = subject
        return subject.asObservable()
    }
}

class SessionDataDelegate: NSObject, URLSessionDataDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let observer = DownloadTask.taskObservers[downloadTask] else { return }
        observer.onNext((completedUnitCount: totalBytesWritten, totalUnitCount: totalBytesExpectedToWrite))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let observer = DownloadTask.taskObservers[task] else { return }
        defer { DownloadTask.taskObservers[task] = nil }
        if let error = error {
            observer.onError(error)
        } else {
            observer.onCompleted()
        }
    }

}
