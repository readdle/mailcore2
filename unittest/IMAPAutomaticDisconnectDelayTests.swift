//
//  IMAPAutomaticDisconnectDelayTests.swift
//  mailcore2
//
//  Tests for changing IMAPAsyncSession's automaticDisconnectDelay while connections are open.
//

// Darwin only: the tests need a POSIX listening socket, and the Android job builds the test target
// without running it.
#if canImport(Darwin)

import Darwin
import Dispatch
import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class IMAPAutomaticDisconnectDelayTests: XCTestCase {

    private static let greeting = "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n"

    /// A connection's queue reports that it ran dry about a second after its last operation
    /// (OperationQueue::checkRunningAfterDelay), and only then is the idle timer armed.
    private func waitForTheIdleTimer() {
        Thread.sleep(forTimeInterval: 2)
    }

    private func makeSession(port: UInt16) -> MCOIMAPSession {
        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(port)
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.timeout = 60
        session.maximumConnections = 1
        return session
    }

    /// mailcore hands parts of an operation's lifecycle to the main queue and waits for them, so
    /// the body runs off the main thread while the main thread spins its run loop.
    private func runOffMainThread(timeout: TimeInterval, _ body: @escaping () -> Void) {
        let finished = expectation(description: "test body")
        DispatchQueue.global(qos: .userInitiated).async {
            body()
            finished.fulfill()
        }
        waitForExpectations(timeout: timeout)
    }

    private func run(_ operation: MCOIMAPOperation) -> Error? {
        var error: Error?
        let finished = DispatchSemaphore(value: 0)
        operation.start { operationError in
            error = operationError
            finished.signal()
        }
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success, "The operation was expected to finish")
        return error
    }

    func testShorterDelayClosesAConnectionArmedWithTheDefault() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.greeting)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.connectOperation()))
            self.waitForTheIdleTimer() // armed with the default 30s

            session.automaticDisconnectDelay = 0.5

            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3),
                          "The running idle timer was expected to restart with the new delay")
        }
    }

    func testSubSecondDelayIsNotRoundedDown() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.greeting)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.connectOperation()))
            self.waitForTheIdleTimer()

            session.automaticDisconnectDelay = 0.8

            XCTAssertFalse(endpoint.waitForClientDisconnect(timeout: 0.3),
                           "Whole seconds would have turned 0.8 into an immediate disconnect")
            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3))
        }
    }

    func testDelayChangedDuringACommandWaitsForTheCommand() throws {
        var session: MCOIMAPSession!
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.greeting,
                                                answers: ["LOGIN": "",
                                                          "CAPABILITY": "* CAPABILITY IMAP4rev1\r\n",
                                                          "LIST": "* LIST (\\Noselect) \"/\" \"\"\r\n",
                                                          "NOOP": ""],
                                                beforeAnswering: ["NOOP": {
                                                    session.automaticDisconnectDelay = 0.2
                                                    // Well past the new delay, with the command still on the wire.
                                                    Thread.sleep(forTimeInterval: 0.8)
                                                }])
        defer { endpoint.stop() }
        session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.noopOperation()), "The command must not be cut by the new delay")

            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3),
                          "Once the command is done, the connection idles out with the new delay")
        }
    }

    func testLeasedConnectionWaitsForItsRelease() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.greeting)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }

        runOffMainThread(timeout: 30) {
            let connect = session.connectOperation()
            connect.setConnection(leased)
            XCTAssertNil(self.run(connect))

            session.automaticDisconnectDelay = 0.3

            XCTAssertFalse(endpoint.waitForClientDisconnect(timeout: 1.5),
                           "A leased connection stays open whatever the delay")

            session.releaseConnection(leased, disconnect: false)

            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3),
                          "The release re-arms the idle timer with the new delay")
        }
    }

    func testConcurrentChangesSettleOnTheLastOne() throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: Self.greeting)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.connectOperation()))
            self.waitForTheIdleTimer()

            // Every change restarts the running idle timer.
            DispatchQueue.concurrentPerform(iterations: 200) { index in
                session.automaticDisconnectDelay = index.isMultiple(of: 2) ? 30 : 60
            }
            XCTAssertFalse(endpoint.waitForClientDisconnect(timeout: 1))

            session.automaticDisconnectDelay = 0.3

            XCTAssertEqual(session.automaticDisconnectDelay, 0.3)
            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3))
        }
    }
}

#endif
