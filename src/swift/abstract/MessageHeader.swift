import Foundation


public class MCOMessageHeader: Convertible, NSCoding {
    
    var nativeInstance:CMessageHeader
    
    required public init(mailCoreObject obj: CObject) {
        self.nativeInstance = CMessageHeader.init(cobject: obj)
        self.nativeInstance.retain()
    }
    
    internal func cast() -> CObject {
        return nativeInstance.toCObject();
    }
    
    public init(data:Data) {
        self.nativeInstance = CMessageHeader_init();
        self.importHeadersData(data: data);
    }
    
    deinit {
        nativeInstance.release()
    }
    
    /** Message-ID field.*/
    public var messageID : String? {
        set { self.nativeInstance.messageID = newValue?.mailCoreString() ?? MailCoreString() }
        get { return self.nativeInstance.messageID.string() }
    }
    
    /** Message-ID auto-generated flag.*/
    public var isMessageIDAutoGenerated : Bool {
        get { return self.nativeInstance.isMessageIDAutoGenerated() }
    }
    
    /** References field. It's an array of message-ids.*/
    public var references : Array<String>? {
        get { return Array<String>(mailCoreArray: self.nativeInstance.references) }
        set { self.nativeInstance.references = newValue?.mailCoreArray() ?? CArray() }
    }
    
    /** In-Reply-To field. It's an array of message-ids.*/
    public var inReplyTo : Array<String>? {
        set { self.nativeInstance.inReplyTo = newValue?.mailCoreArray() ?? CArray() }
        get { return Array<String>(mailCoreArray: self.nativeInstance.inReplyTo) }
    }
    
    /** To field: recipient of the message. It's an array of MCOAddress.*/
    public var to: Array<MCOAddress>? {
        set { self.nativeInstance.to = newValue?.mailCoreArray() ?? CArray() }
        get { return Array<MCOAddress>(mailCoreArray: self.nativeInstance.to) }
    }
    
    /** Cc field: cc recipient of the message. It's an array of MCOAddress.*/
    public var cc: Array<MCOAddress>? {
        set { self.nativeInstance.cc = newValue?.mailCoreArray() ?? CArray() }
        get { return Array<MCOAddress>(mailCoreArray: self.nativeInstance.cc) }
    }
    
    /** Bcc field: bcc recipient of the message. It's an array of MCOAddress.*/
    public var bcc: Array<MCOAddress>? {
        set { self.nativeInstance.bcc = newValue?.mailCoreArray() ?? CArray() }
        get { return Array<MCOAddress>(mailCoreArray: self.nativeInstance.bcc) }
    }
    
    /** Reply-To field. It's an array of MCOAddress.*/
    public var replyTo: Array<MCOAddress>? {
        set { self.nativeInstance.replyTo = newValue?.mailCoreArray() ?? CArray() }
        get { return Array<MCOAddress>(mailCoreArray: self.nativeInstance.replyTo) }
    }
    
    /** Subject of the message.*/
    public var subject: String? {
        set { self.nativeInstance.subject = newValue?.mailCoreString() ?? MailCoreString() }
        get { return self.nativeInstance.subject.string() }
    }
    
    /** Email user agent name: X-Mailer header.*/
    public var userAgent: String? {
        set { self.nativeInstance.userAgent = newValue?.mailCoreString() ?? MailCoreString() }
        get { return self.nativeInstance.userAgent.string() }
    }
    
    public var receivedDate: Date {
        set { self.nativeInstance.receivedDate = time_t(newValue.timeIntervalSince1970) }
        get { return Date.init(timeIntervalSince1970: TimeInterval(self.nativeInstance.receivedDate))}
    }
    
    public var date: Date {
        set { self.nativeInstance.date = time_t(newValue.timeIntervalSince1970) }
        get { return Date.init(timeIntervalSince1970: TimeInterval(self.nativeInstance.date))}
    }
    
    public var sender: MCOAddress? {
        set { self.nativeInstance.sender = newValue?.nativeInstance ?? CAddress() }
        get { return createMCOObject(from: self.nativeInstance.sender.toCObject())}
    }
    
    public var from: MCOAddress? {
        set { self.nativeInstance.from = newValue?.nativeInstance ?? CAddress() }
        get {
            let address = self.nativeInstance.from
            let obj = address.toCObject()
            return createMCOObject(from: obj)
        }
    }
    
    /** Adds a custom header.*/
    public func setExtraHeaderValue(_ value: String, forName name: String) {
        nativeInstance.setExtraHeader(name.mailCoreString(), value.mailCoreString())
    }
    
    /** Remove a given custom header.*/
    public func removeExtraHeaderForName(name: String) {
        nativeInstance.removeExtraHeader(name.mailCoreString())
    }
    
    /** Returns the value of a given custom header.*/
    public func extraHeaderValue(forName: String) -> String? {
        return nativeInstance.extraHeaderValueForName(forName.mailCoreString()).string()
    }
    
    /** Returns an array with the names of all custom headers.*/
    public func allExtraHeadersNames() -> Array<String>? {
        return Array<String>(mailCoreArray: nativeInstance.allExtraHeadersNames());
    }
    
    /** Extracted subject (also remove square brackets).*/
    public func extractedSubject() -> String? {
        return nativeInstance.extractedSubject().string()
    }
    
    /** Extracted subject (don't remove square brackets).*/
    public func partialExtractedSubject() -> String? {
        return nativeInstance.partialExtractedSubject().string()
    }
    
    /** Fill the header using the given RFC 822 data.*/
    public func importHeadersData(data: Data) {
        nativeInstance.importHeadersData(data.mailCoreData())
    }
    
    /** Returns a header that can be used as a base for a reply message.*/
    public func replyHeaderWithExcludedRecipients(excludedRecipients: Array<MCOAddress>) -> MCOMessageHeader? {
        return createMCOObject(from: nativeInstance.replyHeaderWithExcludedRecipients(excludedRecipients.mailCoreArray()).toCObject())
    }
    
    /** Returns a header that can be used as a base for a reply all message.*/
    public func replyAllHeaderWithExcludedRecipients(excludedRecipients: Array<MCOAddress>) -> MCOMessageHeader? {
        return createMCOObject(from: nativeInstance.replyAllHeaderWithExcludedRecipients(excludedRecipients.mailCoreArray()).toCObject())
    }
    
    /** Returns a header that can be used as a base for a forward message.*/
    public func forwardHeader() -> MCOMessageHeader? {
        return createMCOObject(from: nativeInstance.forwardHeader().toCObject())
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        guard let dict = aDecoder.decodeObject(forKey: "info") as? Dictionary<AnyHashable, Any> else {
            return nil
        }
        let serializable = dictionaryUnsafeCast(dict)
        self.init(mailCoreObject: CObject.objectWithSerializable(serializable))
        self.nativeInstance.retain()
    }
    
    public func encode(with aCoder: NSCoder) {
        let serialazable: CDictionary = self.cast().serializable()
        let dict = dictionaryUnsafeCast(serialazable)
        aCoder.encode(dict, forKey: "info")
    }
    
}
