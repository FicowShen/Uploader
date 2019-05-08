import UIKit
import RxSwift

class TaskTableViewCell: UITableViewCell {

    static let ID = String(describing: TaskTableViewCell.self)
    
    @IBOutlet weak var orderLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!

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

    var scene: Scene? {
        didSet {
            guard let scene = scene, scene == .normalTask else { return }
            iconView.superview?.isHidden = true
            iconView.isHidden = true
            indicatorView.stopAnimating()
        }
    }

    var order: Int = 0 {
        didSet {
            orderLabel.text = "任务 \(order)"
        }
    }
    
    var task: Task? {
        didSet {
            guard let task = task else { return }
            disposeBag = DisposeBag()
            updateLabels(forTask: task)
            updateColorForTaskState(task.state)
            updateImage(forTask: task)

            task.observable?
                .subscribe(onNext: { [unowned self] (info) in
                    self.updateLabels(forTask: info.task)
                    self.updateColorForTaskState(info.state)
                }, onError: { [unowned self] (error) in
                    self.displayImage = nil
                }, onCompleted: { [unowned self, unowned task] in
                    self.updateImage(forTask: task)
                }).disposed(by: disposeBag)
        }
    }

    private func updateLabels(forTask task: Task) {
        idLabel.text = task.id
        stateLabel.text = task.state.description
    }

    private func updateImage(forTask task: Task) {
        switch task {
        case let t as DownloadTask:
            if let data = t.data {
                displayImage = UIImage(data: data)
            } else {
                displayImage = nil
            }
        case let t as UploadTask:
            if let _ = task.observable {
                displayImage = nil
            } else {
                displayImage = UIImage(data: t.data)
            }
        case _ as MockTask:
            break
        default:
            return
        }
    }
    
    private func updateColorForTaskState(_ state: TaskState) {
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

}
