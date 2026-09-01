import Foundation
import CMailCore

public class MCOIMAPBaseOperation : MCOOperation {
    
    public typealias MCOOperationProgressBlock = (UInt32, UInt32) -> Void
    public typealias MCOOperationItemProgressBlock = (UInt32) -> Void
    
    internal var baseOperation: CIMAPBaseOperation;
    public var session: MCOIMAPSession?
    
    internal init(baseOperation: CIMAPBaseOperation) {
        self.baseOperation = baseOperation
        self.baseOperation.retain()
        super.init(baseOperation.cOperation)
        self.baseOperation.cOperation = super.nativeInstance
        self.baseOperation = self.baseOperation.setProgressBlocks(itemProgressCallback,
                                                                  bodyProgressCallback,
                                                                  Unmanaged.passUnretained(self).toOpaque())
    }
    
    deinit {
        baseOperation.release()
    }
    
    internal func error() -> ErrorCode {
        return baseOperation.error()
    }

    /**
     Aborts this operation's IMAP command if it is the one currently running on its connection: the
     blocked read returns at once instead of waiting out the socket timeout, so whatever is queued
     behind it - a disconnect, above all - runs immediately. Does nothing when this operation is not
     the one running.

     Unlike cancel(), which only raises a flag mailcore checks before starting an operation, this
     reaches the command already in flight. It costs the connection: the stream stays cancelled and
     is rebuilt on next use, so call it for a command being abandoned, never to hurry up one whose
     result still matters.

     - Returns: whether a command was actually interrupted, i.e. whether this operation was the one
     running. `false` means nothing was holding the connection on its behalf.
     */
    @discardableResult
    public func interruptCurrentCommand() -> Bool {
        return mailCoreAutoreleasePool {
            baseOperation.interruptCurrentCommand()
        }
    }
    
    public func itemProgress(current: UInt32, maximum: UInt32) {
        
    }
    
    public func bodyProgress(current: UInt32, maximum: UInt32) {
    
    }
}

//MARK: C Functions
public func itemProgressCallback(ref: UnsafeRawPointer?, current: UInt32, maximum: UInt32) {
    let selfRef = Unmanaged<MCOIMAPBaseOperation>.fromOpaque(ref!).takeUnretainedValue()
    selfRef.itemProgress(current: current, maximum: maximum)
}

public func bodyProgressCallback(ref: UnsafeRawPointer?, current: UInt32, maximum: UInt32) {
    let selfRef = Unmanaged<MCOIMAPBaseOperation>.fromOpaque(ref!).takeUnretainedValue()
    selfRef.bodyProgress(current: current, maximum: maximum)
}

