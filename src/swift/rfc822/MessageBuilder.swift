import Foundation
import CMailCore

public class MCOMessageBuilder : MCOAbstractMessage {
    
    private var nativeInstance: CMessageBuilder;
    
    public init() {
        self.nativeInstance = CMessageBuilder_init()
        super.init(mailCoreObject: self.nativeInstance.toCObject())
    }
    
    required public init(mailCoreObject: CObject) {
        self.nativeInstance = CMessageBuilder(cobject: mailCoreObject)
        self.nativeInstance.retain()
        super.init(mailCoreObject: mailCoreObject)
    }
    
    deinit {
        self.nativeInstance.release()
    }
    
    override func cast() -> CObject {
        return self.nativeInstance.toCObject()
    }
    
    /** Main HTML content of the message.*/
    public var htmlBody: String? {
        get {
            return mailCoreAutoreleasePool {
                nativeInstance.htmlBody.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.htmlBody = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** Plain text content of the message.*/
    public var textBody: String? {
        get {
            return mailCoreAutoreleasePool {
                nativeInstance.textBody.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.textBody = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** List of file attachments.*/
    public var attachments: Array<MCOAttachment>? {
        get {
            return mailCoreAutoreleasePool {
                Array<MCOAttachment>(mailCoreArray: nativeInstance.attachments);
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.attachments = newValue?.mailCoreArray() ?? CArray()
            }
        }
    }
    
    /** List of related file attachments (included as cid: link in the HTML part).*/
    public var relatedAttachments: Array<MCOAttachment>? {
        get {
            return mailCoreAutoreleasePool {
                Array<MCOAttachment>(mailCoreArray: nativeInstance.relatedAttachments)
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.relatedAttachments = newValue?.mailCoreArray() ?? CArray()
            }
        }
    }
    
    /** Prefix for the boundary identifier. Default value is nil.*/
    public var boundaryPrefix: String? {
        get {
            return mailCoreAutoreleasePool {
                nativeInstance.boundaryPrefix.string()
            }
        }
        set {
            mailCoreAutoreleasePool {
                nativeInstance.boundaryPrefix = newValue?.mailCoreString() ?? MailCoreString()
            }
        }
    }
    
    /** Add an attachment.*/
    public func addAttachment(attachment: MCOAttachment) {
        mailCoreAutoreleasePool {
            nativeInstance.addAttachment(attachment.nativeInstance);
        }
    }
    
    /** Add a related attachment.*/
    public func addRelatedAttachment(attachment: MCOAttachment) {
        mailCoreAutoreleasePool {
            nativeInstance.addRelatedAttachment(attachment.nativeInstance);
        }
    }
    
    /** RFC 822 formatted message.*/
    public func data() -> Data? {
        return mailCoreAutoreleasePool {
            return Data(cdata: nativeInstance.data());
        }
    }
    
    /** RFC 822 formatted message for encryption.*/
    public func dataForEncryption() -> Data? {
        return mailCoreAutoreleasePool {
            return Data(cdata: nativeInstance.dataForEncryption());
        }
    }
    
    /** Store RFC 822 formatted message to file. */
    public func writeToFile(filename: String, useXAttachmentId: Bool = false) throws -> Bool {
        return try mailCoreAutoreleasePool {
            let code = nativeInstance.writeToFile(filename.mailCoreString(), useXAttachmentId)
            if code != ErrorNone {
                throw MailCoreError.error(code: code);
            }
            return true
        }
    }
    
    /**
     Returns an OpenPGP signed message with a given signature.
     The signature needs to be computed on the data returned by -dataForEncryption
     before calling this method.
     You could use http://www.netpgp.com to generate it.
     */
    public func openPGPSignedMessageDataWithSignatureData(signature: Data) -> Data? {
        return mailCoreAutoreleasePool {
            return Data(cdata: nativeInstance.openPGPSignedMessageDataWithSignatureData(signature.mailCoreData()))
        }
    }
    
    /**
     Returns an OpenPGP encrypted message with a given encrypted data.
     The encrypted data needs to be computed before calling this method.
     You could use http://www.netpgp.com to generate it.
     */
    public func openPGPEncryptedMessageDataWithEncryptedData(encryptedData: Data) -> Data? {
        return mailCoreAutoreleasePool {
            return Data(cdata: nativeInstance.openPGPEncryptedMessageDataWithEncryptedData(encryptedData.mailCoreData()))
        }
    }
    
    /** HTML rendering of the message to be displayed in a web view. The delegate can be nil.*/
    //- (NSString *) htmlRenderingWithDelegate:(id <MCOHTMLRendererDelegate>)delegate;
    
    /** HTML rendering of the body of the message to be displayed in a web view.*/
    public func htmlBodyRendering() -> String? {
        return mailCoreAutoreleasePool {
            return nativeInstance.htmlBodyRendering().string()
        }
    }
    
    /** Text rendering of the message.*/
    public func plainTextRendering() -> String? {
        return mailCoreAutoreleasePool {
            return nativeInstance.plainTextRendering().string()
        }
    }
    
    /** Text rendering of the body of the message. All end of line will be removed and white spaces cleaned up.
     This method can be used to generate the summary of the message.*/
    public func plainTextBodyRendering() -> String? {
        return mailCoreAutoreleasePool {
            return nativeInstance.plainTextBodyRenderingAndStripWhitespace(true).string()
        }
    }
    
    /** Text rendering of the body of the message. All end of line will be removed and white spaces cleaned up if requested.
     This method can be used to generate the summary of the message.*/
    public func plainTextBodyRenderingAndStripWhitespace(stripWhitespace: Bool) -> String? {
        return mailCoreAutoreleasePool {
            return nativeInstance.plainTextBodyRenderingAndStripWhitespace(stripWhitespace).string()
        }
    }
    
    /** Method for testing purpose **/
    internal func setBoundaries(_ boundaries: [String]) {
        mailCoreAutoreleasePool {
            nativeInstance.setBoundaries(boundaries.mailCoreArray())
        }
    }

}
