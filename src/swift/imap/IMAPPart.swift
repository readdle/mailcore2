import Foundation
import CCore

public class IMAPPart : AbstractPart {
    
    private var nativeInstance:CIMAPPart;
    
    internal init(part:CIMAPPart) {
        self.nativeInstance = part;
        super.init(part.abstractPart);
    }
    
    required public init(_ obj: CObject) {
        let part = CIMAPPart(cobject: obj);
        self.nativeInstance = part;
        super.init(part.abstractPart);
    }
    
    /** A part identifier is of the form 1.2.1*/
    public var partID: String? {
        get { return String(utf16: nativeInstance.partID) }
        set { String.utf16(newValue, { nativeInstance.partID = $0 }) }
    }
    
    /** The size of the single part in bytes */
    public var size: UInt32 {
        get { return nativeInstance.size }
        set { nativeInstance.size = newValue }
    }
    
    /** It's the encoding of the single part */
    public var encoding: Encoding {
        get { return nativeInstance.encoding }
        set { nativeInstance.encoding = newValue }
    }
    
    /**
     Returns the decoded size of the part.
     For example, for a part that's encoded with base64, it will return actual_size * 3/4.
     */
    public func decodedSize() -> UInt32 {
        return nativeInstance.decodedSize();
    }
    
}