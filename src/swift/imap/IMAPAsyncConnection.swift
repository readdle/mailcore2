import Foundation
import CMailCore

/**
 One IMAP connection of an MCOIMAPSession's pool, acquired for exclusive use via
 MCOIMAPSession.acquireConnection(folder:).

 While held, the session's regular per-operation connection selection skips this connection, so
 the only commands running on it are those explicitly pointed at it with
 MCOIMAPBaseOperation.setConnection(_:). Hand it back with
 MCOIMAPSession.releaseConnection(_:disconnect:) - a leaked lease permanently degrades the
 pool: the connection is never handed out exclusively again and, at the limit, falls back to
 being shared.
 */
public class MCOIMAPAsyncConnection: NSObjectCompat {

    internal var connection: CIMAPAsyncConnection

    internal init(connection: CIMAPAsyncConnection) {
        self.connection = connection
        self.connection.retain()
    }

    deinit {
        connection.release()
    }

    /** Whether the connection is currently reserved by a lease. */
    public var isReserved: Bool {
        return connection.isReserved
    }

    /**
     Stable identity of the underlying pool connection, unique and constant for the lifetime of
     the owning MCOIMAPSession (its pool is never pruned). Two MCOIMAPAsyncConnection wrappers
     from separate acquisitions compare equal here when they lease the same connection — use it
     to key per-connection bookkeeping such as view-freshness generations.
     */
    public var identity: UInt {
        return UInt(bitPattern: connection.instance)
    }

    /** Number of operations queued on this connection. */
    public var operationsCount: UInt32 {
        return connection.operationsCount
    }

    /**
     Wall-clock moment of this connection's last successful LOGIN, nil when it has never logged
     in. On a server that pins the mailbox view per connection, this answers the only question
     that matters at the start of a lease: whether the view this connection holds was taken
     before or after some event of the caller's own. Logins the pool performs on its own - after
     its automatic disconnect, a dropped socket, an error retry - move it, so a caller stays
     correct without observing them.

     A disconnect does not move it: between the disconnect and the next login the value still
     reports the previous login, which reads as older than it is and so errs towards a caller
     refreshing a connection that needed no refresh, never the other way.

     Wall clock, so a comparison against a moment the caller recorded the same way is only as
     reliable as the clock: a step backwards between the login and the caller's own event can
     make the login look later than it was.
     */
    public var lastLoginDate: Date? {
        let value = connection.lastLoginTime
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    /**
     Returns an operation that disconnects this connection only: the object stays pooled (and
     leased, if it is), and the next command on it logs in from scratch. With a lease on a
     server that pins the mailbox view per connection, this is how the holder forces a view no
     older than itself — start it before the commands whose freshness matters.
     */
    public func disconnectOperation() -> MCOIMAPOperation {
        return mailCoreAutoreleasePool {
            return MCOIMAPOperation(operation: connection.disconnectOperation())
        }
    }
}
