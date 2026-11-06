//
//  IMAPIdentityTests.swift
//  mailcore2
//
//  The client identity sent with the IMAP ID command (RFC 2971).
//

#if canImport(Darwin)

import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

final class IMAPIdentityTests: XCTestCase {

    func testSetInfoStoresTheValueUnderTheKey() {
        let session = MCOIMAPSession()

        session.clientIdentity.setInfo("mac", forKey: "platform")

        XCTAssertEqual(session.clientIdentity.infoForKey("platform"), "mac")
        XCTAssertEqual(session.clientIdentity.allInfoKeys(), ["platform"])
    }
}

#endif
