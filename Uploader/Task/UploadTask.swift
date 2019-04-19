import Foundation
import RxSwift

final class UploadTask: Task {
    override func work() -> Observable<TaskProgress> {
        let subject = PublishSubject<TaskProgress>()
        assertionFailure()
        return subject.asObservable()
    }
}
