import Foundation
import CMailCore

/**
 One IMAP connection of an MCOIMAPSession's pool, acquired for exclusive use via
 MCOIMAPSession.acquireConnection(folder:).

 While held, the session's regular per-operation connection selection skips this connection, so
 the only commands running on it are those explicitly pointed at it with
 MCOIMAPBaseOperation.setConnection(_:). Hand it back with
 MCOIMAPSession.releaseConnection(_:disconnect:) - a leaked lease permanently shrinks the pool.
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

    /** Number of operations queued on this connection. */
    public var operationsCount: UInt32 {
        return connection.operationsCount
    }
}
