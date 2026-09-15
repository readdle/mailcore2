//
//  IMAPLoginTests.swift
//  mailcore2
//
//  login() must not report success on a session that is not logged in.
//

#if canImport(Darwin)

import Dispatch
import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class IMAPLoginTests: XCTestCase {

    private final class ConnectionSlot: @unchecked Sendable {
        private let lock = NSLock()
        private var value: MCOIMAPAsyncConnection?
        var connection: MCOIMAPAsyncConnection? {
            get { lock.withLock { value } }
            set { lock.withLock { value = newValue } }
        }
    }

    private func runOffMainThread(timeout: TimeInterval, _ body: @escaping () -> Void) {
        let finished = expectation(description: "test body")
        DispatchQueue.global(qos: .userInitiated).async {
            body()
            finished.fulfill()
        }
        waitForExpectations(timeout: timeout)
    }

    /// The reconnect flag raised while login() is between its commands - an interrupt from
    /// another thread does that - is met by identity(), the one step of login() whose result is
    /// ignored. It tears the connection down and rebuilds it, and the rebuilt connection is not
    /// logged in. login() must report that instead of success: a caller told "logged in" runs its
    /// command on a session that is not, or - when the rebuild failed - on no mailimap at all.
    func testLoginFailsWhenItsIdentityStepRebuildsTheConnection() throws {
        // The endpoint's reader thread raises the flag on a connection the test thread leases
        // after the endpoint exists; the slot makes that hand-over defined.
        let slot = ConnectionSlot()
        // The flag lands while NAMESPACE is on the wire: after fetchNamespace()'s own
        // connectIfNeeded() has run, before identity()'s does.
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1 ID NAMESPACE] LeaseTestTCPEndpoint ready\r\n",
                                                answers: ["LOGIN": "",
                                                          "CAPABILITY": "* CAPABILITY IMAP4rev1 ID NAMESPACE\r\n",
                                                          "NAMESPACE": "* NAMESPACE ((\"\" \"/\")) NIL NIL\r\n",
                                                          "ID": "* ID NIL\r\n"],
                                                beforeAnswering: ["NAMESPACE": { slot.connection?.scheduleReconnect() }])
        defer { endpoint.stop() }

        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(endpoint.port)
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.timeout = 60
        session.maximumConnections = 1

        guard let leased = session.acquireConnection(folder: nil) else {
            return XCTFail("An empty pool with room for 1 connection must satisfy the lease")
        }
        slot.connection = leased

        runOffMainThread(timeout: 30) {
            let expunge = session.expungeOperation(folder: "INBOX")
            expunge.setConnection(leased)
            var error: Error?
            let finished = DispatchSemaphore(value: 0)
            expunge.start { opError in
                error = opError
                finished.signal()
            }
            XCTAssertEqual(finished.wait(timeout: .now() + 10), .success)

            XCTAssertEqual(endpoint.acceptedClientCount, 2, "identity() was expected to rebuild the connection")
            XCTAssertEqual((error as NSError?)?.code, Int(MailCoreError.errorConnection.rawValue),
                           "A login that ends on a rebuilt, unauthenticated connection must fail as a connection error, got \(String(describing: error))")

            session.releaseConnection(leased, disconnect: false)
        }
    }
}

#endif
