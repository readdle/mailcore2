//
//  IMAPConnectionLeaseTests.swift
//  mailcore2
//
//  Tests for IMAPAsyncSession::acquireConnection() / releaseConnection() and for pinning an
//  operation to a leased connection.
//

// Darwin only: the tests need a POSIX listening socket, and the Android job builds the test target
// without running it. Nothing here is platform-specific beyond that socket.
#if canImport(Darwin)

import Darwin
import Dispatch
import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class IMAPConnectionLeaseTests: XCTestCase {

    /// Well above every wait below: a command left to its own devices must not be able to finish
    /// on its own before the test is done observing it.
    private let sessionTimeout: TimeInterval = 60

    private func makeSession(port: UInt16, maximumConnections: UInt32) -> MCOIMAPSession {
        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(port)
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.timeout = sessionTimeout
        session.maximumConnections = maximumConnections
        return session
    }

    /// Runs the test body off the main thread while the main thread keeps spinning its run loop.
    /// mailcore hands parts of an operation's lifecycle to the main queue and waits for them, so a
    /// test that blocks the main thread never gets its operation started in the first place.
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

    /// Enqueueing crosses a couple of threads, so occupancy is polled rather than asserted at one
    /// instant. The operation itself cannot finish - the endpoint is silent - so once the count
    /// reaches the expected value it stays there.
    private func waitForOperationsCount(of connection: MCOIMAPAsyncConnection,
                                        toReach expected: UInt32,
                                        timeout: TimeInterval = 5) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if connection.operationsCount >= expected {
                return true
            }
            usleep(20_000)
        }
        return connection.operationsCount >= expected
    }

    /// Acquiring needs no server at all: connections come to life on first use, so lease
    /// bookkeeping is observable without a single socket.
    func testAcquireReservesUntilReleaseAndExhaustionReturnsNil() {
        let session = makeSession(port: 1, maximumConnections: 2)

        guard let first = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 2 connections must satisfy the first lease")
        }
        XCTAssertTrue(first.isReserved)

        // Non-nil proves it is a different connection: acquiring the already-reserved one again
        // is exactly what acquireConnection() must refuse.
        guard let second = session.acquireConnection(folder: nil) else {
            return XCTFail("A pool with room for 2 connections must satisfy a second lease")
        }
        XCTAssertTrue(second.isReserved)

        XCTAssertNil(session.acquireConnection(folder: nil),
                     "With every connection reserved there is nothing left to hand out exclusively")

        session.releaseConnection(second, disconnect: false)
        XCTAssertFalse(second.isReserved, "Release must return the connection to the shared pool")

        XCTAssertNotNil(session.acquireConnection(folder: nil),
                        "A released connection must be acquirable again")
    }

    func testPinnedOperationRunsOnTheLeasedConnection() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 2 connections must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            operation.setConnection(leased)
            let finished = self.start(operation)

            XCTAssertTrue(self.waitForOperationsCount(of: leased, toReach: 1),
                          "A pinned operation must land on the leased connection")

            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The command was expected to be blocked on the silent socket")

            XCTAssertTrue(operation.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success,
                           "interruptCurrentCommand() did not unblock the pinned command")

            // After an interrupt the stream does not recover, so the lease comes back
            // with a disconnect.
            session.releaseConnection(leased, disconnect: true)
            XCTAssertFalse(leased.isReserved)
        }
    }

    func testUnpinnedOperationAvoidsTheLeasedConnection() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 2 connections must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            let finished = self.start(operation)

            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The command was expected to be blocked on the silent socket")

            XCTAssertEqual(leased.operationsCount, 0,
                           "While the pool has room, a regular operation must not touch the leased connection")

            XCTAssertTrue(operation.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)

            session.releaseConnection(leased, disconnect: false)
        }
    }

    /// The one case where exclusivity gives way: a fully reserved pool at its connection limit
    /// shares the least busy reserved connection with regular operations instead of crashing on
    /// a NULL session.
    func testExhaustedPoolSharesTheLeasedConnection() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            let finished = self.start(operation)

            XCTAssertTrue(self.waitForOperationsCount(of: leased, toReach: 1),
                          "With the whole pool reserved, a regular operation must share the leased connection")

            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The command was expected to be blocked on the silent socket")

            XCTAssertTrue(operation.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)

            session.releaseConnection(leased, disconnect: true)
        }
    }

    func testAcquirePrefersAnIdleConnectionOverABusyOne() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)

        runOffMainThread(timeout: 30) {
            // Occupy the first connection with a command stuck on the silent socket.
            let blocked = session.connectOperation()
            let blockedFinished = self.start(blocked)
            XCTAssertEqual(blockedFinished.wait(timeout: .now() + 2), .timedOut,
                           "The command was expected to be blocked on the silent socket")

            let leased = session.acquireConnection(folder: nil)
            if let leased = leased {
                XCTAssertEqual(leased.operationsCount, 0,
                               "With room in the pool, a lease must get an idle or new connection, not the busy one")
            }
            else {
                XCTFail("A pool with room for 2 connections must satisfy the lease")
            }

            XCTAssertTrue(blocked.interruptCurrentCommand())
            XCTAssertEqual(blockedFinished.wait(timeout: .now() + 10), .success)

            if let leased = leased {
                session.releaseConnection(leased, disconnect: false)
            }
        }
    }

    /// Also exercises the session -> connection plumbing of automaticDisconnectDelay: with the
    /// default 30s the timer could not fire inside the observation windows at all.
    func testAutomaticDisconnectStandsDownWhileReservedAndReleaseRearmsIt() throws {
        let endpoint = try SilentTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] SilentTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)
        session.automaticDisconnectDelay = 1

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            operation.setConnection(leased)
            let finished = self.start(operation)
            XCTAssertEqual(finished.wait(timeout: .now() + 5), .success,
                           "The greeting endpoint was expected to let the connect finish")

            // The queue has drained, so the 1s idle timer is armed. Reserved, the connection
            // must survive well past the timer period: the timer stands down instead of firing.
            XCTAssertFalse(endpoint.waitForClientDisconnect(timeout: 2.5),
                           "The idle auto-disconnect must stand down while the connection is reserved")

            session.releaseConnection(leased, disconnect: false)

            // Release re-arms the idle timer, which then closes the pooled socket.
            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 5),
                          "After release the re-armed auto-disconnect was expected to fire")
        }
    }

    func testReleaseWithDisconnectClosesTheConnection() throws {
        let endpoint = try SilentTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] SilentTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            operation.setConnection(leased)
            let finished = self.start(operation)
            XCTAssertEqual(finished.wait(timeout: .now() + 5), .success,
                           "The greeting endpoint was expected to let the connect finish")

            session.releaseConnection(leased, disconnect: true)
            XCTAssertFalse(leased.isReserved)
            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 5),
                          "Release with disconnect was expected to close the socket")
        }
    }

    func testReleaseIsIdempotent() throws {
        let endpoint = try SilentTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] SilentTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            operation.setConnection(leased)
            let finished = self.start(operation)
            XCTAssertEqual(finished.wait(timeout: .now() + 5), .success,
                           "The greeting endpoint was expected to let the connect finish")

            session.releaseConnection(leased, disconnect: false)
            // The second release must be a no-op: its disconnect would otherwise land on a
            // connection that is back in the shared pool and may serve other operations.
            session.releaseConnection(leased, disconnect: true)

            XCTAssertFalse(endpoint.waitForClientDisconnect(timeout: 2),
                           "A repeated release must not tear down a pooled connection")
        }
    }

    func testConnectionScopedDisconnectTearsTheSocketButKeepsTheLease() throws {
        let endpoint = try SilentTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] SilentTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            operation.setConnection(leased)
            let finished = self.start(operation)
            XCTAssertEqual(finished.wait(timeout: .now() + 5), .success,
                           "The greeting endpoint was expected to let the connect finish")

            let disconnect = self.start(leased.disconnectOperation())
            XCTAssertEqual(disconnect.wait(timeout: .now() + 5), .success)

            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 5),
                          "The connection-scoped disconnect was expected to close the socket")
            XCTAssertTrue(leased.isReserved,
                          "Refreshing tears the socket, not the lease")

            session.releaseConnection(leased, disconnect: false)
        }
    }
}

#endif
