//
//  TaskTableViewCell.swift
//  Uploader
//
//  Created by Ficow on 2019/3/24.
//  Copyright © 2019 fshen. All rights reserved.
//

import UIKit

class TaskTableViewCell: UITableViewCell {

    static let ID = "TaskTableViewCell"
    static let Height: CGFloat = 72
    
    @IBOutlet weak var orderLabel: UILabel!
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
            task.progressDelegate = self
            state = task.state.description
            updateColorForTask(task)
        }
    }
    
    private var state: String = "" {
        didSet {
            stateLabel.text = "状态：\(state)"
        }
    }
    
    private func updateColorForTask(_ task: UploadTask) {
        
        switch task.state {
        case .ready:
            progressView.isHidden = true
            stateLabel.textColor = .lightGray
        case .uploading:
            progressView.isHidden = false
            stateLabel.textColor = .darkGray
        case .succeeded:
            progressView.isHidden = true
            stateLabel.textColor = .green
        case .failed:
            progressView.isHidden = true
            stateLabel.textColor = .red
        }
    }
    
}

extension TaskTableViewCell: UploadTaskProgressDelegate {
    func uploadTaskDidUpdateState(_ task: UploadTask) {
        
        state = task.state.description
        updateColorForTask(task)
    }
    
    func uploadTaskDidUpdateProgress(_ task: UploadTask) {
//        print("task: \(task)")
        
        progressView.progress = Float(task.progress.completedUnitCount) / Float(task.progress.totalUnitCount)
        
    }
}
