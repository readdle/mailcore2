import Foundation
import CMailCore

public class MCOIMAPIdentity: Convertible {
    
    internal var nativeInstance:CIMAPIdentity;
    
    public init(vendor: String, name: String, version: String) {
        self.nativeInstance = CIMAPIdentity_init()
    }
    
    func cast() -> CObject {
        return self.nativeInstance.toCObject()
    }
    
    required public init(mailCoreObject: CObject) {
        self.nativeInstance = CIMAPIdentity.init(cobject: mailCoreObject)
        self.nativeInstance.retain()
    }
    
    deinit {
        self.nativeInstance.release()
    }
    
    /** Vendor of the IMAP client */
    public var vendor: String? {
        get {
            return mailCoreAutoreleasePool {
                nativeInstance.vendor.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.vendor = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** Name of the IMAP client */
    public var name: String? {
        get {
            return mailCoreAutoreleasePool {
                nativeInstance.name.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.name = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** Version of the IMAP client */
    public var version: String? {
        get {
            return mailCoreAutoreleasePool {
                nativeInstance.version.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.version = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** All fields names of the identity of the client */
    public func allInfoKeys() -> [String]? {
        return mailCoreAutoreleasePool {
            return Array<String>(mailCoreArray: nativeInstance.allInfoKeys())
        }
    }
    
    /** Retrieve a custom field in the identity */
    public func infoForKey(_ key: String) -> String? {
        return mailCoreAutoreleasePool {
            return nativeInstance.infoForKey(key.mailCoreString()).string()
        }
    }

    /** Set a custom field in the identity */
    public func setInfo(_ value: String, forKey key: String) {
        mailCoreAutoreleasePool {
            nativeInstance.setInfoForKey(key.mailCoreString(), value.mailCoreString())
        }
    }
    
    /** Remove all info keys including vendor, name and version */
    public func removeAllInfos() {
        mailCoreAutoreleasePool {
            nativeInstance.removeAllInfos()
        }
    }
    
}
