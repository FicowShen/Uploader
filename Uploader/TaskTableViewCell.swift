import UIKit
import RxSwift

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

    var disposeBag: DisposeBag!

    var order: Int = 0 {
        didSet {
            orderLabel.text = "Task \(order)"
        }
    }
    
    var task: Task? {
        didSet {
            guard let task = task else { return }
            idLabel.text = task.id
            disposeBag = DisposeBag()
            updateColorForTaskState(task.state)
            updateImage(forTask: task)

            task.observable?
                .subscribe(onNext: { [unowned self] (state) in
                    self.updateColorForTaskState(state)
                }, onError: { [unowned self] (error) in
                    self.displayImage = nil
                }, onCompleted: { [unowned self, unowned task] in
                    self.updateImage(forTask: task)
                })
                .disposed(by: disposeBag)
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
            if let _ = task.observable {
                displayImage = nil
            } else {
                showImage(fromData: t.data)
            }
        case _ as MockTask:
            break
        default:
            return
        }
    }

    private func showImage(fromData data: Data) {
        Observable.just(UIImage(data: data))
            .subscribeOn(SerialDispatchQueueScheduler(qos: .userInitiated))
            .asDriver(onErrorJustReturn: nil)
            .drive(onNext: { [unowned self] (image) in
                self.displayImage = image
            })
            .disposed(by: disposeBag)
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
        disposeBag = nil
        iconView.image = nil
    }

    override func updateConstraints() {
        defer { super.updateConstraints() }
        guard let _ = task as? MockTask else { return }
        imageViewHeightConstrait.constant = 0
        super.updateConstraints()
    }

}
