import Foundation

extension NSError {
    static func makeError(message: String, domain: String = "com.ficow.uploader") -> NSError {
        return NSError(domain: domain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
