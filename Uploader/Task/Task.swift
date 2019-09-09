import Foundation

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

protocol TaskStateDelegate: class {
    func taskStateDidChange<Task: TaskProtocol>(_ task: Task)
}

protocol TaskProtocol: class, Hashable {
    var id: String { get }
    var timeStamp: TimeInterval { get }
    var state: Atomic<TaskState> { get }
    var delegate: TaskStateDelegate? { get set }

    func start()
}

extension TaskProtocol {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }
}

class Task: TaskProtocol {
    let id = UUID().uuidString
    let timeStamp: TimeInterval = Date().timeIntervalSince1970
    let state: Atomic<TaskState> = Atomic(.ready)
    weak var delegate: TaskStateDelegate?

    func start() {
        fatalError("Implement your work in subclass.")
    }
}
