import Foundation
import RxSwift

enum MockImageURL: String {
    case size573kb = "https://pixabay.com/get/e036b60f2cfd1c3e955b4704e44b429fe76ae3d01cb5164094f7c771/fox-937049.jpg?attachment"
    case size2mb = "https://pixabay.com/get/ea36b70b2ef11c3e955b4704e44b429fe76ae3d01cb5164094f7c87a/fields-336465.jpg?attachment"
    case size6mb = "https://pixabay.com/get/ed35b40a21f6073ecd1f4407e74e4192ea73ffd41cb4154694f2c17fa7/apple-4055926.jpg?attachment"
    case size10mb = "https://pixabay.com/get/eb35b5072ff0033ecd1f4407e74e4192ea73ffd41cb4154694f1c97fa5/forest-2048742.jpg?attachment"
}

func mockWork() -> Observable<TaskProgress> {
    let subject = PublishSubject<TaskProgress>()
    DispatchQueue.global().async {
        let observer = subject.asObserver()
        let tryToFail = Bool.random()
        let failNow = { Int.random(in: 0...10) < 3 }
        for i in 0...100 {
            Thread.sleep(forTimeInterval: TimeInterval(Int.random(in: 1...10)) * 0.01)
            let taskProgress = (completedUnitCount: Int64(i), totalUnitCount: Int64(100))
            observer.onNext(taskProgress)
            if tryToFail && failNow() {
                observer.onError(NSError.makeError(message: "upload failed"))
                return
            }
        }
        observer.onCompleted()
    }
    return subject.asObservable()
}

final class MockTask: Task {
    override func work() -> Observable<TaskProgress> {
        return mockWork()
    }
}
