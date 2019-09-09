import Foundation

final class DownloadTask: Task {

    let request: URLRequest
    var data: Data?

    init(request: URLRequest) {
        self.request = request
    }

    override func start(scheduler: TaskStateObserver) {
    }
}
