import Foundation
import RxSwift

final class UploadTask: Task {

    let request: URLRequest

    init(request: URLRequest) {
        self.request = request
    }
    
    override func work() -> Observable<TaskProgress> {
        let subject = PublishSubject<TaskProgress>()
        assertionFailure()
        return subject.asObservable()
    }
}
