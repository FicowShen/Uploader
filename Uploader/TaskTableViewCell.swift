import UIKit

class TaskTableViewCell: UITableViewCell {

    static let ID = String(describing: TaskTableViewCell.self)
    static let Height: CGFloat = 86
    
    @IBOutlet weak var orderLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var stateLabel: UILabel!
    
    var order: Int = 0 {
        didSet {
            orderLabel.text = "任务 \(order)"
        }
    }
    
    var task: UploadTask? {
        didSet {
            guard let task = task else { return }
            idLabel.text = task.id
            task.progressDelegate = self
            progressView.progress = Float(task.progress.fractionCompleted)
            stateLabel.text = task.state.description
            updateColorForTask(task)
        }
    }
    
    private func updateColorForTask(_ task: UploadTask) {

        switch task.state {
        case .ready:
            progressView.isHidden = true
            stateLabel.textColor = .lightGray
        case .uploading:
            progressView.isHidden = false
            stateLabel.textColor = .brown
        case .succeeded:
            progressView.isHidden = true
            stateLabel.textColor = .green
        case .failed:
            progressView.isHidden = true
            stateLabel.textColor = .red
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.task?.progressDelegate = nil
        self.task = nil
    }
    
}

extension TaskTableViewCell: UploadTaskProgressDelegate {
    func uploadTaskDidUpdateState(_ task: UploadTask) {
        
        idLabel.text = task.id
        stateLabel.text = task.state.description
        updateColorForTask(task)
    }
    
    func uploadTaskDidUpdateProgress(_ task: UploadTask) {
        
        idLabel.text = task.id
        progressView.progress = Float(task.progress.fractionCompleted)
    }
}
