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

    /// The session this lease came from, held so it cannot be destroyed first: the C++ connection
    /// keeps a raw pointer back to its owner and reaches through it on every operation, so an
    /// outlived session is a use-after-free rather than a nil check.
    private let session: MCOIMAPSession

    /// The reservation this handle was made for. A connection released and acquired again is a
    /// different lease on the same object, and the session refuses a release carrying this value
    /// once that has happened — otherwise a duplicated cleanup path (a defer plus an explicit
    /// release, an error path plus a normal one) would cancel the next holder's lease and tear
    /// down the socket underneath it.
    internal let leaseGeneration: UInt32

    internal init(connection: CIMAPAsyncConnection, session: MCOIMAPSession) {
        self.connection = connection
        self.session = session
        self.leaseGeneration = connection.leaseGeneration
        self.connection.retain()
    }

    /// Returns the lease if its holder never did. A leaked lease is permanent otherwise — nothing
    /// in the pool clears a reservation on its own — and the connection would be lost to the pool
    /// for the life of the session. Torn down rather than pooled: a holder that lost track of its
    /// lease cannot have left the connection in a state anybody should inherit. Best effort:
    /// deinit runs on whatever thread drops the last reference, outside the serialisation the
    /// release contract asks for; a holder that releases explicitly never gets here.
    deinit {
        session.releaseConnection(self, disconnect: true)
        connection.release()
    }

    internal var isReserved: Bool {
        return connection.isReserved
    }

    /**
     Stable identity of the underlying pool connection, constant for the lifetime of the owning
     MCOIMAPSession (its pool is never pruned): two handles from separate acquisitions compare
     equal here when they lease the same connection.
     */
    public var identity: UInt {
        return UInt(bitPattern: connection.instance)
    }

    internal var operationsCount: UInt32 {
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
