//
//  SMTPCheckAccountTests.swift
//  mailcore2
//
//  An account check must not keep its connection once it has reported.
//

#if canImport(Darwin)

import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class SMTPCheckAccountTests: XCTestCase {

    /// Servers that cap concurrent connections per client IP refuse the next check while this
    /// one's socket is open, and the automatic disconnect only closes it 30 s later.
    func testCheckAccountClosesItsConnectionOnSuccess() throws {
        try assertCheckClosesConnection(mailReply: "250 OK\r\n", expectedError: nil)
    }

    func testCheckAccountClosesItsConnectionWhenTheServerRejectsTheSender() throws {
        try assertCheckClosesConnection(mailReply: "550 Sender rejected\r\n", expectedError: ErrorInvalidAccount)
    }

    private func assertCheckClosesConnection(mailReply: String, expectedError: ErrorCode?) throws {
        let endpoint = try LeaseTestTCPEndpoint(greeting: "220 LeaseTestTCPEndpoint ready\r\n", replies: { line in
            switch line.split(separator: " ").first?.uppercased() {
            case "EHLO": return "250 LeaseTestTCPEndpoint\r\n"
            case "MAIL": return mailReply
            case "RCPT": return "250 OK\r\n"
            case "QUIT": return "221 Bye\r\n"
            default: return nil
            }
        })
        defer { endpoint.stop() }

        let session = MCOSMTPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(endpoint.port)
        session.connectionType = ConnectionTypeClear
        session.timeout = 60

        let checked = expectation(description: "check account")
        var checkError: Error?
        let address = MCOAddress(mailbox: "user@example.com")!
        session.checkAccountOperation(from: address, to: address).start { error in
            checkError = error
            checked.fulfill()
        }
        wait(for: [checked], timeout: 10)

        XCTAssertEqual((checkError as NSError?)?.code, expectedError.map { Int($0.rawValue) })
        XCTAssertTrue(endpoint.waitForClientDisconnect(timeout: 5),
                      "The check must close its connection instead of leaving it to the 30 s automatic disconnect")
    }
}

#endif
