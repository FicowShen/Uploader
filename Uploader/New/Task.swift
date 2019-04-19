import Foundation
import RxSwift

typealias TaskProgress = (completedUnitCount: Int64, totalUnitCount: Int64)
typealias TaskStateInfo = (task: Task, state: TaskState)

enum TaskState {
    case ready
    case working(_ progress: TaskProgress)
    case success
    case fail(_ error: Error)

    var description: String {
        switch self {
        case .ready:
            return "ready"
        case .working:
            return "working"
        case .success:
            return "success"
        case .fail:
            return "fail"
        }
    }
}

protocol TaskProtocol: Hashable {
    var id: String { get }
    var timeStamp: TimeInterval { get }
    var request: URLRequest { get }
    var state: TaskState { get set }
    var observable: Observable<TaskStateInfo>? { get set }

    func work() -> Observable<TaskProgress>
}

class Task: TaskProtocol {
    static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }

    let id = UUID().uuidString
    let timeStamp: TimeInterval = Date().timeIntervalSince1970
    let request: URLRequest
    var state: TaskState = .ready
    var observable: Observable<TaskStateInfo>?

    init(request: URLRequest) {
        self.request = request
    }

    func work() -> Observable<TaskProgress> {
        return mockWork()
    }
}

extension Collection where Self.Element: TaskProtocol {
    var groupObservable: Observable<(successCount: Int, failureCount: Int)> {
        let subject = PublishSubject<(successCount: Int, failureCount: Int)>()
        var disposables = [Disposable]()
        var successCount = 0
        var failureCount = 0
        func increaseAndCheckTaskCount(isSuccess: Bool) {
            if isSuccess {
                successCount += 1
            } else {
                failureCount += 1
            }
            guard (successCount + failureCount) == self.count else { return }
            subject.onNext((successCount, failureCount))
            subject.onCompleted()
            disposables.forEach { $0.dispose() }
        }
        self.forEach { (task) in
            guard let observable = task.observable else {
                // task has been finished
                switch task.state {
                case .success:
                    increaseAndCheckTaskCount(isSuccess: true)
                case .fail(_):
                    increaseAndCheckTaskCount(isSuccess: false)
                default:
                    break
                }
                return
            }
            let disposable = observable
                .subscribe({ (event) in
                    switch event {
                    case .next(let element):
                        switch element.state {
                        case .success:
                            increaseAndCheckTaskCount(isSuccess: true)
                        case .fail(_):
                            increaseAndCheckTaskCount(isSuccess: false)
                        default:
                            break
                        }
                    default:
                        break
                    }
                })
            disposables.append(disposable)
        }
        return subject.asObservable()
    }
}
