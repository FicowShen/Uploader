import UIKit

final class TaskTableViewCell: UITableViewCell {

    static let ID = String(describing: TaskTableViewCell.self)
    
    @IBOutlet weak var orderLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!

    @IBOutlet weak var imageViewHeightConstrait: NSLayoutConstraint!

    private var displayImage: UIImage? {
        didSet {
            iconView.image = displayImage
            if displayImage == nil {
                indicatorView.startAnimating()
            } else {
                indicatorView.stopAnimating()
            }
        }
    }

    var order: Int = 0 {
        didSet {
            orderLabel.text = "Task \(order)"
        }
    }
    
    var task: Task? {
        didSet {
            guard let task = task else { return }
            task.delegate = self
            idLabel.text = task.id
            updateColorForTaskState(task.state.value)
            updateImage(forTask: task)
        }
    }

    private func updateImage(forTask task: Task) {
        switch task {
        case let t as DownloadTask:
            if let data = t.data {
                showImage(fromData: data)
            } else {
                displayImage = nil
            }
        case let t as UploadTask:
            switch task.state.value {
            case .success:
                showImage(fromData: t.data)
            default:
                displayImage = nil
            }
        case _ as MockTask:
            break
        default:
            return
        }
    }

    private func showImage(fromData data: Data) {
//        Observable.just(UIImage(data: data))
//            .subscribeOn(SerialDispatchQueueScheduler(qos: .userInitiated))
//            .asDriver(onErrorJustReturn: nil)
//            .drive(onNext: { [unowned self] (image) in
//                self.displayImage = image
//            })
//            .disposed(by: disposeBag)
    }
    
    private func updateColorForTaskState(_ state: TaskState) {
        stateLabel.text = state.description
        switch state {
        case .ready:
            progressView.isHidden = true
            stateLabel.textColor = .lightGray
        case .working(let progress):
            progressView.progress = Float(progress.completedUnitCount) / Float(progress.totalUnitCount)
            progressView.isHidden = false
            stateLabel.textColor = .brown
        case .success:
            progressView.isHidden = true
            stateLabel.textColor = .green
        case .failure:
            progressView.isHidden = true
            stateLabel.textColor = .red
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
    }

    override func updateConstraints() {
        defer { super.updateConstraints() }
        guard let _ = task as? MockTask else { return }
        imageViewHeightConstrait.constant = 0
        super.updateConstraints()
    }

}

extension TaskTableViewCell: TaskStateDelegate {
    func taskStateDidChange<Task>(_ task: Task) where Task : TaskProtocol {
        guard task === self.task else { return }
        updateColorForTaskState(task.state.value)
    }


}
