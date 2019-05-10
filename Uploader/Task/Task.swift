import Foundation
import RxSwift

typealias TaskProgress = (completedUnitCount: Int64, totalUnitCount: Int64)

enum TaskState {
    case ready
    case working(_ progress: TaskProgress)
    case success
    case failure(_ error: Error)

    var description: String {
        switch self {
        case .ready:
            return "ready"
        case .working:
            return "working"
        case .success:
            return "success"
        case .failure:
            return "failure"
        }
    }
}

protocol TaskProtocol: class, Hashable {
    var id: String { get }
    var timeStamp: TimeInterval { get }
    var state: TaskState { get set }
    var observable: Observable<TaskState>? { get set }

    func start() -> Observable<TaskProgress>
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
    var state: TaskState = .ready
    var observable: Observable<TaskState>?

    func start() -> Observable<TaskProgress> {
        fatalError("Implement your work in subclass.")
    }
}

extension Collection where Self.Element: TaskProtocol {
    var groupObservable: Observable<(successCount: Int, failureCount: Int)> {

        let subject = PublishSubject<(successCount: Int, failureCount: Int)>()
        var disposables = [Disposable]()
        var successCount = 0
        var failureCount = 0

        func count(forState state: TaskState) {
            switch state {
            case .success:
                successCount += 1
            case .failure(_):
                failureCount += 1
            default:
                break
            }
            guard (successCount + failureCount) == self.count else { return }
            subject.onNext((successCount, failureCount))
            subject.onCompleted()
        }

        self.forEach { (task) in
            guard let observable = task.observable else {
                // task has been finished
                count(forState: task.state)
                return
            }
            let disposable = observable
                .subscribe(onNext: { (state) in
                    count(forState: state)
                })
            disposables.append(disposable)
        }
        return subject.asObservable()
    }
}
