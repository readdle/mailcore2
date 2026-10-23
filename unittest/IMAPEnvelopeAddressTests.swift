//
//  IMAPEnvelopeAddressTests.swift
//  mailcore2
//
//  ENVELOPE address lists: group markers are not addresses (RFC 3501 7.4.2).
//

#if canImport(Darwin)

import Dispatch
import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class IMAPEnvelopeAddressTests: XCTestCase {

    private struct Envelope {
        var from = "((\"Sender\" NIL \"sender\" \"example.com\"))"
        var sender = "NIL"
        var replyTo = "NIL"
        var to = "NIL"
        var cc = "NIL"
        var bcc = "NIL"
    }

    private let groupEnd = "(NIL NIL NIL NIL)"

    private func runOffMainThread(timeout: TimeInterval, _ body: @escaping () -> Void) {
        let finished = expectation(description: "test body")
        DispatchQueue.global(qos: .userInitiated).async {
            body()
            finished.fulfill()
        }
        waitForExpectations(timeout: timeout)
    }

    /// The header mailcore builds from `envelope`, served as the answer to a UID FETCH.
    private func fetchHeader(_ envelope: Envelope, file: StaticString = #filePath, line: UInt = #line) throws -> MCOMessageHeader? {
        let fields = [envelope.from, envelope.sender, envelope.replyTo, envelope.to, envelope.cc, envelope.bcc].joined(separator: " ")
        let fetch = "* 1 FETCH (UID 1 ENVELOPE (\"Fri, 09 Oct 2026 12:41:28 +0000\" \"Subject\" \(fields) NIL \"<id@example.com>\")"
            + " BODY[HEADER.FIELDS (References)] {2}\r\n\r\n)\r\n"
        let endpoint = try LeaseTestTCPEndpoint(greeting: "* OK [CAPABILITY IMAP4rev1] LeaseTestTCPEndpoint ready\r\n",
                                                answers: ["LOGIN": "",
                                                          "CAPABILITY": "* CAPABILITY IMAP4rev1\r\n",
                                                          "LIST": "* LIST (\\Noselect) \"/\" \"\"\r\n",
                                                          "SELECT": "* 1 EXISTS\r\n* OK [UIDVALIDITY 1] UIDs valid\r\n",
                                                          "UID": fetch])
        defer { endpoint.stop() }

        let session = MCOIMAPSession()
        session.hostname = "127.0.0.1"
        session.port = UInt32(endpoint.port)
        session.connectionType = ConnectionTypeClear
        session.username = "user"
        session.password = "password"
        session.timeout = 10
        session.maximumConnections = 1

        var fetched: [MCOIMAPMessage]?
        var fetchError: Error?
        runOffMainThread(timeout: 30) {
            let finished = DispatchSemaphore(value: 0)
            session.fetchMessagesByUid(folder: "INBOX", kind: .headers, uids: MCOIndexSet(index: 1)).start { error, messages, _ in
                fetchError = error
                fetched = messages
                finished.signal()
            }
            XCTAssertEqual(finished.wait(timeout: .now() + 20), .success, "The fetch did not finish", file: file, line: line)
        }
        XCTAssertNil(fetchError, file: file, line: line)
        XCTAssertEqual(fetched?.count, 1, file: file, line: line)
        return fetched?.first?.header
    }

    private func mailboxes(_ addresses: [MCOAddress]?) -> [String]? {
        return addresses?.map { $0.mailbox }
    }

    /// Strato sends a lone end marker for every empty address field.
    func testLoneGroupEndIsAnEmptyField() throws {
        var envelope = Envelope()
        envelope.from = "((\"Ewald Klimach\" NIL \"ewald.klimach\" \"antriebstechnik-hilden.de\"))"
        envelope.sender = "(\(groupEnd))"
        envelope.replyTo = "(\(groupEnd))"
        envelope.to = "((NIL NIL \"a.moog\" \"unicu.de\"))"
        envelope.cc = "(\(groupEnd))"
        envelope.bcc = "(\(groupEnd))"

        let header = try XCTUnwrap(try fetchHeader(envelope))
        XCTAssertEqual(header.from?.mailbox, "ewald.klimach@antriebstechnik-hilden.de")
        XCTAssertNil(header.sender)
        XCTAssertNil(header.replyTo)
        XCTAssertEqual(mailboxes(header.to), ["a.moog@unicu.de"])
        XCTAssertNil(header.cc)
        XCTAssertNil(header.bcc)
    }

    func testEmptyGroupIsAnEmptyField() throws {
        var envelope = Envelope()
        envelope.to = "((NIL NIL \"undisclosed-recipients\" NIL)\(groupEnd))"

        let header = try XCTUnwrap(try fetchHeader(envelope))
        XCTAssertNil(header.to)
    }

    func testGroupContributesOnlyItsMembers() throws {
        var envelope = Envelope()
        envelope.to = "((NIL NIL \"before\" \"example.com\")(NIL NIL \"team\" NIL)(\"Member A\" NIL \"a\" \"example.com\")"
            + "(NIL NIL \"b\" \"example.com\")\(groupEnd)(NIL NIL \"after\" \"example.com\"))"

        let header = try XCTUnwrap(try fetchHeader(envelope))
        XCTAssertEqual(mailboxes(header.to), ["before@example.com", "a@example.com", "b@example.com", "after@example.com"])
        XCTAssertEqual(header.to?[1].displayName, "Member A")
    }

    /// A NIL host with no end marker after it is an address without a domain, not a group start.
    func testDomainlessAddressIsKept() throws {
        var envelope = Envelope()
        envelope.from = "((NIL NIL \"root\" NIL))"
        envelope.to = "((NIL NIL \"root\" NIL))"
        envelope.cc = "((NIL NIL \"a\" \"example.com\")(NIL NIL \"root\" NIL))"

        let header = try XCTUnwrap(try fetchHeader(envelope))
        XCTAssertEqual(header.from?.mailbox, "root")
        XCTAssertEqual(mailboxes(header.to), ["root"])
        XCTAssertEqual(mailboxes(header.cc), ["a@example.com", "root"])
    }

    /// An ENVELOPE cannot tell a domain-less address before a group from a group start; it is
    /// dropped so that a group name never becomes a recipient.
    func testDomainlessAddressBeforeGroupIsDropped() throws {
        var envelope = Envelope()
        envelope.to = "((NIL NIL \"root\" NIL)(NIL NIL \"team\" NIL)(NIL NIL \"a\" \"example.com\")\(groupEnd))"

        let header = try XCTUnwrap(try fetchHeader(envelope))
        XCTAssertEqual(mailboxes(header.to), ["a@example.com"])
    }
}

#endif
