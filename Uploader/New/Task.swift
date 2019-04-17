import Foundation
import RxSwift

typealias TaskProgress = (completedUnitCount: Int64, totalUnitCount: Int64)
typealias TaskStateInfo = (task: Task, state: TaskState)

enum TaskState {
    case ready
    case working(progress: TaskProgress)
    case success
    case fail(error: Error)

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
