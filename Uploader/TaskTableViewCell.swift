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
    
    var order: Int = 0 {
        didSet {
            orderLabel.text = "任务 \(order)"
        }
    }
    
    var task: DownloadTask? {
        didSet {
            guard let task = task else { return }
            disposeBag = DisposeBag()
            updateViews(forTask: task)
            updateColorForTaskState(task.state)
            updateImage(forTask: task)

            task.observable?
                .subscribe(onNext: { [weak self] (info) in
                    self?.updateViews(forTask: info.task)
                    self?.updateColorForTaskState(info.state)
                }, onError: { [weak self] (error) in
                    self?.displayImage = nil
                }, onCompleted: { [weak self, unowned task] in
                    self?.updateImage(forTask: task)
                }).disposed(by: disposeBag)
        }
    }

    private func updateViews(forTask task: Task) {
        idLabel.text = task.id
        stateLabel.text = task.state.description
    }

    private func updateImage(forTask task: Task) {
        guard let task = task as? DownloadTask,
            let data = task.data,
            let image = UIImage(data: data) else {
                displayImage = nil
                return
        }
        displayImage = image
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
        case .fail:
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
