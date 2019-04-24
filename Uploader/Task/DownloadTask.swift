import Foundation
import RxSwift
import Alamofire
import RxAlamofire

final class DownloadTask: Task {

    let request: URLRequest
    private var bag: DisposeBag?

    init(request: URLRequest) {
        self.request = request
    }

    override func work() -> Observable<TaskProgress> {
        let subject = PublishSubject<TaskProgress>()
        let observer = subject.asObserver()
        let bag = DisposeBag()
        self.bag = bag

        SessionManager.default.rx
            .request(urlRequest: self.request)
            .validate(statusCode: 200 ..< 300)
            .flatMap { (request) -> Observable<RxProgress> in
                return request.rx.progress()
            }
            .observeOn(MainScheduler.instance)
            .subscribe { [weak self] (event) in
                switch event {
                case .next(let element):
                    let taskProgress = (completedUnitCount: element.bytesWritten, totalUnitCount: element.totalBytes)
                    observer.onNext(taskProgress)
                case .error(let error):
                    observer.onError(error)
                    self?.bag = nil
                case .completed:
                    observer.onCompleted()
                    self?.bag = nil
                }
            }.disposed(by: bag)

        return subject.asObservable()
    }
}
