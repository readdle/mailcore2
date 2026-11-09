//
//  RSMLibetpanHelperTests.swift
//  MailCoreTests
//
//  Created by Andrew on 9/25/17.
//  Copyright © 2017 MailCore. All rights reserved.
//

import Foundation
import XCTest

import MailCore

public class LibetpanHelperTests: XCTestCase {
    
    override public func setUp() {
        // swift-corelibs-foundation on Linux traps in the `NSTimeZone.default` setter.
        #if !os(Linux)
        NSTimeZone.default = TimeZone(identifier: "Europe/Kiev")!
        #endif
    }
    
    func testDates() {
        XCTAssertNil(LibetpanHelper.date(fromRFC2822String: "Wed, 22 April 2015 05:10:18"))
        XCTAssertEqual(LibetpanHelper.date(fromRFC2822String: "Tue, 14 Apr 2015 16:40:45 +0300")?.timeIntervalSinceReferenceDate, 450711645)
        XCTAssertEqual(LibetpanHelper.date(fromRFC2822String: "Wed, 22 Apr 2015 13:47:36 +0000")?.timeIntervalSinceReferenceDate, 451403256)
    }
}
