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
        let endpoint = try LeaseTestTCPEndpoint()
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

            session.releaseConnection(leased, disconnect: false)
            XCTAssertFalse(leased.isReserved)
        }
    }

    func testInterruptedConnectionReconnectsOnItsNextCommand() throws {
        // LOGIN and what mailcore sends right after it (CAPABILITY, the delimiter LIST) are
        // answered, so that the command the interrupt cuts is the NOOP itself - a plain command
        // outside login(), whose stream error is what has to schedule the reconnect.
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n",
                                                answers: ["LOGIN": "",
                                                          "CAPABILITY": "* CAPABILITY IMAP4rev1\r\n",
                                                          "LIST": "* LIST (\\Noselect) \"/\" \"\"\r\n"])
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let connect = session.connectOperation()
            connect.setConnection(leased)
            XCTAssertEqual(self.start(connect).wait(timeout: .now() + 5), .success,
                           "The greeting endpoint was expected to let the connect finish")
            XCTAssertEqual(endpoint.acceptedClientCount, 1)

            // Nothing answers the NOOP, so it blocks until interrupted.
            let noop = session.noopOperation()
            noop.setConnection(leased)
            let finished = self.start(noop)
            XCTAssertTrue(self.waitForOperationsCount(of: leased, toReach: 1))
            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The NOOP was expected to be blocked on the silent socket")
            XCTAssertTrue(noop.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success,
                           "interruptCurrentCommand() did not unblock the NOOP")

            // Still "connected" as far as its state goes, but on a stream libetpan will never read
            // from again. The next command has to start over, and the endpoint sees a second client.
            let reconnect = session.connectOperation()
            reconnect.setConnection(leased)
            XCTAssertEqual(self.start(reconnect).wait(timeout: .now() + 5), .success)
            XCTAssertEqual(endpoint.acceptedClientCount, 2,
                           "An interrupted connection must reconnect on its next command, on its own")

            session.releaseConnection(leased, disconnect: false)
        }
    }

    func testUnpinnedOperationAvoidsTheLeasedConnection() throws {
        let endpoint = try LeaseTestTCPEndpoint()
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
    /// Every other test leases with folder: nil, which takes acquireConnection's availableSession
    /// path and leaves the folder branch — both of the hunks that modify sessionForFolder — with
    /// no coverage at all. Those are the hunks that have to behave exactly as upstream does when
    /// nothing is reserved, so they are the ones worth pinning.
    func testAcquireWithAFolderSkipsReservedConnections() throws {
        let endpoint = try LeaseTestTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)

        guard let first = session.acquireConnection(folder: "INBOX") else {
            return XCTFail("An empty pool with room for 2 connections must satisfy the lease")
        }
        XCTAssertTrue(first.isReserved)

        // The same folder again: the connection already selected to it is reserved, so the pick
        // must create the second one rather than hand the first out twice.
        guard let second = session.acquireConnection(folder: "INBOX") else {
            return XCTFail("The pool had room for a second connection")
        }
        XCTAssertTrue(second.isReserved)
        XCTAssertNotEqual(first.identity, second.identity,
                          "a reserved connection must never be handed to a second holder")

        XCTAssertNil(session.acquireConnection(folder: "INBOX"),
                     "with both connections reserved the pool has nothing left to lease")
        XCTAssertNil(session.acquireConnection(folder: "Archive"),
                     "and a different folder does not change that")

        session.releaseConnection(first, disconnect: false)
        session.releaseConnection(second, disconnect: false)
    }

    /// A release is refused for a connection that belongs to another session's pool: it would
    /// clear a reservation that session is relying on and queue a disconnect on a connection this
    /// one has no claim to.
    func testReleaseIgnoresAConnectionFromAnotherSession() throws {
        let endpoint = try LeaseTestTCPEndpoint()
        defer { endpoint.stop() }

        let owner = makeSession(port: endpoint.port, maximumConnections: 1)
        let stranger = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = owner.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        stranger.releaseConnection(leased, disconnect: true)

        XCTAssertTrue(leased.isReserved, "another session must not be able to end this lease")
        XCTAssertNil(owner.acquireConnection(folder: nil),
                     "the owning pool must still consider its only connection leased")

        owner.releaseConnection(leased, disconnect: false)
    }

    func testExhaustedPoolSharesTheLeasedConnection() throws {
        let endpoint = try LeaseTestTCPEndpoint()
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
        let endpoint = try LeaseTestTCPEndpoint()
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
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)
        session.session.automaticDisconnectDelay = 1

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
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n")
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

    /// The release that matters is not the duplicated one, but the duplicated one that lands
    /// AFTER somebody else has taken the same connection. Without a lease token the second
    /// release passes every check — the connection is reserved, by this session — and clears the
    /// new holder's reservation while queueing a disconnect under it.
    func testStaleReleaseDoesNotCancelTheNextLease() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let first = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }
        session.releaseConnection(first, disconnect: false)

        guard let second = session.acquireConnection(folder: nil) else {
            return XCTFail("The released connection must be available again")
        }
        XCTAssertTrue(second.isReserved)

        // The first holder's cleanup runs a second time — a defer after an explicit release, an
        // error path after a normal one.
        session.releaseConnection(first, disconnect: true)

        XCTAssertTrue(second.isReserved, "a stale release must not free the lease that replaced it")
        XCTAssertNil(session.acquireConnection(folder: nil),
                     "the pool must still consider its only connection leased")

        // The refusal is the C++ primitive's, not the Swift handle's: the same stale release
        // straight through the C bridge, with the generation the first lease reported.
        session.session.releaseConnection(second.connection, first.leaseGeneration, true)
        XCTAssertTrue(second.isReserved, "the session itself must refuse a release with an older lease generation")

        session.releaseConnection(second, disconnect: false)
    }

    /// Nothing in the pool clears a reservation on its own, so a holder that loses track of its
    /// lease would cost the pool that connection for the life of the session. The handle returns
    /// the lease when it goes away.
    func testDroppingTheHandleReturnsTheLease() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n")
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        do {
            guard let leaked = session.acquireConnection(folder: nil) else {
                return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
            }
            XCTAssertTrue(leaked.isReserved)
            XCTAssertNil(session.acquireConnection(folder: nil), "the only connection is leased")
        }

        // The dropped handle returns its lease on the session's queue - the main queue here -
        // so the pool frees up once that queue has run.
        var reacquired: MCOIMAPAsyncConnection?
        let deadline = Date(timeIntervalSinceNow: 5)
        while reacquired == nil && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            reacquired = session.acquireConnection(folder: nil)
        }
        guard let reacquired = reacquired else {
            return XCTFail("A dropped handle must have returned its lease to the pool")
        }
        session.releaseConnection(reacquired, disconnect: false)
    }

    func testReleaseIsIdempotent() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n")
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

    /// The freshness question a leaseholder actually asks is "was this connection's view taken
    /// before my signal", and a connection that has never logged in has no view at all: its
    /// first command logs in and therefore sees the current state. Reporting nil here is what
    /// lets a caller skip a teardown it used to pay for, having no way to tell a fresh pool
    /// connection from a stale one.
    ///
    /// acquireConnection does no I/O, so this asserts on a connection that provably never
    /// reached the wire. The other half - that a real LOGIN is recorded and a later one moves
    /// the value forward - is not unit-testable here: this suite has no IMAP server, and a fake
    /// answering just enough to get through LOGIN would encode mailcore's own post-login
    /// sequence in a test. It is verified against the live server instead.
    func testNeverConnectedConnectionReportsNoLoginTime() throws {
        let endpoint = try LeaseTestTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 1)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }
        defer { session.releaseConnection(leased, disconnect: false) }

        XCTAssertNil(leased.lastLoginDate,
                     "A pool connection that has never logged in must not claim a login moment")
    }

    func testConnectionScopedDisconnectTearsTheSocketButKeepsTheLease() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n")
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

    // MARK: - Liveness of the chosen connection

    /// Lets a CONNECT finish - capabilities inline, so no CAPABILITY follow-up - and answers
    /// nothing else, so a connected connection stays idle and any command pinned to it blocks.
    private static let bannerOnlyGreeting = "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n"

    /// Two pooled connections in a known order: taking the second lease while the first is held
    /// is what makes the pool grow to two, and it fixes which one comes first.
    private func leaseTwoConnections(_ session: MCOIMAPSession,
                                     folder: String? = nil) -> [MCOIMAPAsyncConnection]? {
        guard let first = session.acquireConnection(folder: folder),
              let second = session.acquireConnection(folder: folder) else {
            XCTFail("A pool with room for 2 connections must satisfy both leases")
            return nil
        }
        return [first, second]
    }

    private func releaseAll(_ session: MCOIMAPSession, _ connections: [MCOIMAPAsyncConnection]) {
        for connection in connections {
            session.releaseConnection(connection, disconnect: false)
        }
    }

    private func runConnect(_ session: MCOIMAPSession, on connection: MCOIMAPAsyncConnection) {
        let operation = session.connectOperation()
        operation.setConnection(connection)
        XCTAssertEqual(start(operation).wait(timeout: .now() + 5), .success,
                       "The greeting endpoint was expected to let the connect finish")
    }

    /// Stands in for the socket the pool drops after its idle delay, minus the waiting: the
    /// operation reports back once the teardown is done, so the state read afterwards is settled.
    private func tearDownSocket(of connection: MCOIMAPAsyncConnection) {
        XCTAssertEqual(start(connection.disconnectOperation()).wait(timeout: .now() + 5), .success,
                       "The connection-scoped disconnect was expected to finish")
    }

    /// Two free idle connections, one of them disconnected: their queues say the same thing, so
    /// without the preference the pick is position in the pool and the first, most urgent asker
    /// pays for a handshake half the time. Run for either position and for both acquireConnection
    /// paths; only the dead-comes-first variants can fail without it, the others hold the
    /// established order in place.
    private func assertLeasePrefersTheLiveConnection(deadIndex: Int, folder: String?) throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting)
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session, folder: folder) else {
            return
        }

        runOffMainThread(timeout: 60) {
            for connection in pool {
                self.runConnect(session, on: connection)
            }
            self.tearDownSocket(of: pool[deadIndex])
            self.releaseAll(session, pool)

            guard let acquired = session.acquireConnection(folder: folder) else {
                return XCTFail("With both connections back in the pool a lease must be satisfied")
            }
            defer { session.releaseConnection(acquired, disconnect: false) }

            XCTAssertEqual(acquired.identity, pool[1 - deadIndex].identity,
                           "The lease must go to the connected connection, not to the one that owes a handshake")
        }
    }

    func testAcquirePrefersTheLiveConnectionOverAnEarlierDeadOne() throws {
        try assertLeasePrefersTheLiveConnection(deadIndex: 0, folder: nil)
    }

    func testAcquirePrefersTheLiveConnectionOverALaterDeadOne() throws {
        try assertLeasePrefersTheLiveConnection(deadIndex: 1, folder: nil)
    }

    /// Folder affinity outlives the socket - nothing clears the last selected folder on a
    /// disconnect - so the folder-matched branch chooses between the same two connections.
    func testAcquireForAFolderPrefersTheLiveConnection() throws {
        try assertLeasePrefersTheLiveConnection(deadIndex: 0, folder: "INBOX")
    }

    /// A connection that has never been used owes the same handshake as one that idled out.
    func testAcquirePrefersAWarmConnectionOverANeverConnectedOne() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting)
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session) else {
            return
        }

        runOffMainThread(timeout: 60) {
            self.runConnect(session, on: pool[1])
            self.releaseAll(session, pool)

            guard let acquired = session.acquireConnection(folder: nil) else {
                return XCTFail("With both connections back in the pool a lease must be satisfied")
            }
            defer { session.releaseConnection(acquired, disconnect: false) }

            XCTAssertEqual(acquired.identity, pool[1].identity,
                           "A connection that never reached the wire is not the ready one")
        }
    }

    /// The preference is the tie and nothing more: a shorter queue wins outright, even when the
    /// shorter queue is the disconnected one. Queue length counts commands without weighing them,
    /// and a lease is owed an empty queue.
    func testShorterQueueWinsEvenWhenItIsTheDeadConnection() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting)
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session) else {
            return
        }

        runOffMainThread(timeout: 60) {
            for connection in pool {
                self.runConnect(session, on: connection)
            }
            self.tearDownSocket(of: pool[0])

            // The endpoint answers nothing past the banner, so this command stays in the queue.
            let noop = session.noopOperation()
            noop.setConnection(pool[1])
            let finished = self.start(noop)
            XCTAssertTrue(self.waitForOperationsCount(of: pool[1], toReach: 1))
            self.releaseAll(session, pool)

            guard let acquired = session.acquireConnection(folder: nil) else {
                return XCTFail("With both connections back in the pool a lease must be satisfied")
            }
            XCTAssertEqual(acquired.identity, pool[0].identity,
                           "An empty queue wins the lease even when it costs a handshake to use")
            session.releaseConnection(acquired, disconnect: false)

            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The NOOP was expected to be blocked on the silent socket")
            XCTAssertTrue(noop.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)
        }
    }

    /// A connection whose stream died under a command is the case the socket state alone gets
    /// wrong: libetpan never clears a cancelled stream, so the session stays "connected" while its
    /// next command has to tear that stream down and build the connection again — strictly more
    /// than a closed socket costs. It must lose the tie to a connection that can answer.
    func testAcquirePrefersTheLiveConnectionOverAnInterruptedOne() throws {
        // LOGIN and what mailcore sends after it are answered, so the command the interrupt cuts is
        // the NOOP itself - the connection is fully logged in when its stream dies, which is the
        // state this is about.
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting,
                                                answers: ["LOGIN": "",
                                                          "CAPABILITY": "* CAPABILITY IMAP4rev1\r\n",
                                                          "LIST": "* LIST (\\Noselect) \"/\" \"\"\r\n"])
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session) else {
            return
        }

        runOffMainThread(timeout: 60) {
            for connection in pool {
                self.runConnect(session, on: connection)
            }

            // Nothing answers the NOOP, so interrupting it is what cancels the stream and leaves
            // the connection pooled, connected, and owing a reconnect.
            let noop = session.noopOperation()
            noop.setConnection(pool[0])
            let finished = self.start(noop)
            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The NOOP was expected to be blocked on the silent socket")
            XCTAssertTrue(noop.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)
            self.releaseAll(session, pool)

            guard let acquired = session.acquireConnection(folder: nil) else {
                return XCTFail("With both connections back in the pool a lease must be satisfied")
            }
            defer { session.releaseConnection(acquired, disconnect: false) }

            XCTAssertEqual(acquired.identity, pool[1].identity,
                           "A cancelled stream costs more than a closed socket, not less")
        }
    }

    /// Two live idle connections stay interchangeable, and the pick stays the first in the pool.
    func testTiesAmongLiveConnectionsKeepThePoolOrder() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting)
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session) else {
            return
        }

        runOffMainThread(timeout: 60) {
            for connection in pool {
                self.runConnect(session, on: connection)
            }
            self.releaseAll(session, pool)

            guard let acquired = session.acquireConnection(folder: nil) else {
                return XCTFail("With both connections back in the pool a lease must be satisfied")
            }
            defer { session.releaseConnection(acquired, disconnect: false) }

            XCTAssertEqual(acquired.identity, pool[0].identity,
                           "With nothing to tell two idle live connections apart the first stays the pick")
        }
    }

    /// Leases are not the only caller: a regular operation goes through the same selection.
    func testUnpinnedOperationRunsOnTheLiveConnection() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting)
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session) else {
            return
        }

        runOffMainThread(timeout: 60) {
            for connection in pool {
                self.runConnect(session, on: connection)
            }
            self.tearDownSocket(of: pool[0])
            self.releaseAll(session, pool)

            let noop = session.noopOperation()
            let finished = self.start(noop)

            XCTAssertTrue(self.waitForOperationsCount(of: pool[1], toReach: 1),
                          "A regular operation must land on the connection that can answer it right away")
            XCTAssertEqual(pool[0].operationsCount, 0,
                           "The disconnected connection must be left alone while a live one is free")

            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The NOOP was expected to be blocked on the silent socket")
            XCTAssertTrue(noop.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)
        }
    }

    /// The all-reserved fallback shares a leased connection with regular operations, through the
    /// same pick: it too must hand over the one that can answer now.
    func testExhaustedPoolSharesTheLiveConnection() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.bannerOnlyGreeting)
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port, maximumConnections: 2)
        guard let pool = leaseTwoConnections(session) else {
            return
        }

        runOffMainThread(timeout: 60) {
            for connection in pool {
                self.runConnect(session, on: connection)
            }
            self.tearDownSocket(of: pool[0])

            // Both stay leased: with the pool at its limit a regular operation has nothing else.
            let noop = session.noopOperation()
            let finished = self.start(noop)

            XCTAssertTrue(self.waitForOperationsCount(of: pool[1], toReach: 1),
                          "The shared connection must be the live one")
            XCTAssertEqual(pool[0].operationsCount, 0,
                           "Sharing must not revive a disconnected connection while a live one is there")

            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The NOOP was expected to be blocked on the silent socket")
            XCTAssertTrue(noop.interruptCurrentCommand())
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)

            self.releaseAll(session, pool)
        }
    }
}

#endif
