import Foundation
import RxSwift
import Alamofire
import RxAlamofire

final class DownloadTask: Task {

    let request: URLRequest
    var data: Data?
    private var bag: DisposeBag?

    init(request: URLRequest) {
        self.request = request
    }

    override func start() -> Observable<TaskProgress> {
        let subject = PublishSubject<TaskProgress>()
        let observer = subject.asObserver()
        let bag = DisposeBag()
        self.bag = bag

        let observable = SessionManager.default.rx
            .request(urlRequest: self.request)
            .validate(statusCode: 200 ..< 300)

        observable
            .flatMap { $0.rx.progress() }
            .observeOn(MainScheduler.instance)
            .subscribe { [weak self] (event) in
                switch event {
                case .next(let progress):
                    guard progress.totalBytes != 0 else { return }
                    let taskProgress = (completedUnitCount: progress.bytesWritten, totalUnitCount: progress.totalBytes)
                    observer.onNext(taskProgress)
                case .error(let error):
                    observer.onError(error)
                case .completed:
                    break
                }
            }.disposed(by: bag)

        observable
            .flatMap { $0.rx.data() }
            .observeOn(MainScheduler.instance)
            .subscribe { [weak self] (event) in
                defer {
                    observer.onCompleted()
                    self?.bag = nil
                }
                guard let data = event.element else { return }
                self?.data = data
            }.disposed(by: bag)

        return subject.asObservable()
    }
}
