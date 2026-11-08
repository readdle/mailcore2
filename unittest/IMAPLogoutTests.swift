//
//  IMAPLogoutTests.swift
//  mailcore2
//
//  Tests for the LOGOUT an IMAP session sends when it drops a logged-in connection.
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

final class IMAPLogoutTests: XCTestCase {

    private static let greeting = "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n"

    /// Answers enough of a login for a NOOP to log in and succeed. LOGOUT is answered after
    /// `logoutReplyDelay`, so a client that waited for the reply would be held that long.
    private func makeEndpoint(logoutReceived: DispatchSemaphore,
                              logoutReplyDelay: TimeInterval = 0) throws -> LeaseTestTCPEndpoint {
        return try LeaseTestTCPEndpoint(greeting: Self.greeting,
                                        answers: ["LOGIN": "",
                                                  "CAPABILITY": "* CAPABILITY IMAP4rev1\r\n",
                                                  "LIST": "* LIST (\\Noselect) \"/\" \"\"\r\n",
                                                  "NOOP": "",
                                                  "LOGOUT": "* BYE logging out\r\n"],
                                        beforeAnswering: ["LOGOUT": {
                                            logoutReceived.signal()
                                            Thread.sleep(forTimeInterval: logoutReplyDelay)
                                        }])
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

    func testIdleDisconnectLogsOut() throws {
        let logoutReceived = DispatchSemaphore(value: 0)
        let endpoint = try makeEndpoint(logoutReceived: logoutReceived)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)
        session.isLogoutOnDisconnectEnabled = true
        session.automaticDisconnectDelay = 0.5

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.noopOperation()))

            XCTAssertEqual(logoutReceived.wait(timeout: .now() + 5), .success,
                           "A connection closed for being idle was expected to log out")
            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3))
        }
    }

    func testDisconnectDoesNotWaitForTheLogoutReply() throws {
        let logoutReceived = DispatchSemaphore(value: 0)
        let endpoint = try makeEndpoint(logoutReceived: logoutReceived, logoutReplyDelay: 3)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)
        session.isLogoutOnDisconnectEnabled = true

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.noopOperation()))

            let started = Date()
            XCTAssertNil(self.run(session.disconnectOperation()))
            XCTAssertLessThan(Date().timeIntervalSince(started), 1.5,
                              "The disconnect was expected to close without waiting for the reply")

            XCTAssertEqual(logoutReceived.wait(timeout: .now() + 3), .success)
            // The endpoint sees the close only once its delayed reply is out.
            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 6))
        }
    }

    func testDisconnectSendsNoLogoutByDefault() throws {
        let logoutReceived = DispatchSemaphore(value: 0)
        let endpoint = try makeEndpoint(logoutReceived: logoutReceived)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.noopOperation()))
            XCTAssertNil(self.run(session.disconnectOperation()))

            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3))
            XCTAssertEqual(logoutReceived.wait(timeout: .now() + 0.5), .timedOut,
                           "A session that did not opt in keeps closing the socket without LOGOUT")
        }
    }

    func testDisconnectBeforeLoginSendsNoLogout() throws {
        let logoutReceived = DispatchSemaphore(value: 0)
        let endpoint = try makeEndpoint(logoutReceived: logoutReceived)
        defer { endpoint.stop() }
        let session = makeSession(port: endpoint.port)
        session.isLogoutOnDisconnectEnabled = true

        runOffMainThread(timeout: 30) {
            XCTAssertNil(self.run(session.connectOperation()), "Connects without logging in")
            XCTAssertNil(self.run(session.disconnectOperation()))

            XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 3))
            XCTAssertEqual(logoutReceived.wait(timeout: .now() + 0.5), .timedOut,
                           "Only a logged-in connection logs out")
        }
    }
}

#endif
