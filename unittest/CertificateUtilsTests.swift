//
//  CertificateUtilsTests.swift
//  mailcore2
//
//  Tests for mailcore::checkCertificateChain(), the verification every IMAP/SMTP/POP/NNTP
//  session runs on the server certificate right after the TLS handshake (COR-170).
//

import Foundation
import XCTest

#if SWIFT_PACKAGE
import CMailCore
#endif

@testable import MailCore

/// Fixtures live in data/certificates and were generated with OpenSSL:
///
///  - `ca.der`    a private root, valid 2020-01-01 .. 2120-01-01
///  - `leaf.der`  issued by that root for `imap.example.test`, `*.wild.example.test`,
///                `10.1.2.3` and `2001:db8::1`; valid 2026-01-01 .. 2027-12-31
///  - `other.der` an unrelated root that signed nothing here
///
/// The root is passed to the verifier as the only trust anchor, so the tests do not depend on
/// the device's trust store, and verification is pinned to 2026-06-15 so they do not depend on
/// the clock either. The leaf's validity stays under 825 days on purpose: Apple's TLS policy
/// rejects longer-lived server certificates regardless of who issued them.
final class CertificateUtilsTests: XCTestCase {

    /// 2026-06-15T00:00:00Z, inside the leaf's validity period.
    private static let verifyTime: Int64 = 1_781_481_600
    /// 2030-01-01T00:00:00Z, after the leaf expired.
    private static let afterLeafExpiry: Int64 = 1_893_456_000

    private var root = Data()
    private var leaf = Data()
    private var unrelatedRoot = Data()

    override func setUpWithError() throws {
        try super.setUpWithError()

        #if os(Android)
        let directory = Bundle.main.bundleURL.appendingPathComponent("resources/data/certificates")
        #else
        let directory = Bundle.module.resourceURL!.appendingPathComponent("data/certificates")
        #endif

        root = try Data(contentsOf: directory.appendingPathComponent("ca.der"))
        leaf = try Data(contentsOf: directory.appendingPathComponent("leaf.der"))
        unrelatedRoot = try Data(contentsOf: directory.appendingPathComponent("other.der"))
    }

    /// Runs the verifier the way a session does, with the given DER chain (leaf first).
    private func verify(chain: [Data],
                        hostname: String,
                        anchors: [Data]? = nil,
                        at verifyTime: Int64 = CertificateUtilsTests.verifyTime) -> Bool {
        return mailCoreAutoreleasePool {
            let cChain = CArray_init()
            for certificate in chain {
                cChain.addObject(certificate.mailCoreData().toCObject())
            }
            let cAnchors = CArray_init()
            for anchor in anchors ?? [root] {
                cAnchors.addObject(anchor.mailCoreData().toCObject())
            }
            return CCertificateUtils_checkCertificateChain(cChain, hostname.mailCoreString(), cAnchors, verifyTime)
        }
    }

    // MARK: - Accepted

    func testAcceptsCertificateIssuedForHostname() {
        XCTAssertTrue(verify(chain: [leaf, root], hostname: "imap.example.test"))
    }

    func testAcceptsChainWithoutTheRootIncluded() {
        // Servers commonly send only the leaf (and intermediates); the root comes from the store.
        XCTAssertTrue(verify(chain: [leaf], hostname: "imap.example.test"))
    }

    func testHostnameMatchIsCaseInsensitive() {
        XCTAssertTrue(verify(chain: [leaf, root], hostname: "IMAP.Example.TEST"))
    }

    func testAcceptsSingleLabelWildcardMatch() {
        XCTAssertTrue(verify(chain: [leaf, root], hostname: "mail.wild.example.test"))
    }

    func testAcceptsIPv4LiteralFromSubjectAlternativeName() {
        XCTAssertTrue(verify(chain: [leaf, root], hostname: "10.1.2.3"))
    }

    func testAcceptsIPv6LiteralFromSubjectAlternativeName() {
        XCTAssertTrue(verify(chain: [leaf, root], hostname: "2001:db8::1"))
    }

    // MARK: - Rejected: identity

    func testRejectsCertificateIssuedForAnotherHostname() {
        // The COR-170 report: a valid, trusted certificate for a different host was accepted.
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "gmail-imap.l.google.com"))
    }

    func testRejectsHostnameThatOnlySharesTheParentDomain() {
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "example.test"))
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "smtp.example.test"))
    }

    func testRejectsWildcardSpanningSeveralLabels() {
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "a.b.wild.example.test"))
    }

    func testRejectsWildcardParentDomainItself() {
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "wild.example.test"))
    }

    func testRejectsIPLiteralNotInSubjectAlternativeName() {
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "10.1.2.4"))
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "2001:db8::2"))
    }

    func testRejectsEmptyHostname() {
        XCTAssertFalse(verify(chain: [leaf, root], hostname: ""))
    }

    // MARK: - Rejected: chain

    func testRejectsChainNotLeadingToATrustedRoot() {
        // Correct hostname, but the only trusted root did not issue the chain.
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "imap.example.test", anchors: [unrelatedRoot]))
    }

    func testRejectsExpiredCertificate() {
        XCTAssertFalse(verify(chain: [leaf, root], hostname: "imap.example.test", at: CertificateUtilsTests.afterLeafExpiry))
    }

    func testRejectsEmptyChain() {
        XCTAssertFalse(verify(chain: [], hostname: "imap.example.test"))
    }

    func testRejectsMalformedCertificate() {
        XCTAssertFalse(verify(chain: [Data("not a certificate".utf8)], hostname: "imap.example.test"))
    }
}
