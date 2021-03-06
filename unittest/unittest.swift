//
//  unittest.swift
//  mailcore2
//
//  Created by Andrew on 12/5/16.
//  Copyright © 2016 MailCore. All rights reserved.
//

import Foundation
import Dispatch
import XCTest

#if os(Android)
    import CMailCore
#endif

@testable import MailCore

fileprivate func equalAny(_ lhsValue: Any, _ rhsValue: Any) -> Bool {
    if let lhsHashable = lhsValue as? AnyHashable, let rhsHashable = rhsValue as? AnyHashable {
        if lhsHashable != rhsHashable {
            print("EqualAny assert: \(type(of: lhsHashable)):\(lhsHashable) != \(type(of: rhsHashable)):\(rhsHashable)")
            return false
        }
    }
    else if let lhsArray = lhsValue as? Array<Any>, let rhsArray = rhsValue as? Array<Any> {
        if equalArrays(lhsArray, rhsArray) == false {
            //print("EqualAny assert: equalArrays \(lhsArray) != \(rhsArray)")
            return false
        }
    }
    else if let lhsDictionary = lhsValue as? Dictionary<AnyHashable, Any>, let rhsDictionary = rhsValue as? Dictionary<AnyHashable, Any> {
        if equalDictionaries(lhsDictionary, rhsDictionary) == false {
            //print("EqualAny assert: equalDictionaries \(lhsDictionary) != \(rhsDictionary)")
            return false
        }
    }
    else {
        print("EqualAny unknown type")
        assert(false)
        return false
    }
    return true
}


fileprivate func equalDictionaries(_ lhs: Dictionary<AnyHashable, Any>, _ rhs: Dictionary<AnyHashable, Any>) -> Bool {
    for (key, lhsValue) in lhs {
        guard let rhsValue = rhs[key] else {
            print("EqualDictionaries no value for \(key)")
            return false
        }
        if equalAny(lhsValue, rhsValue) == false {
            //print("EqualDictionaries: equalAny(\(lhsValue), \(rhsValue))")
            print("Check for \(key) failed")
            return false
        }
    }
    return true
}

fileprivate func equalArrays(_ lhs: Array<Any>, _ rhs: Array<Any>) -> Bool {
    for (idx, lhsValue) in lhs.enumerated() {
        let rhsValue = rhs[idx]
        if equalAny(lhsValue, rhsValue) == false {
            //print("EqualArrays: equalAny(\(lhsValue), \(rhsValue))")
            return false
        }
    }
    return true
}

extension MCOMessageHeader {
    func prepareForUnitTest() {
        if fabs(date.timeIntervalSinceNow) <= 2 {
            // Date might be generated, set to known date.
            date = Date(timeIntervalSinceReferenceDate: 0)
        }
        if fabs(receivedDate.timeIntervalSinceNow) <= 2 {
            // Date might be generated, set to known date.
            receivedDate = Date(timeIntervalSinceReferenceDate: 0)
        }
        if self.nativeInstance.isMessageIDAutoGenerated() {
            messageID = "MyMessageID123@mail.gmail.com"
        }
    }
}

extension MCOAbstractPart {
    func prepareForUnitTest() {
        if let part = self as? MCOAbstractMessagePart {
            part.prepareForUnitTest2()
        }
        else if let part = self as? MCOAbstractMultipart {
            part.prepareForUnitTest2()
        }
    }
}

extension MCOAbstractMessagePart {
    func prepareForUnitTest2() {
        header?.prepareForUnitTest()
        mainPart?.prepareForUnitTest()
    }
}
extension MCOAbstractMultipart {
    
    func prepareForUnitTest2() {
        for part: MCOAbstractPart in parts ?? [] {
            part.prepareForUnitTest()
        }
    }
}
extension FileManager {
    
    @discardableResult
    func fileExists(atPath: String , isDirectory: inout Bool) -> Bool {
        var isDirectoryObjC: ObjCBool = false
        let result = self.fileExists(atPath: atPath, isDirectory: &isDirectoryObjC)
        isDirectory = isDirectoryObjC.boolValue
        return result
    }
    
}

fileprivate let TEST_EMAIL = "comscams@gmail.com"
fileprivate let TEST_PASSWORD = "l4 d3 e2 r1"

class unittest : XCTestCase {
    
    var _mainPath: URL!
    var _builderPath: URL!
    var _parserPath: URL!
    var _builderOutputPath: URL!
    var _parserOutputPath: URL!
    var _charsetDetectionPath: URL!
    var _summaryDetectionPath: URL!
    var _summaryDetectionOutputPath: URL!
    
