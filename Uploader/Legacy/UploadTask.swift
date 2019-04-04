import Foundation

protocol UploadTaskProgressDelegate: class {
    func uploadTaskDidUpdateState(_ task: UploadTask)
    func uploadTaskDidUpdateProgress(_ task: UploadTask)
}

//protocol UploadTaskProtocol {
//    var id: String { get }
//    var groupId: String? { get }
//    var timeStamp: TimeInterval { get }
//
//    var progressDelegate: UploadTaskProgressDelegate? { get set }
//}

class UploadTask: Hashable {

    enum State {
        case ready
        case uploading
        case succeeded
        case failed(Error)

        var description: String {
            switch self {
            case .ready:
                return "等待开始"
            case .uploading:
                return "进行中"
            case .succeeded:
                return "已成功"
            case .failed(let error):
                return "已失败, \(error)"
            }
        }
    }

    static func == (lhs: UploadTask, rhs: UploadTask) -> Bool {
        return lhs.id == rhs.id
    }

    var hashValue: Int { return id.hashValue }

    let id: String
    private(set) var groupId: String?
    let timeStamp: TimeInterval

    var state: State = .ready
    let progress = Progress()

    weak var progressDelegate: UploadTaskProgressDelegate?

    init(id: String = UUID().uuidString, groupId: String? = nil, timeStamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.groupId = groupId
        self.timeStamp = timeStamp
        progress.totalUnitCount = 1
        progress.completedUnitCount = 0
    }

    func removeGroupId() {
        self.groupId = nil
    }
}
