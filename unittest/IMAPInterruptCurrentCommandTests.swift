//
//  IMAPInterruptCurrentCommandTests.swift
//  mailcore2
//
//  Tests for IMAPOperation::interruptCurrentCommand().
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

final class IMAPInterruptCurrentCommandTests: XCTestCase {

    /// Well above every wait below: a command left to its own devices must not be able to finish on
    /// its own and pass a test that is about being interrupted.
    private let sessionTimeout: TimeInterval = 60

    private func makeSession(port: UInt16) -> MCOIMAPSession {
        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(port)
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.timeout = sessionTimeout
        session.maximumConnections = 1
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

    func testInterruptEndsTheWaitOfTheRunningCommand() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            let operation = session.connectOperation()
            let finished = self.start(operation)

            // The endpoint accepts the connection and stays silent, so the command is stuck reading
            // the greeting.
            XCTAssertEqual(finished.wait(timeout: .now() + 2), .timedOut,
                           "The command was expected to be blocked on the socket")

            XCTAssertTrue(operation.interruptCurrentCommand(),
                          "The running operation was expected to report that it interrupted a command")

            // Left alone this would return only when the 60s socket timeout expires.
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success,
                           "interruptCurrentCommand() did not unblock the running command")
        }
    }

    func testInterruptDoesNothingForAnOperationThatIsNotRunning() throws {
        let endpoint = try SilentTCPEndpoint()
        defer { endpoint.stop() }

        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 60) {
            // One connection, so the second operation waits in the queue while the first one blocks.
            let running = session.connectOperation()
            let runningFinished = self.start(running)

            XCTAssertEqual(runningFinished.wait(timeout: .now() + 2), .timedOut,
                           "The first command was expected to be blocked on the socket")

            let queued = session.noopOperation()
            let queuedFinished = self.start(queued)

            // The queued operation owns no connection, so interrupting on its behalf must not touch
            // the stream the running one is blocked on.
            XCTAssertFalse(queued.interruptCurrentCommand(),
                           "A queued operation has no command of its own to interrupt")

            XCTAssertEqual(runningFinished.wait(timeout: .now() + 3), .timedOut,
                           "A queued operation must not interrupt the command of the running one")

            // ... while the running operation can still be interrupted itself.
            XCTAssertTrue(running.interruptCurrentCommand(),
                          "The running operation was expected to report that it interrupted a command")

            XCTAssertEqual(runningFinished.wait(timeout: .now() + 10), .success,
                           "interruptCurrentCommand() did not unblock the running command")
            XCTAssertEqual(queuedFinished.wait(timeout: .now() + 10), .success,
                           "The queued operation was expected to finish once the connection was freed")
        }
    }
}

#endif
