import Foundation

extension URLSession {

    func uploadTask(_ task: UploadTaskProtocol, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {

        let dataTask = URLSessionUploadTask.init()

        let delay = Int.random(in: 0...5)
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(delay)) {

            guard Int.random(in: 0...1) > 0 else {
                let error = NSError(domain: "Mock Request Failed", code: -1, userInfo: nil)
                UploadManager.shared.urlSession(UploadManager.shared.urlSession, task: dataTask, didCompleteWithError: error)
                DispatchQueue.main.async {
                    completionHandler(nil, nil, error)
                }
                return
            }

            let mockDataUploadQueue = DispatchQueue.init(label: "mock_data_upload_queue")
            (1...100).forEach({ (value) in
                mockDataUploadQueue.sync {
                    Thread.sleep(forTimeInterval: 0.05)
                    let currentValue = Int64(value)
                    UploadManager.shared.urlSession(UploadManager.shared.urlSession, task: dataTask, didSendBodyData: currentValue, totalBytesSent: currentValue, totalBytesExpectedToSend: 100)
                }
            })

            let data = "Mock Request Succeeded".data(using: .utf8)
            let response = URLResponse()
            UploadManager.shared.urlSession(UploadManager.shared.urlSession, task: dataTask, didCompleteWithError: nil)
            DispatchQueue.main.async {
                completionHandler(data, response, nil)
            }
        }
        return dataTask
    }

}
