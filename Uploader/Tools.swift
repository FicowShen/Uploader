import Foundation

var DefaultDateFormatter: DateFormatter = {
    let formatter = DateFormatter.init()
    formatter.dateFormat =  "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = NSTimeZone.system
    return formatter
}()

/// Debug输出
func DLog<T>(_ msg: T, file: String = #file, function: String = #function, line: Int = #line){
    #if DEBUG
        let file: String = (file as NSString).pathComponents.last ?? "UnknownFile"
        let time: String = DefaultDateFormatter.string(from: Date())
        let output: String =  "⚠️ \(time)\n<\(file)>\(function)[\(line)]:\n\(msg)"
        print(output)
    #endif
}
