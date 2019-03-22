import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var label: UILabel! {
        didSet {
            defaultLabelText = label.text ?? ""
        }
    }
    @IBOutlet var tasksButton: [UIButton]!

    @IBOutlet weak var progressView: UIProgressView! {
        didSet {
            progressView.progress = 0
        }
    }

    private var defaultLabelText = ""

    var currentTasks = [UploadTask]()
    

    @IBAction func buttonTapped(_ sender: UIButton) {

        guard let index = tasksButton.firstIndex(of: sender) else { return }
        switch index {
        case 0:
            progressView.progress = 0
            let task = UploadTask()
            task.progressDelegate = self
            currentTasks = [task]
            UploadManager.shared.addTask(task)
            label.text = "Running Single Task"
        case 1:
            let tasks = [UploadTask].init(repeating: UploadTask(), count: 3)
            tasks.forEach { $0.progressDelegate = self }
            currentTasks = tasks
            UploadManager.shared.addTasks(tasks)
            label.text = "Running Multiple Tasks"
        case 2:
            label.text = defaultLabelText
        default:
            label.text = defaultLabelText
        }
    }

}

extension ViewController: UploadTaskProgressDelegate {
    func uploadTask(_ task: UploadTask, didUpdate progress: Progress) {
        print("task: \(task), progress: \(progress)")
        guard currentTasks.count == 1 else { return }
        progressView.progress = Float(progress.completedUnitCount) / Float(progress.totalUnitCount)
    }
}

