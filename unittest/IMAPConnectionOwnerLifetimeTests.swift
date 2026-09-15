//
//  IMAPConnectionOwnerLifetimeTests.swift
//  mailcore2
//
//  A pooled connection must not outlive its IMAPAsyncSession while it still has work: the
//  connection reaches its owner through a raw pointer on every queue start and stop.
//

#if canImport(Darwin)

import Darwin
import Dispatch
import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class IMAPConnectionOwnerLifetimeTests: XCTestCase {

    private func makeSession() -> MCOIMAPSession {
        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = 1 // never connected: a disconnect on a fresh connection is a no-op
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.maximumConnections = 1
        return session
    }

    private func runOffMainThread(timeout: TimeInterval, _ body: @escaping () -> Void) {
        let finished = expectation(description: "test body")
        DispatchQueue.global(qos: .userInitiated).async {
            body()
            finished.fulfill()
        }
        waitForExpectations(timeout: timeout)
    }

    private func start(_ operation: MCOIMAPOperation) -> DispatchSemaphore {
        let finished = DispatchSemaphore(value: 0)
        operation.start { _ in
            finished.signal()
        }
        return finished
    }

    /// A connection-scoped disconnect is the one operation that does not retain the session it
    /// belongs to. Queue one, let every other reference to the session go, wait for the
    /// connection's queue thread to stop - its stop releases the session's last retain - and then
    /// start the queued operation: the queue restarts and reports to an owner that no longer exists.
    func testQueuedDisconnectKeepsTheOwnerAlive() {
        var session: MCOIMAPSession? = makeSession()
        var handle = session!.acquireConnection(folder: nil)
        XCTAssertNotNil(handle)

        // Retains the connection (through the operation), not the session.
        let later = handle!.disconnectOperation()

        runOffMainThread(timeout: 30) {
            // Wakes the connection's queue thread; when it stops it releases its retain of the
            // session, which is the last one once the Swift wrappers below are gone.
            XCTAssertEqual(self.start(handle!.disconnectOperation()).wait(timeout: .now() + 5), .success)

            session!.releaseConnection(handle!, disconnect: false)

            // The queue thread lingers for about a second after its last operation and releases
            // its retain of the session when it stops; only then are the wrappers below the last
            // holders.
            let deadline = Date(timeIntervalSinceNow: 10)
            while session!.isOperationQueueRunning && Date() < deadline {
                usleep(20_000)
            }
            XCTAssertFalse(session!.isOperationQueueRunning, "the connection's queue was expected to stop")
            handle = nil
            // The dropped handle returns its lease on the session's queue (the main queue here)
            // and holds the session until then; let that run before the session is dropped.
            DispatchQueue.main.sync {}
            session = nil

            XCTAssertEqual(self.start(later).wait(timeout: .now() + 5), .success,
                           "The queued disconnect must still run once the pool has been dropped")
        }
    }
}

#endif
