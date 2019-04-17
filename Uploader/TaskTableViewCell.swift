import UIKit
import RxSwift

class TaskTableViewCell: UITableViewCell {

    static let ID = String(describing: TaskTableViewCell.self)
    static let Height: CGFloat = 86
    
    @IBOutlet weak var orderLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var stateLabel: UILabel!

    var disposeBag: DisposeBag!
    
    var order: Int = 0 {
        didSet {
            orderLabel.text = "任务 \(order)"
        }
    }
    
    var task: Task? {
        didSet {
            guard let task = task else { return }
            disposeBag = DisposeBag()
            updateViews(forTask: task)
            updateColorForTaskState(task.state)
            task.observable?
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] (info) in
                    print(info.state)
                    self?.updateViews(forTask: info.task)
                    self?.updateColorForTaskState(info.state)
                    }, onError: { (error) in

                }, onCompleted: {

                }).disposed(by: disposeBag)
        }
    }

    private func updateViews(forTask task: Task) {
        idLabel.text = task.id
        stateLabel.text = task.state.description
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

    }
    
}
