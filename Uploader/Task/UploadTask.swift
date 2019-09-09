import Foundation

final class UploadTask: Task {

    let request: URLRequest
    let data: Data

    init(request: URLRequest, data: Data) {
        self.request = request
        self.data = data
    }
    
    override func start(scheduler: TaskStateObserver) {
    }
}
