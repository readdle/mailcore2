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
     reaches the command already in flight. It costs the connection: a command in flight fails with
     a connection error, a cut that met none fails nothing, and either way the connection is rebuilt
     before the next operation's first command - so call it for a command being abandoned, never to
     hurry up one whose result still matters.

     - Returns: whether a command was actually cut, which needs this operation to be the one the
     queue is running and its connection to have a stream. One still opening its socket - DNS, the
     TCP connect, an implicit-TLS handshake - is running yet holds nothing breakable and answers
     `false`, and its command runs on to its timeout. A `true` may still cover a command that
     finished just as the interrupt landed: its result is intact, but the stream is cancelled all
     the same.
     */
    @discardableResult
    public func interruptCurrentCommand() -> Bool {
        return mailCoreAutoreleasePool {
            baseOperation.interruptCurrentCommand()
        }
    }

    /**
     Pins this operation to the given connection: start() runs it there instead of letting the
     session pick a connection. Set it before start(); pair with
     MCOIMAPSession.acquireConnection(folder:), which is what keeps other operations off that
     connection.
     */
    public func setConnection(_ connection: MCOIMAPAsyncConnection) {
        mailCoreAutoreleasePool {
            baseOperation.setSession(connection.connection)
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

