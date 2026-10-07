import Foundation
import CMailCore

public let MailCoreErrorDomain = "MailCoreErrorDomain"

// Swift-only features: Global variables defined in Swift
// Class for using from Objective-C [MailCoreErrors domain]
public class MailCoreErrors: NSObjectCompat {
    
    public class func domain() -> String {
        return MailCoreErrorDomain
    }
    
}

// This enum is not Error because Enum with raw type cannot have cases with arguments (e.g. userInfo)
@objc public enum MailCoreError : IntEnum {
    
    case errorNone // 0
    case errorConnection
    case errorTLSNotAvailable
    case errorParse
    case errorCertificate
    case errorAuthentication
    case errorGmailIMAPNotEnabled
    case errorGmailExceededBandwidthLimit
    case errorGmailTooManySimultaneousConnections
    case errorMobileMeMoved
    case errorYahooUnavailable // 10
    case errorNonExistantFolder
    case errorRename
    case errorDelete
    case errorCreate
    case errorSubscribe
    case errorAppend
    case errorCopy
    case errorExpunge
    case errorFetch
    case errorIdle // 20
    case errorIdentity
    case errorNamespace
    case errorStore
    case errorCapability
    case errorStartTLSNotAvailable
    case errorSendMessageIllegalAttachment
    case errorStorageLimit
    case errorSendMessageNotAllowed
    case errorNeedsConnectToWebmail
    case errorSendMessage // 30
    case errorAuthenticationRequired
    case errorFetchMessageList
    case errorDeleteMessage
    case errorInvalidAccount
    case errorFile
    case errorCompression
    case errorNoSender
    case errorNoRecipient
    case errorNoop
    case errorGmailApplicationSpecificPasswordRequired // 40
    case errorServerDate
    case errorNoValidServerFound
    case errorCustomCommand
    case errorYahooSendMessageSpamSuspected
    case errorYahooSendMessageDailyLimitExceeded
    case errorOutlookLoginViaWebBrowser
    case errorTiscaliSimplePassword
    case errorCanceled
    case errorIMAPTooManySimultaneousConnections
    
    internal static func error(code: ErrorCode, userInfo: [String: Any]? = nil) -> NSError {
        return NSError(domain: MailCoreErrorDomain, code: Int(code.rawValue), userInfo: userInfo)
    }

}
