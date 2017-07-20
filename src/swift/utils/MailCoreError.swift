import Foundation
import CCore

public class MailCoreError : Error {
    
    public var errorCode: UInt32;
    public var errorMessage: String;
    public var userInfo: Dictionary<String, Any>?
    
    internal init(code: ErrorCode) {
        self.errorCode = code.rawValue;
        //Add localization
        self.errorMessage = "";
    }
    
}
