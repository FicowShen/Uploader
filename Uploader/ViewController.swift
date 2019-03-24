import UIKit

enum Scene: String {
    case normalUpload = "Normal Upload Scene"
    case groupUpload1 = "Group Upload Scene 1"
    case groupUpload2 = "Group Upload Scene 2"
}

class ViewController: UIViewController {

    @IBOutlet var tasksButton: [UIButton]!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(groupUploadDidFinish(_:)), name: UploadManager.GroupUploadingDidFinishNotification.Name, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @IBAction func buttonTapped(_ sender: UIButton) {

        guard let scene = Scene.init(rawValue: sender.currentTitle ?? "") else { fatalError() }
        let vc = TaskTableViewController.init(scene: scene)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    private func groupUploadDidFinish(_ notification: Notification){
        print(notification)
    }

}