    override func setUp() {
        super.setUp()
        
        #if os(Android)
        _mainPath = Bundle.main.bundleURL.appendingPathComponent("resources/data-android")
        MCOOperation.setMainQueue(DispatchQueue.main)
        #else
        NSTimeZone.default = TimeZone.init(abbreviation: "PST")!
        _mainPath = Bundle.init(for: unittest.self).resourceURL!.appendingPathComponent("data")
        #endif
        
        _builderPath = _mainPath.appendingPathComponent("builder/input")
        _builderOutputPath = _mainPath.appendingPathComponent("builder/output")
        _parserPath = _mainPath.appendingPathComponent("parser/input")
        _parserOutputPath = _mainPath.appendingPathComponent("parser/output")
        _charsetDetectionPath = _mainPath.appendingPathComponent("charset-detection")
        _summaryDetectionPath = _mainPath.appendingPathComponent("summary/input")
        _summaryDetectionOutputPath = _mainPath.appendingPathComponent("summary/output")
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testMessageBuilder1() {
        let builder = MCOMessageBuilder()
        builder.header.from = MCOAddress(RFC822String: "Hoà <dinh.viet.hoa@gmail.com>")
        builder.header.to = [MCOAddress(RFC822String: "Foo Bar <dinh.viet.hoa@gmail.com>")!]
        builder.header.subject = "testMessageBuilder1"
        builder.header.date = Date(timeIntervalSinceReferenceDate: 0)
        builder.header.messageID = "MyMessageID123@mail.gmail.com"
        builder.htmlBody = "<html><body>This is a HTML content</body></html>"
        let path = _builderOutputPath.appendingPathComponent("builder1.eml")
        print(path.path)
        let expectedData = try! Data.init(contentsOf: path, options: [])
        builder.setBoundaries(["1", "2", "3", "4", "5"])
        XCTAssertEqual(String(data: builder.data()!, encoding: String.Encoding.utf8), String(data: expectedData, encoding: String.Encoding.utf8))
    }
    
    func testMessageBuilder2() {
        let builder = MCOMessageBuilder()
        builder.header.from = MCOAddress(RFC822String: "Hoà <dinh.viet.hoa@gmail.com>")
        builder.header.to = [MCOAddress(RFC822String: "Foo Bar <dinh.viet.hoa@gmail.com>")!, MCOAddress(RFC822String: "Other Recipient <another-foobar@to-recipient.org>")!]
        builder.header.cc = [MCOAddress(RFC822String: "Carbon Copy <dinh.viet.hoa@gmail.com>")!, MCOAddress(RFC822String: "Other Recipient <another-foobar@to-recipient.org>")!]
        builder.header.subject = "testMessageBuilder2"
        builder.header.date = Date(timeIntervalSinceReferenceDate: 0)
        builder.header.messageID = "MyMessageID123@mail.gmail.com"
        builder.htmlBody = "<html><body>This is a HTML content</body></html>"
        var path = _builderPath.appendingPathComponent("photo.jpg")
        builder.addAttachment(attachment: MCOAttachment.attachmentWithContentsOfFile(filename: path.path)!)
        path = _builderPath.appendingPathComponent("photo2.jpg")
        builder.addAttachment(attachment: MCOAttachment.attachmentWithContentsOfFile(filename: path.path)!)
        builder.setBoundaries(["1", "2", "3", "4", "5"])
        path = _builderOutputPath.appendingPathComponent("builder2.eml")
        let expectedData = try! Data(contentsOf: path, options: [])
        //[[builder data] writeToFile:@"/Users/hoa/builder2-now.eml" atomically:YES];
        XCTAssertEqual(String(data: builder.data()!, encoding: String.Encoding.utf8), String(data: expectedData, encoding: String.Encoding.utf8))
    }
    
    func testMessageBuilder3() {
        let builder = MCOMessageBuilder()
        builder.header.from = MCOAddress(RFC822String: "Hoà <dinh.viet.hoa@gmail.com>")
        builder.header.to = [MCOAddress(RFC822String: "Foo Bar <dinh.viet.hoa@gmail.com>")!, MCOAddress(RFC822String: "Other Recipient <another-foobar@to-recipient.org>")!]
        builder.header.cc = [MCOAddress(RFC822String: "Carbon Copy <dinh.viet.hoa@gmail.com>")!, MCOAddress(RFC822String: "Other Recipient <another-foobar@to-recipient.org>")!]
        builder.header.subject = "testMessageBuilder3"
        builder.header.date = Date(timeIntervalSinceReferenceDate: 0)
        builder.header.messageID = "MyMessageID123@mail.gmail.com"
        builder.htmlBody = "<html><body><div>This is a HTML content</div><div><img src=\"cid:123\"></div></body></html>"
        var path = _builderPath.appendingPathComponent("photo.jpg")
        builder.addAttachment(attachment: MCOAttachment.attachmentWithContentsOfFile(filename: path.path)!)
        path = _builderPath.appendingPathComponent("photo2.jpg")
        let attachment = MCOAttachment.attachmentWithContentsOfFile(filename: path.path)!
        attachment.contentID = "123"
        builder.addRelatedAttachment(attachment: attachment)
        builder.setBoundaries(["1", "2", "3", "4", "5"])
        path = _builderOutputPath.appendingPathComponent("builder3.eml")
        let expectedData = try?  Data(contentsOf: path, options: [])
        //[[builder data] writeToFile:@"/Users/hoa/builder3-now.eml" atomically:YES];
        XCTAssertEqual(String(data: builder.data()!, encoding: String.Encoding.utf8), String(data: expectedData!, encoding: String.Encoding.utf8))
    }
    
    func testMessageParser() {
        var expectedData: Data!
        do {

            let list =  try FileManager.default.subpathsOfDirectory(atPath: _parserPath.path)
            for name in list {
                var path = _parserPath.appendingPathComponent(name)
                var isDirectory = false
                FileManager.default.fileExists(atPath: path.path , isDirectory: &isDirectory)
                if isDirectory {
                    continue
                }
                
                if path.lastPathComponent.starts(with: ".") { // Hidden files
                    continue
                }
                
                let data = try Data(contentsOf: path, options: [])
                let parser = MCOMessageParser(data: data)
                parser.header.prepareForUnitTest()
                parser.mainPart()?.prepareForUnitTest()
                
                let result: Dictionary<AnyHashable, Any> = dictionaryUnsafeCast(parser.nativeInstance.serializable())
                
                path = _parserOutputPath.appendingPathComponent(name)
                expectedData = try Data(contentsOf: path, options: [])
                let expectedResult = try JSONSerialization.jsonObject(with: expectedData, options: []) as! [AnyHashable: Any]
                
                let equal = equalDictionaries(result, expectedResult)
                if !equal {
                    print("Parsed Result: \(result)")
                    print("Expected Result: \(expectedResult)")
                    let pathResult = path.path + ".compswift"
                    print("Save result to: \(pathResult)")
                    parser.saveToFile(fileName: pathResult )
                }
                XCTAssertTrue(equal, "file \(name)");
            }
        }
        catch let e {
            XCTFail(" " + String.init(describing: e) + "\n" + (String(data: expectedData, encoding: .utf8) ?? "error!"))
            return
        }

    }
    
    func testCharsetDetection() {
        let list =  try! FileManager.default.subpathsOfDirectory(atPath: _charsetDetectionPath.path)
        for name in list {
            let path = _charsetDetectionPath.appendingPathComponent(name)
            var isDirectory = false
            FileManager.default.fileExists(atPath: path.path , isDirectory: &isDirectory)
            if isDirectory {
                continue
            }
            if path.lastPathComponent.starts(with: ".") { // Hidden files
                continue
            }
            
            let data = try! Data(contentsOf: path, options: [])
            let charset = data.mailCoreData().charsetWithFilteredHTML(false).string()!.lowercased()
            XCTAssertEqual(path.deletingPathExtension().lastPathComponent, charset, "not equal");
        }
    }
    
    func testSummary() {
        let list = try! FileManager.default.subpathsOfDirectory(atPath: _summaryDetectionPath.path)
        for name in list {
            let path = _summaryDetectionPath.appendingPathComponent(name)
            var isDirectory = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path , isDirectory: &isDirectory))
            if isDirectory {
                continue
            }
            if path.lastPathComponent.starts(with: ".") == true { // Hidden files
                continue
            }
            
            let data = try! Data(contentsOf: path, options: [])
            let parser = MCOMessageParser(data: data)
            parser.header.prepareForUnitTest()
            parser.mainPart()?.prepareForUnitTest()
            let str = parser.plainTextRendering()
            
            var resultPath = _summaryDetectionOutputPath.appendingPathComponent(name)
            resultPath = resultPath.deletingPathExtension().appendingPathExtension("txt")
            let resultData = try! Data(contentsOf: resultPath, options: [])
            
            XCTAssertEqual(String(data: resultData, encoding: .utf8), str)
        }

    }
    
    func testMUTF7() {
        let mutf7string = "~peter/mail/&U,BTFw-/&ZeVnLIqe-".mailCoreString()
        let ns = CIMAPNamespace.namespaceWithPrefix("".mailCoreString(), 0x2f/*'/'*/)
        let result = ns.componentsFromPath(mutf7string)
        XCTAssertTrue(result.description().string() == "[~peter,mail,台北,日本語]")
        XCTAssertTrue(mutf7string.mUTF7DecodedString().string() == "~peter/mail/台北/日本語")
        XCTAssertTrue("~peter/mail/台北/日本語".mailCoreString().mUTF7EncodedString().isEqual(mutf7string))
    }
}
